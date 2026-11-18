#!/usr/bin/env python3
"""Placeholder sounds for every key of the sound event table (Phase 275).

Reads the generated event table (``godot/world_systems/soundevents.tres``: ``events`` and ``files``, from
``fabric/gameplay/sounds.js``) and writes one tiny, deterministic placeholder per asset key under
``assets/sounds/`` as ``.ogg.raw`` (Ogg Vorbis bytes, see ``assets/README.md``):

* ``sounds/ui/*`` - a short sine blip (stereo);
* ``sounds/sfx/player/footsteps/*`` - a low-passed noise burst (mono);
* ``sounds/sfx/items/*`` - a noise click over a decaying tone (mono);
* ``sounds/sfx/creatures/*`` - a falling growl tone (mono);
* ``sounds/sfx/world/*`` - a tone and noise thud (mono);
* ``sounds/ambience/*`` - four seconds of slow, soft noise that loops (stereo);
* ``sounds/music/*`` - four seconds of eight pentatonic notes that loop (stereo).

Pitch, colour and pattern come from a CRC of the file key, so each variant (``_01``, ``_02``..) sounds
different. All files are 48 kHz (the production rate), mono for positional effects, stereo for the rest.

Encoding decision. Python's stdlib synthesizes the PCM; ``ffmpeg`` (libvorbis, ``-bitexact`` and a fixed
stream serial) encodes it to Ogg Vorbis. Two encodes on one machine are byte-identical, but libvorbis is
floating point, so another ffmpeg/libvorbis build or CPU may produce other bytes. So the encoder never runs in
CI: ``assets/sounds/placeholders.lock.json`` records, per key, the SHA-256 of the synthesized PCM and of the
committed file. ``--check`` (stdlib only, no ffmpeg) re-synthesizes the PCM and fails when a key is missing, a
file is orphaned, a file or its PCM no longer matches the lock (stale), a file is not Ogg Vorbis with the
expected channels and rate, or ``assets/manifest.json``'s ``sounds`` section is not exactly the keys. A plain
run re-encodes only what is missing or stale, so running it on another machine does not churn the bytes.

    python3 tools/gen_placeholder_audio.py              # write missing/stale placeholders, the lock and the manifest
    python3 tools/gen_placeholder_audio.py --force      # re-encode every placeholder
    python3 tools/gen_placeholder_audio.py --check      # fail if anything is stale, missing or orphaned
    python3 tools/gen_placeholder_audio.py --self-test  # prove --check catches each of those

To add a sound: add a row to ``EVENTS`` in ``fabric/gameplay/sounds.js``, ``npm run generate``, run this
script (needs ffmpeg), commit the new ``.ogg.raw`` files, the lock and the manifest.
"""
import hashlib
import io
import json
import math
import shutil
import struct
import subprocess
import sys
import tempfile
import wave
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TABLE = Path("godot/world_systems/soundevents.tres")
ASSETS = Path("assets")
SOUND_DIR = Path("assets/sounds")
LOCK = Path("assets/sounds/placeholders.lock.json")
MANIFEST = Path("assets/manifest.json")
GENERATOR_VERSION = 1
RATE = 48000
FFMPEG_ARGS = ["-hide_banner", "-loglevel", "error", "-f", "wav", "-i", "-", "-map_metadata", "-1",
               "-c:a", "libvorbis", "-qscale:a", "0", "-fflags", "+bitexact", "-flags:a", "+bitexact",
               "-serial_offset", "0", "-f", "ogg", "-"]


def read_table(root=ROOT):
    """(events, files) from the generated .tres; its dictionaries are written as JSON."""
    out = {}
    for line in (root / TABLE).read_text().splitlines():
        for name in ("events", "files"):
            if line.startswith(name + " = "):
                out[name] = json.loads(line[len(name) + 3:])
    if set(out) != {"events", "files"}:
        sys.exit(f"FAIL {TABLE} has no events/files table: run `npm run generate`")
    return out["events"], out["files"]


def expected_keys(root=ROOT):
    _, files = read_table(root)
    keys = sorted(k for ks in files.values() for k in ks)
    if len(keys) != len(set(keys)):
        sys.exit("FAIL two events share an asset key")
    return keys


# ---------------------------------------------------------------- synthesis

def kind_of(key):
    for prefix, kind in (("sounds/ui/", "ui"), ("sounds/sfx/player/footsteps/", "footsteps"),
                         ("sounds/sfx/items/", "items"), ("sounds/sfx/creatures/", "creatures"),
                         ("sounds/sfx/world/", "world"), ("sounds/ambience/", "ambience"),
                         ("sounds/music/", "music")):
        if key.startswith(prefix):
            return kind
    sys.exit(f"FAIL {key} is not in the sound key layout")


def channels_of(key):
    return 2 if kind_of(key) in ("ui", "ambience", "music") else 1


class Noise:
    """A 31-bit LCG: the same key gives the same noise everywhere."""

    def __init__(self, seed):
        self.x = seed & 0x7FFFFFFF or 1

    def next(self):
        self.x = (1103515245 * self.x + 12345) & 0x7FFFFFFF
        return self.x / 0x3FFFFFFF - 1.0


def synth(key):
    """Mono samples in [-1, 1] for one key."""
    kind = kind_of(key)
    seed = zlib.crc32(key.encode())
    noise = Noise(seed)
    tau = 2 * math.pi
    out = []
    if kind == "ui":
        f = 700 + seed % 600
        n = int(0.07 * RATE)
        for i in range(n):
            t = i / RATE
            out.append(0.45 * math.sin(tau * f * t) * math.exp(-t * 60) * min(1.0, i / 48))
    elif kind == "footsteps":
        n = int(0.14 * RATE)
        a = 0.05 + (seed % 7) * 0.015
        lp = 0.0
        for i in range(n):
            t = i / RATE
            lp += a * (noise.next() - lp)
            out.append(3.0 * lp * math.exp(-t * 30) * min(1.0, i / 144))
    elif kind in ("items", "world"):
        f = 250 + seed % 500
        n = int((0.18 if kind == "items" else 0.25) * RATE)
        for i in range(n):
            t = i / RATE
            tone = 0.35 * math.sin(tau * f * t) * math.exp(-t * 18)
            hit = 0.3 * noise.next() * math.exp(-t * 90)
            out.append((tone + hit) * min(1.0, i / 48))
    elif kind == "creatures":
        f0 = 160 + seed % 140
        n = int(0.35 * RATE)
        phase = 0.0
        for i in range(n):
            t = i / RATE
            phase += tau * f0 * (1.0 - 0.4 * t / 0.35) / RATE
            s = math.sin(phase) + 0.3 * math.sin(2 * phase) + 0.1 * noise.next()
            out.append(0.35 * s * math.sin(math.pi * i / n))
    elif kind == "ambience":
        n = 4 * RATE
        a = 0.02 + (seed % 5) * 0.01
        lp = 0.0
        for i in range(n):
            t = i / RATE
            lp += a * (noise.next() - lp)
            swell = 0.6 + 0.4 * math.sin(tau * t / 4.0)  # one swell per loop, so the seam is smooth
            out.append(1.2 * lp * swell)
        fade = RATE // 50  # 20 ms either end: the noise itself does not wrap
        for i in range(fade):
            g = i / fade
            out[i] *= g
            out[n - 1 - i] *= g
    else:  # music
        scale = [0, 2, 4, 7, 9, 12, 14, 16]
        base = 196.0 * 2 ** ((seed % 5) / 12)
        note = RATE // 2
        for k in range(8):
            step = scale[(seed >> (3 * k)) % len(scale)]
            f = base * 2 ** (step / 12)
            for i in range(note):
                t = i / RATE
                env = min(1.0, i / 480) * (1.0 - i / note)
                out.append(0.3 * env * (math.sin(tau * f * t) + 0.3 * math.sin(2 * tau * f * t)))
    return out


def pcm(key):
    """16-bit little-endian PCM of `key`, interleaved to its channel count."""
    ch = channels_of(key)
    frames = bytearray()
    for v in synth(key):
        s = max(-32767, min(32767, int(round(v * 32767))))
        frames += struct.pack("<h", s) * ch
    return bytes(frames)


def wav_bytes(key, data):
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(channels_of(key))
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)
    return buf.getvalue()


def pcm_hash(key, data):
    h = hashlib.sha256(f"v{GENERATOR_VERSION}:{key}:{channels_of(key)}:{RATE}:".encode())
    h.update(data)
    return h.hexdigest()


def encode(key, data):
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        sys.exit(f"FAIL {key} needs encoding and ffmpeg is not installed (the --check needs no ffmpeg)")
    res = subprocess.run([ffmpeg] + FFMPEG_ARGS, input=wav_bytes(key, data), capture_output=True, check=False)
    if res.returncode != 0 or not res.stdout:
        sys.exit(f"FAIL ffmpeg could not encode {key}: {res.stderr.decode(errors='replace')}")
    return res.stdout


# ---------------------------------------------------------------- checks

def vorbis_info(data):
    """(channels, rate) from an Ogg Vorbis identification header, or None."""
    if len(data) < 28 or data[:4] != b"OggS":
        return None
    off = 27 + data[26]
    head = data[off:off + 16]
    if len(head) < 16 or head[:7] != b"\x01vorbis":
        return None
    return head[11], struct.unpack("<I", head[12:16])[0]


def manifest_text(keys, root):
    manifest = json.loads((root / MANIFEST).read_text())
    manifest["sounds"] = {k: k for k in keys}
    return json.dumps(manifest, indent=2) + "\n"


def sound_files(root):
    return sorted(p for p in (root / SOUND_DIR).rglob("*") if p.is_file() and p != root / LOCK)


def check(root=ROOT, quiet=False):
    """Problems with the placeholder tree under `root`, as strings."""
    keys = expected_keys(root)
    problems = []
    lock = {}
    if (root / LOCK).exists():
        lock = json.loads((root / LOCK).read_text()).get("files", {})
    else:
        problems.append(f"missing {LOCK}")
    for key in keys:
        path = root / ASSETS / key
        if not path.exists():
            problems.append(f"missing {ASSETS / key}")
            continue
        data = path.read_bytes()
        info = vorbis_info(data)
        if info != (channels_of(key), RATE):
            problems.append(f"{ASSETS / key} is not Ogg Vorbis at {channels_of(key)} ch {RATE} Hz (got {info})")
        entry = lock.get(key)
        if entry is None:
            problems.append(f"{key} has no lock entry")
            continue
        if entry.get("ogg") != hashlib.sha256(data).hexdigest():
            problems.append(f"{ASSETS / key} differs from the locked placeholder (stale)")
        if entry.get("pcm") != pcm_hash(key, pcm(key)):
            problems.append(f"{ASSETS / key} is stale: the generator's sound for it changed")
    for k in sorted(set(lock) - set(keys)):
        problems.append(f"lock lists {k}, which no event uses")
    expected = {root / ASSETS / k for k in keys}
    for p in sound_files(root):
        if p not in expected:
            problems.append(f"orphan {p.relative_to(root)}")
    if (root / MANIFEST).read_text() != manifest_text(keys, root):
        problems.append(f"{MANIFEST} `sounds` does not list exactly the sound keys")
    if not quiet:
        for p in problems:
            print("FAIL", p)
    return problems


def write(root=ROOT, force=False):
    keys = expected_keys(root)
    old = {}
    if (root / LOCK).exists():
        old = json.loads((root / LOCK).read_text()).get("files", {})
    lock = {}
    encoded = 0
    for key in keys:
        data = pcm(key)
        ph = pcm_hash(key, data)
        path = root / ASSETS / key
        entry = old.get(key, {})
        current = (not force and path.exists() and entry.get("pcm") == ph
                   and entry.get("ogg") == hashlib.sha256(path.read_bytes()).hexdigest())
        if not current:
            ogg = encode(key, data)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(ogg)
            encoded += 1
        lock[key] = {"pcm": ph, "ogg": hashlib.sha256(path.read_bytes()).hexdigest()}
    expected = {root / ASSETS / k for k in keys}
    for p in sound_files(root):
        if p not in expected:
            p.unlink()
    for d in sorted((root / SOUND_DIR).rglob("*"), reverse=True):
        if d.is_dir() and not any(d.iterdir()):
            d.rmdir()
    (root / LOCK).parent.mkdir(parents=True, exist_ok=True)
    (root / LOCK).write_text(json.dumps({"version": GENERATOR_VERSION, "files": lock}, indent=2, sort_keys=True) + "\n")
    (root / MANIFEST).write_text(manifest_text(keys, root))
    print(f"{len(keys)} placeholder sounds under {root / SOUND_DIR} ({encoded} encoded)")


def self_test():
    """Copy the tree, break it one way at a time, and require --check to say so."""
    failed = 0

    def case(label, breaker, pattern):
        nonlocal failed
        with tempfile.TemporaryDirectory() as tmp:
            t = Path(tmp)
            shutil.copytree(ROOT / SOUND_DIR, t / SOUND_DIR)
            (t / MANIFEST).write_text((ROOT / MANIFEST).read_text())
            (t / TABLE).parent.mkdir(parents=True, exist_ok=True)
            (t / TABLE).write_text((ROOT / TABLE).read_text())
            breaker(t)
            probs = check(t, quiet=True)
            ok = (not probs) if pattern is None else any(pattern in p for p in probs)
            print(f"{'ok  ' if ok else 'FAIL'} {label}{'' if ok else ' — ' + repr(probs)}")
            failed += 0 if ok else 1

    keys = expected_keys()
    first = keys[0]

    def lock_edit(t, fn):
        d = json.loads((t / LOCK).read_text())
        fn(d["files"])
        (t / LOCK).write_text(json.dumps(d))

    def manifest_edit(t):
        m = json.loads((t / MANIFEST).read_text())
        m["sounds"].pop(first)
        (t / MANIFEST).write_text(json.dumps(m, indent=2) + "\n")

    case("the committed tree passes", lambda t: None, None)
    case("a missing file fails", lambda t: (t / ASSETS / first).unlink(), "missing")
    case("an orphaned file fails", lambda t: (t / SOUND_DIR / "ui" / "nobody.ogg.raw").write_bytes(b"x"), "orphan")
    case("an edited file fails", lambda t: (t / ASSETS / first).write_bytes((t / ASSETS / first).read_bytes() + b"\0"), "stale")
    case("a file that is not Ogg Vorbis fails", lambda t: (t / ASSETS / first).write_bytes(b"RIFF0000WAVE"), "not Ogg Vorbis")
    case("a changed synth fails", lambda t: lock_edit(t, lambda f: f[first].update(pcm="0" * 64)), "generator's sound")
    case("a lock row with no event fails", lambda t: lock_edit(t, lambda f: f.update({"sounds/ui/gone.ogg.raw": {}})), "no event uses")
    case("a manifest without the key fails", manifest_edit, "`sounds`")
    case("a missing lock fails", lambda t: (t / LOCK).unlink(), "missing")
    a, b = pcm(first), pcm(first)
    print(f"{'ok  ' if a == b else 'FAIL'} the synth is deterministic")
    failed += 0 if a == b else 1
    if failed:
        print(f"{failed} self-test case(s) failed")
        return 1
    print("all placeholder-audio self-tests passed")
    return 0


def main():
    args = sys.argv[1:]
    if args == ["--check"]:
        probs = check()
        if probs:
            print("sounds are stale: run `python3 tools/gen_placeholder_audio.py` and commit the result")
            sys.exit(1)
        print(f"ok: {len(expected_keys())} placeholder sounds current")
    elif args == ["--self-test"]:
        sys.exit(self_test())
    elif args in ([], ["--force"]):
        write(force=bool(args))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
