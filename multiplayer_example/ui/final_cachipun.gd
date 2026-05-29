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
var player_choices: Dictionary = {}
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

# Texturas para cada elección
var hand_textures := {
	Choice.ROCK: preload("res://sprites/hand_rock.png"),
	Choice.PAPER: preload("res://sprites/hand_paper.png"),
	Choice.SCISSORS: preload("res://sprites/hand_scissors.png")
}


func _ready() -> void:
	_setup_ui()
	_connect_signals()
	_start_game()


func _setup_ui() -> void:
	_selection_menu.hide()
	_result_label.hide()
	_countdown_label.hide()
	_hand_sprite.texture = hand_textures[Choice.ROCK]
	
	# Mostrar jugadores en el piso
	_setup_players_display()
	
	# Animación de entrada de la mano
	_animate_hand_entrance()


func _connect_signals() -> void:
	_rock_btn.pressed.connect(_on_choice_selected.bind(Choice.ROCK))
	_paper_btn.pressed.connect(_on_choice_selected.bind(Choice.PAPER))
	_scissors_btn.pressed.connect(_on_choice_selected.bind(Choice.SCISSORS))


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
		
	var player_id = multiplayer.get_unique_id()
	
	# Enviar elección a todos los jugadores
	_register_player_choice.rpc(player_id, choice)


@rpc("any_peer", "call_local", "reliable")
func _register_player_choice(player_id: int, choice: Choice) -> void:
	player_choices[player_id] = choice
	
	# Verificar si todos los jugadores han elegido o si es suficiente
	_check_if_ready_to_play()


func _check_if_ready_to_play() -> void:
	# Por simplicidad, cuando al menos 1 jugador elige, se procede
	# Podrías ajustar esto para esperar a todos los jugadores ganadores
	if player_choices.size() > 0:
		_calculate_team_choice()
		_play_round()


func _calculate_team_choice() -> void:
	# Estrategia: usar la elección más popular del equipo
	var choice_counts := {Choice.ROCK: 0, Choice.PAPER: 0, Choice.SCISSORS: 0}
	
	for choice in player_choices.values():
		choice_counts[choice] += 1
	
	# Encontrar la elección con más votos
	var max_votes = 0
	final_choice = Choice.ROCK
	
	for choice in choice_counts:
		if choice_counts[choice] > max_votes:
			max_votes = choice_counts[choice]
			final_choice = choice


func _play_round() -> void:
	if not multiplayer.is_server():
		return
		
	current_state = GameState.SHOWING_RESULT
	
	# La mano enemiga elige al azar
	enemy_choice = [Choice.ROCK, Choice.PAPER, Choice.SCISSORS].pick_random()
	
	# Calcular resultado
	var result = _calculate_result(final_choice, enemy_choice)
	
	# Enviar resultado a todos
	_show_game_result.rpc(final_choice, enemy_choice, result)


@rpc("authority", "call_local", "reliable")
func _show_game_result(team_choice: Choice, hand_choice: Choice, result: String) -> void:
	final_choice = team_choice
	enemy_choice = hand_choice
	game_result = result
	
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
	
	# Auto-reiniciar después de unos segundos
	await get_tree().create_timer(4.0).timeout
	_restart_game()

func _setup_players_display() -> void:
	for child in _players_container.get_children():
		child.queue_free()
	
	var player_count = 0
	for player in Game.players:
		var player_label = Label.new()
		player_label.text = "🎮 %s" % player.name
		player_label.add_theme_font_size_override("font_size", 32)  # ✅
		player_label.add_theme_color_override("font_color", Color.CYAN)  # ✅
		player_label.position = Vector2(player_count * 100, -30 - (player_count * 25))
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


func _calculate_result(team: Choice, hand: Choice) -> String:
	if team == hand:
		return "¡EMPATE!"
	elif (team == Choice.ROCK and hand == Choice.SCISSORS) or \
		 (team == Choice.PAPER and hand == Choice.ROCK) or \
		 (team == Choice.SCISSORS and hand == Choice.PAPER):
		return "¡EL EQUIPO GANA!"
	else:
		return "¡LA MANO GANA!"


func _choice_to_string(choice: Choice) -> String:
	match choice:
		Choice.ROCK: return "Piedra"
		Choice.PAPER: return "Papel"
		Choice.SCISSORS: return "Tijera"
		_: return "Ninguna"


func _restart_game() -> void:
	player_choices.clear()
	final_choice = Choice.NONE
	enemy_choice = Choice.NONE
	current_state = GameState.SELECTING
	_hand_sprite.texture = hand_textures[Choice.ROCK]
	_show_selection_menu()


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
	tween.tween_property(_hand_sprite, "position:x", screen_width - 450, 0.1)
	tween.tween_property(_hand_sprite, "position:x", screen_width - 500, 0.1)
	
	tween.tween_callback(_start_game)
