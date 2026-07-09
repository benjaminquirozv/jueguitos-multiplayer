extends Area2D

# Marca este portal como trampa en el Inspector.
# Solo los portales con es_trampa = true activarán el sabotaje PORTAL_TRAMPA.
@export var es_trampa := false

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return

	# Solo actúa el jugador local (el que tiene authority sobre su propio body)
	if not body.is_multiplayer_authority():
		return

	var my_data = Game.get_current_player()


	body.global_position = $Destino.global_position
	#lolazo
