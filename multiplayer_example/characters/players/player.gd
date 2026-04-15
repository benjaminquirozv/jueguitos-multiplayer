extends CharacterBody2D


const SPEED = 300.0
@export var velocidad = 200.0

func _physics_process(delta: float) -> void:

	# As good practice, you should replace UI actions with custom gameplay actions.
	var direccion = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	velocity = direccion * velocidad
	
	move_and_slide()
