extends CharacterBody2D

@export var velocidad = 200.0
@onready var anim = $AnimatedSprite2D
@onready var collision = $CollisionShape2D
@onready var footsteps = $footsteps


# Sprite según EQUIPO (ambos roles del mismo equipo comparten sprite)
const SPRITE_FRAMES = {
	Statics.Role.ROLE_A: preload("res://characters/players/frames_black.tres"),
	Statics.Role.ROLE_B: preload("res://characters/players/frames_black.tres"),
	Statics.Role.ROLE_C: preload("res://characters/players/frames_white.tres"),
	Statics.Role.ROLE_D: preload("res://characters/players/frames_white.tres"),
}
# Color según team
const TINTES = {
	Statics.Team.TEAM_BLACK: Color(0.3, 0.3, 0.3),  # oscuro
	Statics.Team.TEAM_WHITE: Color(1.0, 1.0, 1.0),  # claro/normal
}

# Escala SOLO del sprite (no del cuerpo) para compensar que las hojas de
# animación tienen tamaños nativos distintos (black = 64px, white = 24px)
# y así se vean todos del mismo tamaño en pantalla, sin tocar cámara ni colisión.
const SPRITE_SCALES = {
	Statics.Role.NONE:   Vector2(1.0, 1.0),
	Statics.Role.ROLE_A: Vector2(0.46875, 0.46875), # 64px -> ~30px
	Statics.Role.ROLE_B: Vector2(0.46875, 0.46875),
	Statics.Role.ROLE_C: Vector2(1.25, 1.25),       # 24px -> 30px
	Statics.Role.ROLE_D: Vector2(1.25, 1.25),
}

# ── CONFIGURACIÓN SABOTAJE ────────────────────────────────────────────────────
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


func _enter_tree():
	set_multiplayer_authority(name.to_int())


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return
	if Input.is_key_pressed(KEY_P):
		print("PLAYER POS: ", global_position)

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
		if my_data and my_data.sabotaje != Statics.Sabotaje.NINGUNO:
			texto += "Equipado: %s\n" % Statics.get_sabotaje_name(my_data.sabotaje)
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
	var congelado : bool = my_data and my_data.sabotaje_activo == Statics.Sabotaje.FREEZE
	if Input.is_action_just_pressed("ui_accept") and not congelado:
		_intentar_sabotaje()
	# ─────────────────────────────────────────────────────────────────────────

	# ── Movimiento ────────────────────────────────────────────────────────────
	var direccion = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	#Si se mueve se escuchan pasos 
	if direccion != Vector2.ZERO:
		anim.play("walk")

		if !footsteps.playing:
			footsteps.play()
	else:
		anim.stop()

		if footsteps.playing:
			footsteps.stop()
	# EFECTO: Controles invertidos
	if my_data and my_data.sabotaje_activo == Statics.Sabotaje.CONTROLES_INVERTIDOS:
		direccion = -direccion

	if direccion != Vector2.ZERO:
		anim.play("walk")
		if not footsteps.playing:
			footsteps.play()
	else:
		anim.play("idle")
		if footsteps.playing:
			footsteps.stop()
			
	# EFECTO: Freeze
	if my_data and my_data.sabotaje_activo == Statics.Sabotaje.FREEZE:
		direccion = Vector2.ZERO

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
	var victima = _buscar_victima_al_azar()
	if victima == null:
		return  # Nadie en rango

	# Aplicar el sabotaje a la víctima vía RPC (se ejecuta en TODOS los peers)
	# Llamamos al método del nodo de la víctima directamente usando su nombre (= su ID de red)
	var victima_node = get_parent().get_node_or_null(str(victima.id))
	if victima_node == null:
		return

	victima_node.recibir_sabotaje.rpc(my_data.sabotaje, DURACION_EFECTO)
	_cooldown_restante = COOLDOWN_SABOTAJE


func _buscar_victima_al_azar() -> Statics.PlayerData:
	var mi_id   = multiplayer.get_unique_id()
	var mi_data = Game.get_current_player()
	if mi_data == null:
		return null

	var candidatos: Array[Statics.PlayerData] = []
	for player_data in Game.players:
		if player_data.id == mi_id:
			continue  # No me saboteo a mí mismo
		if player_data.team == mi_data.team:
			continue  # Es de mi equipo, no es un objetivo válido

		candidatos.append(player_data)

	if candidatos.is_empty():
		return null

	return candidatos[randi() % candidatos.size()]
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
	# El cuerpo (CharacterBody2D) NO se escala: eso afectaba la cámara y el hitbox real.
	scale = Vector2(1.0, 1.0)

	# Sprite según equipo, escalado solo visualmente para que todos midan igual
	if SPRITE_FRAMES.has(this_player.role):
		anim.sprite_frames = SPRITE_FRAMES[this_player.role]
	anim.scale = SPRITE_SCALES.get(this_player.role, Vector2(1.0, 1.0))
	# Tinte según team
	if TINTES.has(this_player.team):
		anim.modulate = TINTES[this_player.team]
	#outline según el equipo
	if OUTLINE_COLORS.has(this_player.team):
		anim.material.set_shader_parameter("outline_color", OUTLINE_COLORS[this_player.team])
		anim.material.set_shader_parameter("outline_width", 3)

	# ── Visibilidad para jugadores remotos ──
	if is_multiplayer_authority():
		set_normal_visual()
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
