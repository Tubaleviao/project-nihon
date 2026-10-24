extends "res://src/core/wiring.gd"
## Admin wiring (Phase 182) — applies what the host's admin commands did to THIS machine's player:
## its moves (`/speed`, `/fly`), a heal, and whether it is an admin at all (the Admin window).
## The commands themselves run in ChatSlice on the host; the host emits these signals for its own
## player and its networking carries them to a remote player's client.

const PlayerSlice := preload("res://src/player/player_slice.gd")

func _connect_all() -> void:
	connect_bus(GameBus.admin_moves_synced, _on_admin_moves)
	connect_bus(GameBus.admin_healed, _on_admin_healed)
	connect_bus(GameBus.admin_status_synced, _on_admin_status)
	# A client's (re)connection starts walking normally: the host dropped its moves when it left or joined.
	connect_bus(GameBus.player_identity_assigned, _on_identity_assigned)
	# The commands' doors: `/time` runs the host's clock, and a joining client is told whether it is an admin.
	if root._chat != null:
		root._chat.world_clock = root._clock
		if root._networking != null:
			root._networking.admin_check = root._chat.is_admin
	# A host's or offline game's own player is an admin; a client learns it from the host.
	if not root._is_client and not root._is_server:
		GameBus.admin_status_synced.emit(true)

func _on_admin_moves(speed_factor: float, flying: bool) -> void:
	if root._player != null:
		root._player.set_admin_moves(speed_factor, flying)

## A downed body is left to respawn: healing is not a revive.
func _on_admin_healed() -> void:
	if root._player != null and root._player.is_alive():
		root._player.set_hp(PlayerSlice.MAX_HP)

func _on_identity_assigned(_player_id: String) -> void:
	if root._is_client:
		_on_admin_moves(1.0, false)

func _on_admin_status(is_admin: bool) -> void:
	if root._ui != null:
		root._ui.set_admin(is_admin)
