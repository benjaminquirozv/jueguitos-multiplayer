extends CharacterBody2D

@export var velocidad = 200.0
@onready var anim = $AnimatedSprite2D
@onready var collision = $CollisionShape2D

# Sprite según role (el personaje)
const SPRITE_FRAMES = {
	Statics.Role.ROLE_A: preload("res://characters/players/frames_black.tres"),
	Statics.Role.ROLE_B: preload("res://characters/players/frames_white.tres"),
	Statics.Role.ROLE_C: preload("res://characters/players/frames_black.tres"),
	Statics.Role.ROLE_D: preload("res://characters/players/frames_white.tres"),
}

# Color según team
const TINTES = {
	Statics.Team.TEAM_BLACK: Color(0.3, 0.3, 0.3),  # oscuro
	Statics.Team.TEAM_WHITE: Color(1.0, 1.0, 1.0),  # claro/normal
}

const SCALES = {
	Statics.Role.NONE:   Vector2(1.0, 1.0),  # ← agregar esto
	Statics.Role.ROLE_A: Vector2(0.5, 0.5),
	Statics.Role.ROLE_B: Vector2(0.5, 0.5),
	Statics.Role.ROLE_C: Vector2(1.0, 1.0),
	Statics.Role.ROLE_D: Vector2(1.0, 1.0),
}

# ── CONFIGURACIÓN SABOTAJE ────────────────────────────────────────────────────
const RANGO_SABOTAJE    := 500.0  # Distancia máxima para afectar al más cercano
const DURACION_EFECTO   := 30.0   # Segundos que dura el sabotaje sobre la víctima
const COOLDOWN_SABOTAJE := 60.0   # Segundos de espera antes de poder usar de nuevo
# ─────────────────────────────────────────────────────────────────────────────

# Timers propios (solo activos en el jugador local)
var _cooldown_restante  := 0.0  # Cuánto falta para poder usar el sabotaje de nuevo
var _efecto_restante    := 0.0  # Cuánto falta para que se te quite el efecto

# Nodo de UI para mostrar cooldown y efecto activo — se crea en _ready
var _label_ui: Label


func _ready():
	$Camera2D.enabled = is_multiplayer_authority()
	if not Game.player_updated.is_connected(_on_player_updated):
		Game.player_updated.connect(_on_player_updated)
	if not Game.players_updated.is_connected(_update_visual):
		Game.players_updated.connect(_update_visual)
	#Outline	
	var mat = ShaderMaterial.new()
	mat.shader = preload("res://player/player.gdshader")
	anim.material = mat
	_update_visual()

	# Crear label de HUD solo para el jugador local
	if is_multiplayer_authority():
		_label_ui = Label.new()
		_label_ui.position = Vector2(-50, -80)
		_label_ui.z_index = 10
		_label_ui.add_theme_font_size_override("font_size", 12)
		add_child(_label_ui)
	var my_data = Game.get_player(name.to_int())
	if my_data != null and my_data.team == Statics.Team.TEAM_BLACK:
		scale = Vector2(0.5, 0.5)
	else:
		scale = Vector2(1.0, 1.0)


func _enter_tree():
	set_multiplayer_authority(name.to_int())


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return

	var my_data = Game.get_current_player()

	# ── Actualizar timers ─────────────────────────────────────────────────────
	if _cooldown_restante > 0.0:
		_cooldown_restante -= delta

	if _efecto_restante > 0.0:
		_efecto_restante -= delta
		if _efecto_restante <= 0.0:
			# El efecto que me estaban aplicando terminó
			_quitar_efecto_local()

	# ── UI: mostrar estado al jugador local ───────────────────────────────────
	if _label_ui:
		var texto := ""
		if _cooldown_restante > 0.0:
			texto += "Sabotaje: %.0fs\n" % _cooldown_restante
		else:
			texto += "Sabotaje: LISTO\n"
		if my_data and my_data.sabotaje_activo != Statics.Sabotaje.NINGUNO:
			texto += "⚠ %s (%.0fs)" % [
				Statics.get_sabotaje_name(my_data.sabotaje_activo),
				_efecto_restante
			]
		_label_ui.text = texto

	# ── ESPACIO: lanzar sabotaje ──────────────────────────────────────────────
	if Input.is_action_just_pressed("ui_accept"):  # ui_accept = barra espaciadora
		_intentar_sabotaje()
	# ─────────────────────────────────────────────────────────────────────────

	# ── Movimiento ────────────────────────────────────────────────────────────
	var direccion = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# EFECTO: Controles invertidos
	if my_data and my_data.sabotaje_activo == Statics.Sabotaje.CONTROLES_INVERTIDOS:
		direccion = -direccion

	if direccion != Vector2.ZERO:
		anim.play("walk")

	# EFECTO: Velocidad lenta
	var vel_actual = velocidad
	if my_data and my_data.sabotaje_activo == Statics.Sabotaje.VELOCIDAD_LENTA:
		vel_actual = velocidad * 0.2

	velocity = direccion * vel_actual
	move_and_slide()


# ── LANZAR SABOTAJE ───────────────────────────────────────────────────────────
func _intentar_sabotaje() -> void:
	var my_data = Game.get_current_player()
	if my_data == null:
		return

	# No tiene sabotaje elegido
	if my_data.sabotaje == Statics.Sabotaje.NINGUNO:
		return

	# Todavía en cooldown
	if _cooldown_restante > 0.0:
		return

	# Buscar al jugador más cercano dentro del rango
	var victima = _buscar_victima_mas_cercana()
	if victima == null:
		return  # Nadie en rango

	# Aplicar el sabotaje a la víctima vía RPC (se ejecuta en TODOS los peers)
	# Llamamos al método del nodo de la víctima directamente usando su nombre (= su ID de red)
	var victima_node = get_parent().get_node_or_null(str(victima.id))
	if victima_node == null:
		return

	victima_node.recibir_sabotaje.rpc(my_data.sabotaje, DURACION_EFECTO)
	_cooldown_restante = COOLDOWN_SABOTAJE


func _buscar_victima_mas_cercana() -> Statics.PlayerData:
	var mi_id    = multiplayer.get_unique_id()
	var mi_pos   = global_position
	var mas_cerca: Statics.PlayerData = null
	var dist_min := INF

	for player_data in Game.players:
		if player_data.id == mi_id:
			continue  # No me saboteo a mí mismo

		# Buscar el nodo del jugador en la escena
		var nodo = get_parent().get_node_or_null(str(player_data.id))
		if nodo == null:
			continue

		var dist = mi_pos.distance_to(nodo.global_position)
		if dist < dist_min and dist <= RANGO_SABOTAJE:
			dist_min  = dist
			mas_cerca = player_data

	return mas_cerca
# ─────────────────────────────────────────────────────────────────────────────


# ── RECIBIR SABOTAJE (llamado por RPC desde el atacante) ──────────────────────
# Se ejecuta en TODOS los peers, pero solo el jugador cuyo ID coincide
# con este nodo actúa (los demás actualizan el dato en Game.players).
@rpc("any_peer", "reliable", "call_local")
func recibir_sabotaje(tipo: Statics.Sabotaje, duracion: float) -> void:
	var victim_data = Game.get_player(name.to_int())
	if victim_data == null:
		return

	victim_data.sabotaje_activo = tipo

	# Solo el jugador víctima gestiona su propio timer y efectos locales
	if is_multiplayer_authority():
		_efecto_restante = duracion
		_aplicar_efecto_local(tipo)


func _aplicar_efecto_local(tipo: Statics.Sabotaje) -> void:
	# La pantalla oscura necesita hablar con el nivel para activar la niebla.
	# Los otros efectos (velocidad, controles) se aplican directo en _physics_process.
	if tipo == Statics.Sabotaje.PANTALLA_OSCURA:
		var nivel = get_tree().current_scene
		if nivel.has_method("activar_pantalla_oscura"):
			nivel.activar_pantalla_oscura()


func _quitar_efecto_local() -> void:
	var my_data = Game.get_current_player()
	if my_data == null:
		return

	var tipo_anterior = my_data.sabotaje_activo
	my_data.sabotaje_activo = Statics.Sabotaje.NINGUNO

	if tipo_anterior == Statics.Sabotaje.PANTALLA_OSCURA:
		var nivel = get_tree().current_scene
		if nivel.has_method("desactivar_pantalla_oscura"):
			nivel.desactivar_pantalla_oscura()
# ─────────────────────────────────────────────────────────────────────────────


# ── PORTAL TRAMPA: llamado desde portal_lvl.gd / portal_rec.gd ───────────────
# Teletransporta al jugador al inicio. Solo lo llama la víctima (authority).
func ir_al_inicio() -> void:
	var nivel = get_tree().current_scene
	var spawnpoints = nivel.get_node_or_null("spawnpoints")
	if spawnpoints and spawnpoints.get_child_count() > 0:
		global_position = spawnpoints.get_child(0).global_position
# ─────────────────────────────────────────────────────────────────────────────


func _on_player_updated(id: int) -> void:
	if id == name.to_int() or id == multiplayer.get_unique_id():
		_update_visual()
const OUTLINE_COLORS = {
	Statics.Team.TEAM_BLACK: Color(0, 0, 0, 1),
	Statics.Team.TEAM_WHITE: Color(1, 1, 1, 1),
}
func _update_visual() -> void:
	var this_player  = Game.get_player(name.to_int())
	var local_player = Game.get_current_player()
	

	if this_player == null or local_player == null:
		return
	scale = SCALES.get(this_player.role, Vector2(1.0, 1.0))

	# Sprite según role
	if SPRITE_FRAMES.has(this_player.role):
		anim.sprite_frames = SPRITE_FRAMES[this_player.role]

	# Tinte según team
	if TINTES.has(this_player.team):
		anim.modulate = TINTES[this_player.team]
	#outline según el equipo
	if OUTLINE_COLORS.has(this_player.team):
		anim.material.set_shader_parameter("outline_color", OUTLINE_COLORS[this_player.team])
		anim.material.set_shader_parameter("outline_width", 3)

	# ── Visibilidad para jugadores remotos ──
	if is_multiplayer_authority():
		modulate.a = 1.0
		return

	if not Statics.can_see_role(local_player.role, this_player.role):
		visible = false
		collision.disabled = true
		return
	else:
		visible = true
		collision.disabled = false

	if Statics.are_teammates(local_player.role, this_player.role):
		set_ghost_visual()
	else:
		set_normal_visual()
		
				
func set_ghost_visual() -> void:
	modulate.a = 0.35

func set_normal_visual() -> void:
	modulate.a = 1.0
	var this_player = Game.get_player(name.to_int())
	if this_player and TINTES.has(this_player.role):
		anim.modulate = TINTES[this_player.role]
