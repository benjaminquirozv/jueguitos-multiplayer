extends Area2D

@onready var anim = $AnimatedSprite2D
@onready var sfx = $soundstar

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

	# Sonido: puramente local, solo lo escucha quien la agarró.
	call_deferred("_reproducir_sonido_local")

	# Recolección real: se sincroniza con todos vía el servidor.
	if multiplayer.is_server():
		Game.collect_star.rpc(name, my_data.team)
	else:
		Game._request_collect_star.rpc_id(1, name, my_data.team)

func _reproducir_sonido_local() -> void:
	if sfx.stream == null:
		return

	var sonido := AudioStreamPlayer.new()
	sonido.stream = sfx.stream
	sonido.bus = "SFX"
	sonido.pitch_scale = sfx.pitch_scale
	sonido.volume_db = sfx.volume_db

	get_tree().root.add_child(sonido)
	sonido.play()

	await sonido.finished
	sonido.queue_free()
