class_name LobbyWaitingScreen
extends Control

@onready var player_texture: TextureRect = %PlayerTexture
@onready var player_name: Label = %PlayerName
@onready var role_button: Button = %RoleButton
@onready var ready_button: Button = %ReadyButton
@onready var player_list: VBoxContainer = %PlayerList
@onready var waiting_label: Label = %WaitingLabel
@onready var back_button: Button = %BackButton
@onready var role_container: PanelContainer = %RoleContainer
@onready var role_list: VBoxContainer = %RoleList
@onready var start_timer: Timer = $StartTimer
@onready var game_start_container: PanelContainer = %GameStartContainer
@onready var game_start_counter: Label = %GameStartCounter

# ── SABOTAJE ──────────────────────────────────────────────────────────────────
# En waiting_screen.tscn agrega estos 3 nodos con sus unique names:
#   SabotajeButton    → Button         (al lado del RoleButton)
#   SabotajeContainer → PanelContainer (misma estructura que RoleContainer)
#   SabotajeList      → VBoxContainer  (hijo de SabotajeContainer)
@onready var sabotaje_button: Button = %SabotajeButton
@onready var sabotaje_container: PanelContainer = %SabotajeContainer
@onready var sabotaje_list: VBoxContainer = %SabotajeList
# ─────────────────────────────────────────────────────────────────────────────

var LOBBY_PLAYER_SCENE = preload("res://lobby/lobby_player.tscn")


func _ready() -> void:
	player_name.text = Game.get_current_player().name
	ready_button.pressed.connect(_toggle_ready)
	Game.players_updated.connect(_handle_players_updated)
	Game.player_updated.connect(func(id): _update_ready_button())
	Game.vote_updated.connect(func(id): _handle_vote_updated())
	sabotaje_button.disabled = true
	if multiplayer.is_server():
		start_timer.timeout.connect(func(): _start_game.rpc())
	_handle_players_updated()
	role_button.visible = Game.use_roles
	back_button.pressed.connect(_handle_back_pressed)
	role_button.pressed.connect(_handle_role_pressed)
	role_container.hide()
	game_start_container.hide()
	_update_ready_button()

	if Game.use_roles:
		_fill_role_container()
		var role = Game.get_current_player().role
		role_button.text = Statics.get_role_name(role)
		if role == Statics.Role.NONE:
			role_button.text = "Role?"

	# ── SABOTAJE ──────────────────────────────────────────────────────────────
	sabotaje_button.pressed.connect(_handle_sabotaje_pressed)
	sabotaje_container.hide()
	_fill_sabotaje_container()
	var sab = Game.get_current_player().sabotaje
	sabotaje_button.text = Statics.get_sabotaje_name(sab) if sab != Statics.Sabotaje.NINGUNO else "Sabotaje?"
	# ─────────────────────────────────────────────────────────────────────────


func _process(delta: float) -> void:
	game_start_counter.text = str(int(ceil(start_timer.time_left)))


func _toggle_ready() -> void:
	Game.set_current_player_vote(not Game.get_current_player().vote)
	_update_player()


func _update_player() -> void:
	var player_ready = Game.get_current_player().vote
	player_texture.modulate = Color.GREEN if player_ready else Color.WHITE
	role_container.hide()
	sabotaje_container.hide()


func _handle_players_updated() -> void:
	for child in player_list.get_children():
		child.queue_free()
	waiting_label.visible = Game.players.size() == 1
	for player in Game.players:
		if player.id != multiplayer.get_unique_id():
			var lobby_player_inst = LOBBY_PLAYER_SCENE.instantiate()
			lobby_player_inst.set_player(player)
			player_list.add_child(lobby_player_inst)
	_update_ready_button()
	if multiplayer.is_server():
		Game.reset_votes()


func _handle_back_pressed() -> void:
	if multiplayer.is_server():
		Lobby.go_to_host()
	else:
		Lobby.go_to_join()


func _handle_role_pressed() -> void:
	role_container.visible = not role_container.visible
	sabotaje_container.hide()


func _fill_role_container() -> void:
	for child in role_list.get_children():
		child.queue_free()
	for team in [Statics.Team.TEAM_BLACK, Statics.Team.TEAM_WHITE]:
		var button = Button.new()
		button.text = Statics.get_team_name(team)
		button.pressed.connect(func(): _update_team(team))
		role_list.add_child(button)


func _update_team(team: Statics.Team) -> void:
	Game.set_current_player_team(team)
	role_button.text = Statics.get_team_name(team)
	role_container.hide()
	sabotaje_button.disabled = false  # ← agregar esto
	sabotaje_container.show()  
	_update_ready_button()       # ← abre directo el panel de sabotaje


# ── SABOTAJE ──────────────────────────────────────────────────────────────────
func _handle_sabotaje_pressed() -> void:
	sabotaje_container.visible = not sabotaje_container.visible
	role_container.hide()


func _fill_sabotaje_container() -> void:
	for i in Statics.Sabotaje.size() - 1:
		var idx = i + 1
		var button = Button.new()
		button.text = Statics.get_sabotaje_name(idx)
		button.pressed.connect(func(): _update_sabotaje(idx))
		sabotaje_list.add_child(button)


func _update_sabotaje(sabotaje: Statics.Sabotaje) -> void:
	Game.set_current_player_sabotaje(sabotaje)
	sabotaje_button.text = Statics.get_sabotaje_name(sabotaje)
	sabotaje_container.hide()
	_update_ready_button()  
# ─────────────────────────────────────────────────────────────────────────────


func _handle_vote_updated() -> void:
	_update_player()
	if multiplayer and multiplayer.is_server():
		var all_voted = true
		for player in Game.players:
			all_voted = all_voted and player.vote
		if all_voted and _can_start_game():
			_start_timer.rpc()
		elif not start_timer.is_stopped():
			_stop_timer.rpc()


@rpc("reliable", "call_local")
func _start_timer() -> void:
	start_timer.start()
	game_start_container.show()
	role_button.disabled = true
	sabotaje_button.disabled = true


@rpc("reliable", "call_local")
func _stop_timer() -> void:
	start_timer.stop()
	game_start_container.hide()
	role_button.disabled = false
	sabotaje_button.disabled = false


@rpc("reliable", "call_local")
func _start_game() -> void:
	Game.set_current_player_vote(false)
	get_tree().change_scene_to_file("res://level1/level1.tscn")


func _can_start_game() -> bool:
	var quantity = Game.players.size() >= Game.min_players
	var all_have_team = _all_players_selected_team()
	var all_have_sabotaje = _all_players_selected_sabotaje()
	return quantity and all_have_team and all_have_sabotaje

func _all_players_selected_team() -> bool:
	for player in Game.players:
		if player.team == Statics.Team.NONE:
			return false
	return true

func _all_players_selected_sabotaje() -> bool:
	for player in Game.players:
		if player.sabotaje == Statics.Sabotaje.NINGUNO:
			return false
	return true


func _update_ready_button() -> void:
	ready_button.disabled = not _can_start_game()


func _are_all_roles_selected() -> bool:
	var roles = Statics.Role.values()
	roles.pop_front()
	for player in Game.players:
		roles.erase(player.role)
	return roles.is_empty()


func _are_all_roles_unique() -> bool:
	var roles = Statics.Role.values()
	roles.pop_front()
	for player in Game.players:
		if roles.has(player.role):
			roles.erase(player.role)
		else:
			return false
	return true


func _all_players_selected_role() -> bool:
	for player in Game.players:
		if player.role == Statics.Role.NONE:
			return false
	return true
