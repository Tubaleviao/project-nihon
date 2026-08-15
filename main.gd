extends Node
## Entry point — delegates to game_root which owns all vertical slices.

const GameRoot := preload("res://src/core/game_root.gd")

func _ready() -> void:
	var root := GameRoot.new()
	root.name = "GameRoot"
	add_child(root)
