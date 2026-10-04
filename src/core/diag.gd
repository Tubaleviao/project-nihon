extends RefCounted
## Routes slice diagnostics to the engine log. The test suite deliberately drives
## refusal and failure paths; while `quiet` is set those lines print as one plain
## line (no engine backtrace, no ERROR/WARNING banner) so real problems stand out.

static var quiet: bool = false

static func warn(msg: String) -> void:
	if quiet:
		print("    · ", msg)
	else:
		push_warning(msg)

static func error(msg: String) -> void:
	if quiet:
		print("    · ", msg)
	else:
		push_error(msg)
