extends Node
## Entry point — delegates to game_root which owns all vertical slices.

const RootSwap := preload("res://src/menu/root_swap.gd")

func _ready() -> void:
	RootSwap.spawn_root(self, "")
