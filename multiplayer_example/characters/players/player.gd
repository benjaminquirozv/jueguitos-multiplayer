extends CharacterBody2D

@export var velocidad = 200.0
@onready var anim = $AnimatedSprite2D
@onready var collision = $CollisionShape2D

func _ready():
	# Si este personaje es el mío, enciendo la cámara. Si es de otro, la apago.
	$Camera2D.enabled = is_multiplayer_authority()
	if not Game.player_updated.is_connected(_on_player_updated):
		Game.player_updated.connect(_on_player_updated)

	if not Game.players_updated.is_connected(_update_visual):
		Game.players_updated.connect(_update_visual)


	_update_visual()


func _enter_tree():
	# El MultiplayerSpawner le puso como nombre el ID de red.
	# Aquí le decimos al nodo: "Tu dueño es el ID que llevas por nombre".
	set_multiplayer_authority(name.to_int())
	
func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direccion = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direccion != Vector2.ZERO:
		anim.play("walk")
	else:
		anim.play("idle")

	velocity = direccion * velocidad
	
	move_and_slide()
	

func _on_player_updated(id: int) -> void:
	if id == name.to_int() or id == multiplayer.get_unique_id():
		_update_visual()

func _update_visual() -> void:
	var this_player = Game.get_player(name.to_int())
	var local_player = Game.get_current_player()

	if this_player == null or local_player == null:
		return

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
func set_ghost_visual()-> void:
	modulate.a = 0.35
func set_normal_visual()-> void:
	modulate.a = 1.0
