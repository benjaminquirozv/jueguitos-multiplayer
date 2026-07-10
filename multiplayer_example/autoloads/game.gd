extends Node

signal players_updated
signal player_updated(id)
signal vote_updated(id)
signal player_index_received()
signal stars_updated(team)
signal cachipun_round_result(team_choice: int, hand_choice: int, result: String)

var team_stars: Dictionary = {
	Statics.Team.TEAM_BLACK: 0,
	Statics.Team.TEAM_WHITE: 0,
}


@export var multiplayer_test = false
@export var use_roles = true
@export var unique_roles = true
@export var all_roles = true
@export var min_players = 2
@export var fill_screen = true
@export var test_players: Array[PlayerDataResource] = []
@export var main_scene: PackedScene
const STARS_PARA_GANAR := 4

func team_has_all_stars(team: Statics.Team) -> bool:
	return team_stars.get(team, 0) >= STARS_PARA_GANAR

var players: Array[Statics.PlayerData] = []
var change_window_scale := true :
	set(value):
		var last_value = change_window_scale
		change_window_scale = value
		if not change_window_scale:
			reset_window_scale()
		elif last_value != value:
			_update_window_scale()

var _is_window_small = false
var _initial_window_scale_mode
var _initial_window_scale_aspect

@onready var player_id: Label = %PlayerId


func _ready() -> void:
	_initial_window_scale_mode = get_window().content_scale_mode
	_initial_window_scale_aspect = get_window().content_scale_aspect
	get_window().size_changed.connect(_handle_size_changed)
	_update_window_scale()
	get_tree().node_added.connect(_handle_node_added)
	if not OS.is_debug_build():
		multiplayer_test = false
		player_id.hide()


func sort_players() -> void:
	players.sort_custom(func(a, b): return a.index < b.index)


func add_player(player: Statics.PlayerData) -> void:
	var existing_player: Statics.PlayerData = null
	for data in players:
		if data.id == player.id:
			existing_player = data
			break
	if existing_player:
		existing_player.update(player)
	else:
		players.append(player)
	sort_players()
	players_updated.emit()


func remove_player(id: int) -> void:
	for i in players.size():
		if players[i].id == id:
			players.remove_at(i)
			break
	if multiplayer.is_server():
		var player_indices: Dictionary = {}
		for i in players.size():
			players[i].index = i
			player_indices[players[i].id] = i
		update_indices.rpc(player_indices)
	players_updated.emit()


func get_player(id: int) -> Statics.PlayerData:
	for player in players:
		if player.id == id:
			return player
	return null


func get_current_player() -> Statics.PlayerData:
	return get_player(multiplayer.get_unique_id())


@rpc("reliable")
func update_indices(player_indices: Dictionary) -> void:
	for player in Game.players:
		if player.id in player_indices:
			player.index = player_indices[player.id]
			if player.id == multiplayer.get_unique_id():
				Debug.index = player.index
				Debug.add_to_window_title("Client %d" % player.index)
	sort_players()
	players_updated.emit()


@rpc("any_peer", "reliable", "call_local")
func set_player_role(id: int, role: Statics.Role) -> void:
	var player = get_player(id)
	player.role = role
	player.team = Statics.get_team_from_role(role)
	print(player.name, "es del equipo", Statics.get_team_name(player.team))
	player_updated.emit(id)

func set_current_player_role(role: Statics.Role) -> void:
	set_player_role.rpc(multiplayer.get_unique_id(), role)


# ── SABOTAJE elegido en lobby ──────────────────────────────────────────────────
# Sincroniza el sabotaje que el jugador POSEE (lo elige en el lobby).
@rpc("any_peer", "reliable", "call_local")
func set_player_sabotaje(id: int, sabotaje: Statics.Sabotaje) -> void:
	var player = get_player(id)
	if player == null:
		return
	player.sabotaje = sabotaje
	player_updated.emit(id)

func set_current_player_sabotaje(sabotaje: Statics.Sabotaje) -> void:
	set_player_sabotaje.rpc(multiplayer.get_unique_id(), sabotaje)
# ──────────────────────────────────────────────────────────────────────────────

@rpc("any_peer", "reliable", "call_local")
func set_player_team(id: int, team: Statics.Team) -> void:
	var player = get_player(id)
	if player == null:
		return
	player.team = team

	# Contar cuántos jugadores ya están en este equipo (sin contarme a mí mismo)
	var compañeros_en_team := 0
	for p in players:
		if p.id != id and p.team == team:
			compañeros_en_team += 1

	match team:
		Statics.Team.TEAM_BLACK:
			player.role = Statics.Role.ROLE_A if compañeros_en_team == 0 else Statics.Role.ROLE_B
		Statics.Team.TEAM_WHITE:
			player.role = Statics.Role.ROLE_C if compañeros_en_team == 0 else Statics.Role.ROLE_D

	player_updated.emit(id)

func set_current_player_team(team: Statics.Team) -> void:
	set_player_team.rpc(multiplayer.get_unique_id(), team)

@rpc("any_peer", "reliable", "call_local")
func set_player_vote(id: int, vote: bool) -> void:
	var player = get_player(id)
	if not player:
		return
	player.vote = vote
	player_updated.emit(id)
	vote_updated.emit(id)

func set_current_player_vote(vote: bool) -> void:
	set_player_vote.rpc(multiplayer.get_unique_id(), vote)

func reset_votes() -> void:
	for player in players:
		set_player_vote.rpc(player.id, false)

func is_online() -> bool:
	return not multiplayer.multiplayer_peer is OfflineMultiplayerPeer and \
		multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED

func update_player_id() -> void:
	if not OS.is_debug_build():
		return
	if Debug.is_online():
		player_id.show()
		player_id.text = str(multiplayer.get_unique_id())
	else:
		player_id.hide()

func reset_window_scale() -> void:
	get_window().content_scale_mode = _initial_window_scale_mode
	get_window().content_scale_aspect = _initial_window_scale_aspect

func _handle_size_changed() -> void:
	if not change_window_scale:
		return
	var was_windows_small = _is_window_small
	_is_window_small = get_window().size.x < 1280 or get_window().size.y < 720
	if was_windows_small == _is_window_small:
		return
	_update_window_scale()

func _update_window_scale() -> void:
	if _is_window_small:
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	else:
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

func _handle_node_added(node: Node) -> void:
	if node.get_parent() == get_window():
		change_window_scale = node is MainMenu or node is LobbyHostScreen or \
			node is LobbyJoinScreen or node is LobbyWaitingScreen or node is Credits
			
			
##----Lógica de estrellas 
@rpc("any_peer", "call_remote", "reliable")
func _request_collect_star(star_name: String, team: Statics.Team) -> void:
	if multiplayer.is_server():
		collect_star.rpc(star_name, team)


@rpc("any_peer", "reliable", "call_local")
func collect_star(star_name: String, team: Statics.Team) -> void:
	var stars_container = get_tree().current_scene.get_node_or_null("stars")
	if stars_container == null:
		return
	var star = stars_container.get_node_or_null(star_name)
	if star == null:
		return  # ya la recolectaron (evita doble conteo)
	star.queue_free()
	team_stars[team] = team_stars.get(team, 0) + 1
	stars_updated.emit(team)


func get_team_stars(team: Statics.Team) -> int:
	return team_stars.get(team, 0)


func reset_stars() -> void:
	team_stars[Statics.Team.TEAM_BLACK] = 0
	team_stars[Statics.Team.TEAM_WHITE] = 0



#-----------------Final de la partida----------------------------------------------------------
@rpc("any_peer", "reliable", "call_local")
func finalizar_partida(equipo_ganador: Statics.Team) -> void:
	var mi_data = get_current_player()
	if mi_data != null and mi_data.team == equipo_ganador:
		get_tree().change_scene_to_file("res://ui/final_cachipun.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/you_lose.tscn")


#-----------------Cachipún final (RPCs en autoload: la escena no existe en perdedores)----------
const CACHIPUN_TIE := "¡EMPATE!"
const CACHIPUN_TEAM_WINS := "¡EL EQUIPO GANA!"
const CACHIPUN_HAND_WINS := "¡LA MANO GANA!"

var _cachipun_choices: Dictionary = {}


func reset_cachipun() -> void:
	_cachipun_choices.clear()


func submit_cachipun_choice(choice: int) -> void:
	_rpc_cachipun_choice.rpc(multiplayer.get_unique_id(), choice)


@rpc("any_peer", "call_local", "reliable")
func _rpc_cachipun_choice(player_id: int, choice: int) -> void:
	_cachipun_choices[player_id] = choice
	if not multiplayer.is_server():
		return
	if _cachipun_choices.is_empty():
		return
	_resolve_cachipun_round()


func _resolve_cachipun_round() -> void:
	var choice_counts := {1: 0, 2: 0, 3: 0}  # ROCK, PAPER, SCISSORS
	for choice in _cachipun_choices.values():
		if choice_counts.has(choice):
			choice_counts[choice] += 1

	var team_choice := 1
	var max_votes := 0
	for choice in choice_counts:
		if choice_counts[choice] > max_votes:
			max_votes = choice_counts[choice]
			team_choice = choice

	var hand_choice: int = [1, 2, 3].pick_random()
	var result := _calculate_cachipun_result(team_choice, hand_choice)
	_cachipun_choices.clear()
	_rpc_cachipun_result.rpc(team_choice, hand_choice, result)


func _calculate_cachipun_result(team: int, hand: int) -> String:
	if team == hand:
		return CACHIPUN_TIE
	# ROCK=1 beats SCISSORS=3; PAPER=2 beats ROCK=1; SCISSORS=3 beats PAPER=2
	if (team == 1 and hand == 3) or (team == 2 and hand == 1) or (team == 3 and hand == 2):
		return CACHIPUN_TEAM_WINS
	return CACHIPUN_HAND_WINS


@rpc("authority", "call_local", "reliable")
func _rpc_cachipun_result(team_choice: int, hand_choice: int, result: String) -> void:
	cachipun_round_result.emit(team_choice, hand_choice, result)
