extends Area2D

const ESCENA_DESTINO = "res://ui/final_cachipun.tscn"

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_multiplayer_authority():
		return
	# Ordena a TODOS (incluido local) que cambien de escena
	_cambiar_escena_todos.rpc()

@rpc("any_peer", "call_local", "reliable")
func _cambiar_escena_todos() -> void:
	get_tree().change_scene_to_file(ESCENA_DESTINO)
