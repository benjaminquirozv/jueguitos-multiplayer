extends Area2D

@onready var label_portal = $LabelFinal
var jugadores_en_zona: Array = []
var equipo_habilitado = null 

func _ready():
	label_portal.visible = false
	# Conectamos las señales de colisión por código
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node):
	if not body is CharacterBody2D: return
	
	# En tu script, los jugadores se llaman como su ID, así que lo buscamos así:
	var player_data = Game.get_player(body.name.to_int())
	if player_data != null and not jugadores_en_zona.has(player_data):
		jugadores_en_zona.append(player_data)
		
	_revisar_condicion()

func _on_body_exited(body: Node):
	if not body is CharacterBody2D: return
	
	var player_data = Game.get_player(body.name.to_int())
	if player_data != null and jugadores_en_zona.has(player_data):
		jugadores_en_zona.erase(player_data)
		
	_revisar_condicion()

func _revisar_condicion():
	var jugadores_listos = 0
	var equipo_potencial = null

	for p in jugadores_en_zona:
		if Game.team_has_all_stars(p.team):
			jugadores_listos += 1
			equipo_potencial = p.team

	# --- LÓGICA DE TEXTOS ACTUALIZADA ---
	if jugadores_listos >= 2:
		equipo_habilitado = equipo_potencial
		label_portal.text = "Apreta la tecla 'P' para activar el portal"
		label_portal.visible = true
	elif jugadores_listos == 1:
		equipo_habilitado = null
		label_portal.text = "Esperando a tu compañero..."
		label_portal.visible = true
	else:
		equipo_habilitado = null
		label_portal.visible = false

func _process(_delta):
	# Si la condición se cumple y alguien aprieta la P
	if equipo_habilitado != null and Input.is_key_pressed(KEY_P):
		# Desactivamos el _process para que no manden el RPC 50 veces por frame
		set_process(false) 
		# Llamamos a tu función que ya está lista en Game.gd
		Game.finalizar_partida.rpc(equipo_habilitado)
