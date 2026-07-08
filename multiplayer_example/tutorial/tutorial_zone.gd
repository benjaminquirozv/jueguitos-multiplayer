class_name TutorialZone
extends Area2D

signal zone_triggered(zone: TutorialZone, body: Node2D)

@export_multiline var hint_text := ""
@export var sabotaje_demo: Statics.Sabotaje = Statics.Sabotaje.NINGUNO
@export var demo_duration := 8.0
@export var one_shot := true

var _triggered := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	collision_mask = 1


func _on_body_entered(body: Node2D) -> void:
	if one_shot and _triggered:
		return
	if not body.is_in_group("Player"):
		return
	if not body.is_multiplayer_authority():
		return
	_triggered = true
	zone_triggered.emit(self, body)
