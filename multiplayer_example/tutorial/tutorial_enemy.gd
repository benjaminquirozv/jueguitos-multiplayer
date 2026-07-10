extends CharacterBody2D

const PATROL_SPEED := 40.0
const PATROL_RANGE := 16.0
# Slow Motion muy notorio: ~8% de la velocidad normal.
const SLOW_SPEED_FACTOR := 0.08
const SLOW_ANIM_SPEED := 0.2

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var effect_label: Label = $EffectLabel

var _ralentizado := false
var _efecto_restante := 0.0
var _start_x: float
var _direction := 1.0


func _ready() -> void:
	_start_x = position.x
	effect_label.text = ""
	anim.play("walk")
	add_to_group("Enemy")


func _physics_process(delta: float) -> void:
	if _efecto_restante > 0.0:
		_efecto_restante -= delta
		if _efecto_restante <= 0.0:
			_quitar_efecto()
		else:
			effect_label.text = "⚠ Slow Motion (%.0fs)" % _efecto_restante

	var speed := PATROL_SPEED
	if _ralentizado:
		speed *= SLOW_SPEED_FACTOR

	velocity = Vector2(_direction * speed, 0.0)
	move_and_slide()

	if position.x > _start_x + PATROL_RANGE:
		_direction = -1.0
	elif position.x < _start_x - PATROL_RANGE:
		_direction = 1.0

	anim.flip_h = _direction < 0.0
	anim.speed_scale = SLOW_ANIM_SPEED if _ralentizado else 1.0


@rpc("any_peer", "reliable", "call_local")
func recibir_sabotaje(_tipo: Statics.Sabotaje, duracion: float) -> void:
	aplicar_slow(duracion)


func aplicar_slow(duracion: float) -> void:
	_ralentizado = true
	_efecto_restante = duracion
	if effect_label:
		effect_label.text = "⚠ Slow Motion (%.0fs)" % duracion
	if anim:
		anim.modulate = Color(0.45, 0.75, 1.0)


func _quitar_efecto() -> void:
	_ralentizado = false
	_efecto_restante = 0.0
	if effect_label:
		effect_label.text = ""
	if anim:
		anim.modulate = Color.WHITE
		anim.speed_scale = 1.0
