extends CharacterBody2D

@export var velocidad = 200.0

func _ready():
	# Si este personaje es el mío, enciendo la cámara. Si es de otro, la apago.
	$Camera2D.enabled = is_multiplayer_authority()

func _enter_tree():
	# El MultiplayerSpawner le puso como nombre el ID de red.
	# Aquí le decimos al nodo: "Tu dueño es el ID que llevas por nombre".
	set_multiplayer_authority(name.to_int())
	
func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direccion = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	velocity = direccion * velocidad
	
	move_and_slide()
