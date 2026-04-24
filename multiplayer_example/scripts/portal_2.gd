extends Marker2D



##If a collition body enters de 2d area then use this function
func _on_portal_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.set_position($".".global_position) # Replace with function body.
