extends Area2D

@onready var anim = $AnimatedSprite2D
@onready var sfx = $AudioStreamPlayer2D

func _ready() -> void:
	anim.play("estrellas")
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not (body is CharacterBody2D):
		return

	if not body.is_multiplayer_authority():
		return

	var my_data = Game.get_current_player()
	if my_data == null:
		return

	monitoring = false
	# Reproducir sonido
	sfx.play()

	# Esperar que termine
	await sfx.finished
	Game.collect_star.rpc(name, my_data.team)
