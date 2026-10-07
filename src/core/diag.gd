extends RefCounted
## Routes slice diagnostics to the engine log. The test suite deliberately drives
## refusal and failure paths; while `quiet` is set those lines print as one plain
## line (no engine backtrace, no ERROR/WARNING banner) so real problems stand out.

static var quiet: bool = false

## How many warnings have been raised this process; the suite reads it to pin "logs one warning".
static var warn_count: int = 0

static func warn(msg: String) -> void:
	warn_count += 1
	if quiet:
		print("    · ", msg)
	else:
		push_warning(msg)

static func error(msg: String) -> void:
	if quiet:
		print("    · ", msg)
	else:
		push_error(msg)
