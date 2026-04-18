extends Area2D


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.global_position = $Destino.global_position
		# Replace with function body.
#lolazo
