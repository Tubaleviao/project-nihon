extends RefCounted
## Phase 289 — the playtest bot's `mine` step shoots the work bar mid-hold. Half way through a hold the bot drives
## itself (bus intents, not the player's input), the player's own `WorkHold` draws the bar for that work; the rect
## is checked inside the viewport, `mine.png` is taken, the rest of the work time is waited out and the bar hidden.

## "" when the bar showed inside the viewport, else why not. `last` is the host's `[action, material]`.
static func shoot(bot: Node, wh: Control, last: Array, secs: float, kind: String, t0_ms: int) -> String:
	if wh == null or last.size() < 2:
		return "the player has no work bar, or the host named no work"
	wh.show_work(str(last[0]), str(last[1]), secs, secs * 0.5, kind)
	await bot.get_tree().process_frame
	var view := bot.get_viewport().get_visible_rect()
	var r: Rect2 = wh.bar().get_global_rect()
	var note := "" if wh.bar_showing() and view.encloses(r) else "the work bar %s is not inside the viewport %s" % [str(r), str(view)]
	await bot._screenshot("mine")
	var left := secs - float(Time.get_ticks_msec() - t0_ms) * 0.001
	if left > 0.0:
		await bot.get_tree().create_timer(left).timeout
	wh.release()   # the bot's hold was never the bar's own: this only hides it
	return note
