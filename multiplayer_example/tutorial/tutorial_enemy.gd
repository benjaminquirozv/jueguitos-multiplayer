extends CharacterBody2D

const PATROL_SPEED := 40.0
const PATROL_RANGE := 16.0

const SABOTAGE_ORDER := [
	Statics.Sabotaje.VELOCIDAD_LENTA,
	Statics.Sabotaje.CONTROLES_INVERTIDOS,
	Statics.Sabotaje.PANTALLA_OSCURA,
	Statics.Sabotaje.PORTAL_TRAMPA,
]

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var effect_label: Label = $EffectLabel

var _sabotaje_activo: Statics.Sabotaje = Statics.Sabotaje.NINGUNO
var _efecto_restante := 0.0
var _start_x: float
var _direction := 1.0


func _ready() -> void:
	_start_x = position.x
	effect_label.text = ""
	anim.play("walk")


func _physics_process(delta: float) -> void:
	if _efecto_restante > 0.0:
		_efecto_restante -= delta
		if _efecto_restante <= 0.0:
			_quitar_efecto()
		else:
			effect_label.text = "⚠ %s (%.0fs)" % [
				Statics.get_sabotaje_name(_sabotaje_activo), _efecto_restante
			]

	var speed := PATROL_SPEED
	if _sabotaje_activo == Statics.Sabotaje.VELOCIDAD_LENTA:
		speed *= 0.2

	var move_dir := _direction
	if _sabotaje_activo == Statics.Sabotaje.CONTROLES_INVERTIDOS:
		move_dir = -move_dir

	velocity = Vector2(move_dir * speed, 0.0)
	move_and_slide()

	if position.x > _start_x + PATROL_RANGE:
		_direction = -1.0
	elif position.x < _start_x - PATROL_RANGE:
		_direction = 1.0

	anim.flip_h = _direction < 0.0


# Llamado vía RPC por el jugador cuando presiona ESPACIO cerca del enemigo
# (mismo mecanismo que en una partida real, ver player.gd::_intentar_sabotaje).
@rpc("any_peer", "reliable", "call_local")
func recibir_sabotaje(tipo: Statics.Sabotaje, duracion: float) -> void:
	_sabotaje_activo = tipo
	_efecto_restante = duracion
	effect_label.text = "⚠ %s (%.0fs)" % [Statics.get_sabotaje_name(tipo), duracion]
	_avanzar_sabotaje_jugador()


func _quitar_efecto() -> void:
	_sabotaje_activo = Statics.Sabotaje.NINGUNO
	_efecto_restante = 0.0
	effect_label.text = ""


# Deja listo el siguiente sabotaje equipado para que el jugador pueda
# probarlos todos contra el enemigo sin volver al lobby a elegir.
func _avanzar_sabotaje_jugador() -> void:
	var my_data = Game.get_current_player()
	if my_data == null:
		return
	var idx := SABOTAGE_ORDER.find(my_data.sabotaje)
	var siguiente: Statics.Sabotaje = SABOTAGE_ORDER[(idx + 1) % SABOTAGE_ORDER.size()]
	Game.set_current_player_sabotaje(siguiente)
