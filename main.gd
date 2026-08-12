extends Node

func _ready():
	_check("BIOMES", GameData.BIOMES)
	_check("CREATURES", GameData.CREATURES)
	_check("DECISIONS", GameData.DECISIONS)
	_check("ITEMS", GameData.ITEMS)
	_check("MATERIALS", GameData.MATERIALS)
	_check("PROFESSIONS", GameData.PROFESSIONS)
	_check("RECIPES", GameData.RECIPES)
	_check("SKILLS", GameData.SKILLS)
	_check("SYSTEMS", GameData.SYSTEMS)
	_check("TECHNOLOGIES", GameData.TECHNOLOGIES)
	_check("WORLD_SYSTEMS", GameData.WORLD_SYSTEMS)


func _check(name: String, registry: Dictionary):
	for key in registry:
		if registry[key] == null:
			push_error("%s → %s FAILED" % [name, key])
		else:
			print("%s → %s OK" % [name, key])
