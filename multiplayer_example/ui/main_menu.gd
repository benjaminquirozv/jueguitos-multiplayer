class_name MainMenu
extends Control


@onready var host: Button = %Host
@onready var join: Button = %Join
@onready var tutorial: Button = %Tutorial
@onready var credits: Button = %Credits
@onready var quit: Button = %Quit
@onready var _volume: Button = %volume
@onready var music_slider: HSlider = $ButtonsCenter/volumenContainer/VolumeMenu/volumeSlider
@onready var VolumeMenu: VBoxContainer = $ButtonsCenter/volumenContainer/VolumeMenu
@onready var MainButtons: VBoxContainer = $ButtonsCenter/Buttons
@onready var VolumeContainer: Control = $ButtonsCenter/volumenContainer
@onready var _back: Button = $ButtonsCenter/volumenContainer/VolumeMenu/BackButton



func _ready() -> void:
	if Game.multiplayer_test:
		get_tree().change_scene_to_file("res://lobby/lobby_test.tscn")
		return
	
	quit.pressed.connect(func(): get_tree().quit())
	host.pressed.connect(func(): get_tree().change_scene_to_file("res://lobby/host_screen.tscn"))
	join.pressed.connect(func(): get_tree().change_scene_to_file("res://lobby/join_screen.tscn"))
	tutorial.pressed.connect(_start_tutorial)
	credits.pressed.connect(func(): get_tree().change_scene_to_file("res://ui/credits.tscn"))
	_volume.pressed.connect(_on_volume_pressed)
	_back.pressed.connect(_on_back_pressed)
	var music_bus := AudioServer.get_bus_index("Music")
	music_slider.min_value= 0
	music_slider.max_value = 1
	music_slider.step = 0.01
	music_slider.value  = db_to_linear(AudioServer.get_bus_volume_db(music_bus)) 
	music_slider.value_changed.connect(_on_music_volume_changed)
	
	host.grab_focus()
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
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(value))



func _start_tutorial() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(Statics.PORT, Statics.MAX_CLIENTS)
	if err != OK:
		return
	multiplayer.multiplayer_peer = peer
	Game.players.clear()
	var player := Statics.PlayerData.new(1, "Tutorial", 0)
	player.role = Statics.Role.ROLE_A
	player.team = Statics.Team.TEAM_BLACK
	player.sabotaje = Statics.Sabotaje.PORTAL_TRAMPA
	Game.add_player(player)
	Game.update_player_id()
	get_tree().change_scene_to_file("res://tutorial/tutorial.tscn")
