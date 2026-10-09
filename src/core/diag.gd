extends RefCounted
## Routes slice diagnostics to the engine log. The test suite deliberately drives
## refusal and failure paths; while `quiet` is set those lines print as one plain
## line (no engine backtrace, no ERROR/WARNING banner) so real problems stand out.

static var quiet: bool = false

static var _warn_count: int = 0
static var _warn_mutex := Mutex.new()

## How many warnings have been raised this process; the suite reads it to pin "logs one warning".
## Worker threads (chunk builds, region reads) warn too, so the tally is kept under a mutex.
static func warn_count() -> int:
	_warn_mutex.lock()
	var n := _warn_count
	_warn_mutex.unlock()
	return n

static func warn(msg: String) -> void:
	_warn_mutex.lock()
	_warn_count += 1
	_warn_mutex.unlock()
	if quiet:
		print("    · ", msg)
	else:
		push_warning(msg)

static func error(msg: String) -> void:
	if quiet:
		print("    · ", msg)
	else:
		push_error(msg)
