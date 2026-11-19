#!/usr/bin/env python3
"""Phase 250 — the crowd stress run's control channel for the split mode.

One line of text per message over TCP (the grammar is StressRules.control_encode/decode):
  bots -> server: `run <profile> <pattern> <size>`, `steady`, `stop`
  server -> bots: `ready`, `machine <json>`, `result <json>`, `error <text>`

`serve` runs on the server's machine and `call` on the bots'. Both talk to tools/stress.sh through files
in a directory, so the "steady" and "stop" files the host, watcher and bots already use are still the
local signals; this program carries them across the network.

  stress_ctl.py serve <port> <dir>   waits for one `run`, writes <dir>/request ("profile pattern size"),
                                     sends `machine` + `ready` once <dir>/ready exists, touches <dir>/steady
                                     and <dir>/stop on the bots' messages (or a dropped link), then sends
                                     `result` from <dir>/result.json once it exists. A lone `stop` as the
                                     first message ends the server (exit 3).
  stress_ctl.py call <host> <port> <dir> <profile> <pattern> <size>
                                     sends `run`, waits for `ready`, saves <dir>/server-machine.json, sends
                                     `steady` when <dir>/steady appears and `stop` when it is removed or
                                     <dir>/bots-done appears, writes <dir>/host.json and watch.json from `result`.
  stress_ctl.py bye <host> <port>    asks the server to exit.
  stress_ctl.py selftest             a loopback round trip of every message.
"""
import json
import os
import socket
import sys
import tempfile
import threading
import time

PATTERNS = ("cluster", "spread", "cross", "pole", "churn")
PROFILES = ("lan", "wan_br", "wan_bad")


def touch(path):
    with open(path, "w") as f:
        f.write("1\n")


def wait_file(path, secs, stop=None):
    end = time.time() + secs
    while not os.path.exists(path):
        if stop and stop():
            return False
        if time.time() > end:
            return False
        time.sleep(0.2)
    return True


class Link:
    def __init__(self, sock):
        self.sock = sock
        self.buf = b""

    def send(self, line):
        self.sock.sendall(line.encode() + b"\n")

    def recv(self, timeout):
        """One line, '' when the peer closed, None on timeout."""
        self.sock.settimeout(timeout)
        while b"\n" not in self.buf:
            try:
                chunk = self.sock.recv(1 << 16)
            except socket.timeout:
                return None
            except OSError:
                return ""
            if not chunk:
                return ""
            self.buf += chunk
        line, self.buf = self.buf.split(b"\n", 1)
        return line.decode().strip()


def valid_run(parts):
    return (len(parts) == 4 and parts[0] == "run" and parts[1] in PROFILES and parts[2] in PATTERNS
            and parts[3].isdigit() and int(parts[3]) > 0)


def serve(port, d, accept_secs=86400):
    os.makedirs(d, exist_ok=True)
    srv = socket.socket()
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("0.0.0.0", port))
    srv.listen(1)
    srv.settimeout(accept_secs)
    conn, _ = srv.accept()
    link = Link(conn)
    first = link.recv(60)
    if first == "stop":
        return 3
    parts = (first or "").split()
    if not valid_run(parts):
        link.send("error bad request")
        return 1
    with open(os.path.join(d, "request"), "w") as f:
        f.write("%s %s %s\n" % tuple(parts[1:]))
    if not wait_file(os.path.join(d, "ready"), 600):
        link.send("error the server never got ready")
        return 1
    mpath = os.path.join(d, "machine.json")
    if os.path.exists(mpath):
        link.send("machine " + json.dumps(json.load(open(mpath))))
    link.send("ready")
    while True:
        msg = link.recv(3600)
        if msg == "steady":
            touch(os.path.join(d, "steady"))
        elif msg in ("stop", "", None):
            touch(os.path.join(d, "stop"))
            break
    if wait_file(os.path.join(d, "result.json"), 300):
        link.send("result " + json.dumps(json.load(open(os.path.join(d, "result.json")))))
    return 0


def connect(host, port, secs=60):
    end = time.time() + secs
    while True:
        try:
            return Link(socket.create_connection((host, port), timeout=5))
        except OSError:
            if time.time() > end:
                raise
            time.sleep(1)


def call(host, port, d, profile, pattern, size):
    os.makedirs(d, exist_ok=True)
    link = connect(host, port)
    link.send("run %s %s %s" % (profile, pattern, size))
    while True:
        msg = link.recv(900)
        if msg in (None, ""):
            print("stress_ctl: the server did not answer", file=sys.stderr)
            return 1
        if msg.startswith("error"):
            print("stress_ctl: " + msg, file=sys.stderr)
            return 1
        if msg.startswith("machine "):
            open(os.path.join(d, "server-machine.json"), "w").write(msg[8:])
        if msg == "ready":
            touch(os.path.join(d, "server-ready"))
            break
    steady, done = os.path.join(d, "steady"), os.path.join(d, "bots-done")
    seen = False
    while not os.path.exists(done):
        if os.path.exists(steady) and not seen:
            link.send("steady")
            seen = True
        elif seen and not os.path.exists(steady):
            break
        time.sleep(0.2)
    link.send("stop")
    while True:
        msg = link.recv(600)
        if msg is None or msg == "":
            print("stress_ctl: the server sent no result", file=sys.stderr)
            return 1
        if msg.startswith("result "):
            res = json.loads(msg[7:])
            for k in ("host", "watch"):
                if res.get(k) is not None:
                    json.dump(res[k], open(os.path.join(d, k + ".json"), "w"))
            return 0


def bye(host, port):
    connect(host, port).send("stop")
    return 0


def selftest():
    port = 17999
    with tempfile.TemporaryDirectory() as root:
        sd, bd = os.path.join(root, "s"), os.path.join(root, "b")
        os.makedirs(sd)
        os.makedirs(bd)
        codes = {}
        t = threading.Thread(target=lambda: codes.__setitem__("serve", serve(port, sd, 30)), daemon=True)
        t.start()
        c = threading.Thread(target=lambda: codes.__setitem__("call", call("127.0.0.1", port, bd, "lan", "cluster", "16")), daemon=True)
        c.start()
        assert wait_file(os.path.join(sd, "request"), 20), "no request"
        assert open(os.path.join(sd, "request")).read().split() == ["lan", "cluster", "16"]
        json.dump({"cores": 4}, open(os.path.join(sd, "machine.json"), "w"))
        touch(os.path.join(sd, "ready"))
        assert wait_file(os.path.join(bd, "server-ready"), 20), "no ready"
        assert json.load(open(os.path.join(bd, "server-machine.json")))["cores"] == 4
        touch(os.path.join(bd, "steady"))
        assert wait_file(os.path.join(sd, "steady"), 20), "steady did not cross"
        os.remove(os.path.join(bd, "steady"))
        assert wait_file(os.path.join(sd, "stop"), 20), "stop did not cross"
        json.dump({"host": {"tick": 1}, "watch": {"fps": 60}}, open(os.path.join(sd, "result.json"), "w"))
        t.join(30)
        c.join(30)
        assert codes == {"serve": 0, "call": 0}, codes
        assert json.load(open(os.path.join(bd, "host.json"))) == {"tick": 1}
        assert json.load(open(os.path.join(bd, "watch.json"))) == {"fps": 60}
        t = threading.Thread(target=lambda: codes.__setitem__("serve", serve(port, sd, 30)), daemon=True)
        t.start()
        time.sleep(0.5)
        bye("127.0.0.1", port)
        t.join(30)
        assert codes["serve"] == 3, codes
    print("stress_ctl selftest: ok")
    return 0


def main(argv):
    try:
        if argv[1] == "serve":
            return serve(int(argv[2]), argv[3])
        if argv[1] == "call":
            return call(argv[2], int(argv[3]), argv[4], argv[5], argv[6], argv[7])
        if argv[1] == "bye":
            return bye(argv[2], int(argv[3]))
        if argv[1] == "selftest":
            return selftest()
    except (IndexError, ValueError):
        pass
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
