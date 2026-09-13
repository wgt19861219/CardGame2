class_name UiOk
extends Control

## 注释里提及 SomeViewClass 不算引用（AST 不含注释，LAYER003 不误报）。

const AtlasSpritePath: String = "res://scripts/ui/atlas_sprite.gd"

func build() -> void:
	add_child(load("res://scenes/ui/hero_content.tscn").instantiate())
