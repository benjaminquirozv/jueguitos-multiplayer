class_name MainMenu
extends Control


@onready var host: Button = %Host
@onready var join: Button = %Join
@onready var tutorial: Button = %Tutorial
@onready var credits: Button = %Credits
@onready var quit: Button = %Quit


func _ready() -> void:
	if Game.multiplayer_test:
		get_tree().change_scene_to_file("res://lobby/lobby_test.tscn")
		return
	
	quit.pressed.connect(func(): get_tree().quit())
	host.pressed.connect(func(): get_tree().change_scene_to_file("res://lobby/host_screen.tscn"))
	join.pressed.connect(func(): get_tree().change_scene_to_file("res://lobby/join_screen.tscn"))
	tutorial.pressed.connect(_start_tutorial)
	credits.pressed.connect(func(): get_tree().change_scene_to_file("res://ui/credits.tscn"))
	
	host.grab_focus()


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
