extends Control


@onready var _label: Label = $Panel/Label


func set_text(text: String) -> void:
	_label.text = text
