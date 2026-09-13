class_name UiBadViewRef
extends Control

const BattleFakePath: String = "res://scripts/view/battle/battle_fake.gd"

func open() -> void:
	var panel := BattleFake.new()
	add_child(panel)
