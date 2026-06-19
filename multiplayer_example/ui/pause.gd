extends CanvasLayer

signal pause_state_changed(is_paused: bool, requester_id: int)

var _is_paused := false
var _current_requester := 0

@onready var _pause_button: Button = %PauseButton
@onready var _overlay: Control = %PauseOverlay
@onready var _paused_by: Label = %PausedBy
@onready var _resume: Button = %Resume
@onready var _volume: Button = %volume
@onready var _back: Button = $PauseOverlay/volumenContainer/VolumeMenu/BackButton
@onready var _quit_game: Button = %QuitGame
@onready var _menu: Button = %Menu
@onready var music_slider: HSlider = $PauseOverlay/volumenContainer/VolumeMenu/volumeSlider
@onready var VolumeMenu: VBoxContainer = $PauseOverlay/volumenContainer/VolumeMenu
@onready var MainButtons: VBoxContainer = $PauseOverlay/ButtonsCenter/Buttons
@onready var VolumeContainer: Control = $PauseOverlay/volumenContainer
func _ready() -> void:
	
	MainButtons.visible = true
	VolumeContainer.visible = false
	_update_ui()
	_pause_button.pressed.connect(_toggle_pause)
	_resume.pressed.connect(_toggle_pause)
	_quit_game.pressed.connect(_on_quit_game)
	_menu.pressed.connect(_on_menu)
	_volume.pressed.connect(_on_volume_pressed)
	_back.pressed.connect(_on_back_pressed)
	# Conectar eventos de multiplayer para sincronización
	if multiplayer:
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		
	##Agregamos valores default para el slider de volumen
	var music_bus := AudioServer.get_bus_index("Music")
	music_slider.min_value= 0
	music_slider.max_value = 1
	music_slider.step = 0.01
	music_slider.value  = db_to_linear(AudioServer.get_bus_volume_db(music_bus)) 
	music_slider.value_changed.connect(_on_music_volume_changed)
	
func _on_volume_pressed():
	MainButtons.visible = false
	VolumeContainer.visible = true
func _on_back_pressed():
	VolumeContainer.visible = false
	MainButtons.visible = true
##función para manejar volumen
func _on_music_volume_changed(value: float):
	var music_bus := AudioServer.get_bus_index("Music")
	if value <= 0:
		AudioServer.set_bus_volume_db(music_bus, -80)
	else:
		AudioServer.set_bus_volume_db(music_bus,linear_to_db(value))
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	# Evitar spam de pausas
	if multiplayer.is_server():
		_server_handle_pause_request(multiplayer.get_unique_id())
	else:
		_request_pause_to_server.rpc_id(1, multiplayer.get_unique_id())


@rpc("any_peer", "call_remote", "reliable")
func _request_pause_to_server(requester_id: int) -> void:
	if multiplayer.is_server():
		_server_handle_pause_request(requester_id)


func _server_handle_pause_request(requester_id: int) -> void:
	# Solo el servidor maneja el estado de pausa para evitar conflictos
	var new_pause_state = not _is_paused
	_is_paused = new_pause_state
	_current_requester = requester_id if new_pause_state else 0
	
	# Notificar a todos los peers (incluyendo servidor)
	_sync_pause_state.rpc(_is_paused, _current_requester)


@rpc("authority", "call_local", "reliable")
func _sync_pause_state(should_pause: bool, requester_id: int) -> void:
	# Solo acepta comandos del servidor
	if multiplayer.get_remote_sender_id() != 1 and multiplayer.get_remote_sender_id() != 0:
		return
	
	_is_paused = should_pause
	_current_requester = requester_id
	
	get_tree().paused = should_pause
	_update_ui()
	
	pause_state_changed.emit(should_pause, requester_id)


func _update_ui() -> void:
	_pause_button.visible = not _is_paused
	_overlay.visible = _is_paused
	
	if _is_paused:
		_paused_by.text = _get_paused_by_text(_current_requester)
		# Usar call_deferred para evitar problemas con el focus durante la pausa
		_resume.call_deferred("grab_focus")


func _on_quit_game() -> void:
	# Despausar antes de salir para evitar estados inconsistentes
	if _is_paused and multiplayer.is_server():
		_server_handle_pause_request(0)
	elif _is_paused:
		_request_pause_to_server.rpc_id(1, 0)
	
	# Dar tiempo para que se sincronice la despausa
	await get_tree().process_frame
	get_tree().quit()


func _on_menu() -> void:
	# Despausar antes de cambiar de escena
	if _is_paused and multiplayer.is_server():
		_server_handle_pause_request(0)
	elif _is_paused:
		_request_pause_to_server.rpc_id(1, 0)
	
	# Dar tiempo para sincronización
	await get_tree().process_frame
	
	if Game.is_online():
		Lobby.go_to_menu()
	else:
		get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _on_peer_disconnected(id: int) -> void:
	# Si el jugador que pausó se desconecta, despausar automáticamente
	if _is_paused and _current_requester == id and multiplayer.is_server():
		_server_handle_pause_request(0)


func _get_paused_by_text(requester_id: int) -> String:
	var player: Statics.PlayerData = Game.get_player(requester_id)
	if player == null:
		return "Juego en pausa"
	return "Pausado por %s" % player.name
