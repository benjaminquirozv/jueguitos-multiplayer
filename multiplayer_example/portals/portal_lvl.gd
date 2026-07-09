extends Area2D

# Marca este portal como trampa en el Inspector.
# Solo los portales con es_trampa = true activarán el sabotaje PORTAL_TRAMPA.
@export var es_trampa := false
@onready var teleport_sound: AudioStreamPlayer = $Teleport


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	print("ENTRÓ AL PORTAL: ", name)

	if not body.is_in_group("Player"):
		return

	# Solo actúa el jugador local (el que tiene authority sobre su propio body)
	if not body.is_multiplayer_authority():
		return

	var my_data = Game.get_current_player()
	call_deferred("_reproducir_sonido_local")
	# ── SABOTAJE: Portal trampa ───────────────────────────────────────────────
	#if es_trampa and my_data and my_data.sabotaje_activo == Statics.Sabotaje.PORTAL_TRAMPA:
	#	body.ir_al_inicio()
	#	return
	# ─────────────────────────────────────────────────────────────────────────

	body.global_position = $Destino.global_position

func _reproducir_sonido_local() -> void:
	if teleport_sound.stream == null:
		return

	var sonido := AudioStreamPlayer.new()
	sonido.stream = teleport_sound.stream
	sonido.bus = "SFX"
	sonido.pitch_scale = teleport_sound.pitch_scale
	sonido.volume_db = teleport_sound.volume_db

	get_tree().root.add_child(sonido)
	sonido.play()

	await sonido.finished
	sonido.queue_free()
