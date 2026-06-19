extends Area2D

const ESCENA_DESTINO = "res://ui/final_cachipun.tscn"

# Server-authoritative: which team "owns" the portal.
# NONE = unlocked; set on first entry and stays for the match.
var locked_team: Statics.Team = Statics.Team.NONE


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body.is_multiplayer_authority():
		return
	var player_data := Game.get_current_player()
	if player_data == null:
		return
	if multiplayer.is_server():
		_procesar_entrada(multiplayer.get_unique_id(), player_data.team)
	else:
		_solicitar_entrada.rpc_id(1, multiplayer.get_unique_id(), player_data.team)


# Received on server only (sent via rpc_id(1, ...))
@rpc("any_peer", "reliable")
func _solicitar_entrada(player_id: int, team: Statics.Team) -> void:
	_procesar_entrada(player_id, team)


func _procesar_entrada(player_id: int, team: Statics.Team) -> void:
	if locked_team == Statics.Team.NONE:
		# Lock portal to this team; sync to all peers
		_set_locked_team.rpc(team)
	if team != locked_team:
		# Portal is locked to another team — block entry
		return
	if player_id == multiplayer.get_unique_id():
		get_tree().change_scene_to_file(ESCENA_DESTINO)
	else:
		_entrar.rpc_id(player_id)


@rpc("authority", "call_local", "reliable")
func _set_locked_team(team: Statics.Team) -> void:
	locked_team = team


@rpc("authority", "reliable")
func _entrar() -> void:
	get_tree().change_scene_to_file(ESCENA_DESTINO)
