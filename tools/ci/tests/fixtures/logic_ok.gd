class_name LogicOk
extends RefCounted

const MAX_HP: int = 100

var hp: int = 0
var label: String = ""

func take_damage(amount: int) -> void:
	hp = max(hp - amount, 0)
