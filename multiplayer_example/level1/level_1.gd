extends Node2D

@onready var spawner = $MultiplayerSpawner
@onready var contenedor = $Contenedor
@onready var puntos_aparicion = $spawnpoints.get_children()
@onready var filtro_dimension = $CanvasLayer/Control/FiltroDimension
@onready var niebla = $CanvasLayer/Control/Niebla
@onready var niebla2 = $CanvasLayer/Control/Niebla2

var velocidad_niebla := 15.0


func _ready():
	# 1. Ambos (Servidor y Cliente) configuran la función
	spawner.set_spawn_function(crear_jugador_personalizado)
	niebla.modulate = Color(1, 1, 1, 0.25)
	aplicar_filtro_segun_rol()
	
	# 2. Solo el Servidor da la orden de crear
	if multiplayer.is_server():
		var indice_spawn = 0
		
		# Crear al servidor (Host - ID siempre es 1)
		spawner.spawn({"id": 1, "pos": puntos_aparicion[indice_spawn].global_position})
		indice_spawn += 1
		
		# Crear a los clientes que YA ESTÁN conectados desde el lobby
		for id in multiplayer.get_peers():
			# Usamos el módulo (%) por si hay más jugadores que puntos de aparición
			var punto_actual = puntos_aparicion[indice_spawn % puntos_aparicion.size()]
			
			spawner.spawn({"id": id, "pos": punto_actual.global_position})
			indice_spawn += 1

# Esta función la ejecutan TODOS automáticamente cuando el spawner lo ordena
func crear_jugador_personalizado(datos):
	var nuevo_jugador = preload("res://characters/players/player.tscn").instantiate()
	nuevo_jugador.name = str(datos.id)
	nuevo_jugador.global_position = datos.pos 
	return nuevo_jugador
func aplicar_filtro_segun_rol() -> void:
	var local_player = Game.get_current_player()

	if local_player == null:
		return

	if local_player.role == Statics.Role.ROLE_A or local_player.role == Statics.Role.ROLE_C:
		filtro_dimension.visible = false
		niebla.visible = false
	else:
		filtro_dimension.visible = true
		
		niebla.visible = true
func _process(delta: float) -> void:
	if not niebla.visible:
		return

	niebla.position.x += velocidad_niebla * delta

	if niebla.position.x > 100:
		niebla.position.x = 0
