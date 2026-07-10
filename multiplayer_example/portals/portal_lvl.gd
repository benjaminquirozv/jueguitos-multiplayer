extends Area2D

# Marca este portal como trampa: en el tutorial vuelve al inicio del mapa.
@export var es_trampa := false

@onready var teleport_sound: AudioStreamPlayer = $Teleport


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	if not body.is_multiplayer_authority():
		return

	_reproducir_sonido_local()

	if es_trampa:
		# En el tutorial el portal falso vuelve al inicio del mapa.
		# En otros niveles (p.ej. level1) se mantiene el Destino del portal.
		var escena := get_tree().current_scene
		if escena and escena.has_method("get_tutorial_start_position"):
			if escena.has_method("mostrar_aviso_portal_trampa"):
				escena.mostrar_aviso_portal_trampa()
			body.global_position = escena.get_tutorial_start_position()
			return

	var destino := get_node_or_null("Destino")
	if destino:
		body.global_position = destino.global_position


func _reproducir_sonido_local() -> void:
	if teleport_sound == null or teleport_sound.stream == null:
		return
	var tree := get_tree()
	if tree == null:
		return

	var sonido := AudioStreamPlayer.new()
	sonido.stream = teleport_sound.stream
	sonido.bus = "SFX"
	sonido.pitch_scale = teleport_sound.pitch_scale
	sonido.volume_db = teleport_sound.volume_db

	tree.root.add_child(sonido)
	sonido.play()
	sonido.finished.connect(sonido.queue_free)
