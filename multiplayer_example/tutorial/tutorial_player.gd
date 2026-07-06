extends CharacterBody2D


signal moved

@export var speed := 200.0

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var _bubble: Control = $SpeechBubble


func _ready() -> void:
	$Camera2D.enabled = true


func show_hint(text: String) -> void:
	_bubble.set_text(text)


func _physics_process(_delta: float) -> void:
	var dir := Input.get_axis("ui_left", "ui_right")
	if dir != 0.0:
		moved.emit()
		_anim.play("walk")
		_anim.flip_h = dir < 0.0
	else:
		_anim.stop()

	velocity = Vector2(dir * speed, 0.0)
	move_and_slide()
