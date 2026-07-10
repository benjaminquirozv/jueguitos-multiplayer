extends Control

enum Choice {
	NONE,
	ROCK,    # Piedra
	PAPER,   # Papel  
	SCISSORS # Tijera
}

enum GameState {
	WAITING_PLAYERS,
	SELECTING,
	SHOWING_RESULT,
	FINISHED
}

var current_state := GameState.WAITING_PLAYERS
var final_choice := Choice.NONE
var enemy_choice := Choice.NONE
var game_result := ""

@onready var _hand_sprite: TextureRect = %HandSprite
@onready var _selection_menu: Control = %SelectionMenu
@onready var _rock_btn: Button = %RockButton
@onready var _paper_btn: Button = %PaperButton
@onready var _scissors_btn: Button = %ScissorsButton
@onready var _result_label: Label = %ResultLabel
@onready var _countdown_label: Label = %CountdownLabel
@onready var _players_container: Control = %PlayersContainer
@onready var _idle_sprite: Sprite2D = %IdleDown
@onready var _floor: TileMapLayer = %Floor
@onready var _end_screen: TextureRect = %EndScreen
@onready var _end_background: ColorRect = %EndBackground

const FLOOR_TILE := Vector2i(3, 0)
const TILE_SIZE := 16

const RESULT_TIE := "¡EMPATE!"
const RESULT_TEAM_WINS := "¡EL EQUIPO GANA!"
const RESULT_HAND_WINS := "¡LA MANO GANA!"

const WIN_TEXTURE := preload("res://ui/backgrounds/winner.png")
const GAMEOVER_TEXTURE := preload("res://ui/backgrounds/gameover.png")

# Texturas para cada elección
var hand_textures := {
	Choice.ROCK: preload("res://sprites/hand_rock.png"),
	Choice.PAPER: preload("res://sprites/hand_paper.png"),
	Choice.SCISSORS: preload("res://sprites/hand_scissors.png")
}


func _ready() -> void:
	Game.reset_cachipun()
	_setup_ui()
	_connect_signals()
	# _start_game() se dispara solo una vez, al terminar la animación
	# de entrada de la mano (ver _animate_hand_entrance).


func _exit_tree() -> void:
	if Game.cachipun_round_result.is_connected(_on_cachipun_round_result):
		Game.cachipun_round_result.disconnect(_on_cachipun_round_result)


func _setup_ui() -> void:
	_selection_menu.hide()
	_result_label.hide()
	_countdown_label.hide()
	_hand_sprite.texture = hand_textures[Choice.ROCK]

	_setup_stage()

	# Mostrar jugadores en el piso
	_setup_players_display()
	
	# Animación de entrada de la mano
	_animate_hand_entrance()


func _connect_signals() -> void:
	_rock_btn.pressed.connect(_on_choice_selected.bind(Choice.ROCK))
	_paper_btn.pressed.connect(_on_choice_selected.bind(Choice.PAPER))
	_scissors_btn.pressed.connect(_on_choice_selected.bind(Choice.SCISSORS))
	Game.cachipun_round_result.connect(_on_cachipun_round_result)


func _start_game() -> void:
	current_state = GameState.SELECTING
	await get_tree().create_timer(0.5).timeout  # Pausa dramática
	_show_selection_menu()


func _show_selection_menu() -> void:
	_selection_menu.show()
	_result_label.hide()
	_countdown_label.text = "¡Elige tu jugada!"
	_countdown_label.show()


func _on_choice_selected(choice: Choice) -> void:
	if current_state != GameState.SELECTING:
		return
	# RPCs viven en Game (autoload): los perdedores no tienen esta escena.
	Game.submit_cachipun_choice(int(choice))


func _on_cachipun_round_result(team_choice: int, hand_choice: int, result: String) -> void:
	await _show_game_result(team_choice as Choice, hand_choice as Choice, result)


func _show_game_result(team_choice: Choice, hand_choice: Choice, result: String) -> void:
	final_choice = team_choice
	enemy_choice = hand_choice
	game_result = result
	current_state = GameState.SHOWING_RESULT
	
	# Ocultar menú de selección
	_selection_menu.hide()
	_countdown_label.text = "¡Mostrando jugadas!"
	
	# Animación de revelación
	await _animate_choices_reveal(team_choice, hand_choice)
	
	# Mostrar resultado final
	_result_label.text = "Equipo: %s vs Mano: %s\n\n%s" % [
		_choice_to_string(team_choice),
		_choice_to_string(hand_choice), 
		result
	]
	_result_label.show()
	_countdown_label.hide()
	
	# Solo el empate permite repetir la jugada. Ganar o perder termina la partida.
	match result:
		RESULT_TIE, Game.CACHIPUN_TIE:
			await get_tree().create_timer(4.0).timeout
			_restart_game()
		RESULT_TEAM_WINS, Game.CACHIPUN_TEAM_WINS:
			await get_tree().create_timer(2.5).timeout
			_show_end_screen(WIN_TEXTURE)
		RESULT_HAND_WINS, Game.CACHIPUN_HAND_WINS:
			await get_tree().create_timer(2.5).timeout
			_show_end_screen(GAMEOVER_TEXTURE)

func _setup_stage() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var floor_row := int(viewport_size.y / TILE_SIZE) - 4
	var tiles_x := int(ceil(viewport_size.x / float(TILE_SIZE))) + 2

	for x in range(tiles_x):
		for y in range(floor_row, floor_row + 3):
			_floor.set_cell(Vector2i(x, y), 0, FLOOR_TILE)

	var floor_y := floor_row * TILE_SIZE
	var sprite_height := _idle_sprite.get_rect().size.y * _idle_sprite.scale.y
	_idle_sprite.position = Vector2(viewport_size.x * 0.27, floor_y - sprite_height * 0.45)


func _setup_players_display() -> void:
	for child in _players_container.get_children():
		child.queue_free()

	var player_count := 0
	for player in Game.players:
		var player_label := Label.new()
		player_label.text = "%s" % player.name
		player_label.add_theme_font_size_override("font_size", 28)
		var color := Color.CYAN if Statics.get_team_from_role(player.role) == Statics.Team.TEAM_BLACK else Color.WHITE
		player_label.add_theme_color_override("font_color", color)
		# Stack labels horizontally above the floor
		player_label.position = Vector2(player_count * 160, 0)
		_players_container.add_child(player_label)
		player_count += 1

func _animate_choices_reveal(team_choice: Choice, hand_choice: Choice) -> void:
	# Cuenta regresiva dramática
	for i in range(3, 0, -1):
		_countdown_label.text = str(i)
		# Pequeño movimiento de anticipación de la mano
		_animate_hand_anticipation()
		await get_tree().create_timer(0.8).timeout
	
	_countdown_label.text = "¡YA!"
	await get_tree().create_timer(0.3).timeout
	
	# Animación de "punch" hacia adelante al mostrar la elección
	_animate_hand_reveal(hand_choice)


func _animate_hand_anticipation() -> void:
	# Pequeño movimiento de retroceso como preparación
	var tween = create_tween()
	var current_x = _hand_sprite.position.x
	tween.set_parallel(true)
	tween.tween_property(_hand_sprite, "position:x", current_x + 20, 0.1)
	tween.tween_property(_hand_sprite, "position:x", current_x, 0.1).set_delay(0.1)


func _animate_hand_reveal(hand_choice: Choice) -> void:
	var tween = create_tween()
	var current_x = _hand_sprite.position.x
	
	# Movimiento hacia adelante (punch effect)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	# Cambiar textura y animar hacia adelante
	_hand_sprite.texture = hand_textures[hand_choice]
	tween.tween_property(_hand_sprite, "position:x", current_x - 80, 0.3)
	
	# Efecto de flash
	tween.tween_property(_hand_sprite, "modulate", Color.WHITE * 1.5, 0.1)
	tween.tween_property(_hand_sprite, "modulate", Color.WHITE, 0.1)
	
	# Regresar a posición original
	tween.tween_property(_hand_sprite, "position:x", current_x, 0.2)


func _choice_to_string(choice: Choice) -> String:
	match choice:
		Choice.ROCK: return "Piedra"
		Choice.PAPER: return "Papel"
		Choice.SCISSORS: return "Tijera"
		_: return "Ninguna"


func _restart_game() -> void:
	Game.reset_cachipun()
	final_choice = Choice.NONE
	enemy_choice = Choice.NONE
	current_state = GameState.SELECTING
	_hand_sprite.texture = hand_textures[Choice.ROCK]
	_show_selection_menu()


func _show_end_screen(texture: Texture2D) -> void:
	current_state = GameState.FINISHED
	_result_label.hide()
	_selection_menu.hide()
	_end_background.show()
	_end_screen.texture = texture
	_end_screen.show()
	await get_tree().create_timer(3.0).timeout
	Lobby.go_to_menu()


func _animate_hand_entrance() -> void:
	# Animación de entrada de la mano desde el lado derecho (horizontal)
	var tween = create_tween()
	var screen_width = get_viewport().get_visible_rect().size.x

	# Comenzar fuera de pantalla por la derecha
	_hand_sprite.position.x = screen_width + 400

	# Animar entrada horizontal con efecto de "punch" como en el gif
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(_hand_sprite, "position:x", screen_width - 500, 1.2)

	# Pequeño rebote al final
	tween.tween_property(_hand_sprite, "position:x", screen_width - 550, 0.1)
	tween.tween_property(_hand_sprite, "position:x", screen_width - 600, 0.1)
	
	tween.tween_callback(_start_game)
