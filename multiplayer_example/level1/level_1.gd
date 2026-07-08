extends Node2D

const PAUSE_SCENE := preload("res://ui/pause.tscn")

@onready var spawner           = $MultiplayerSpawner
@onready var contenedor        = $Contenedor
@onready var puntos_aparicion  = $spawnpoints.get_children()
@onready var filtro_dimension  = $CanvasLayer/Control/FiltroDimension
@onready var niebla            = $CanvasLayer/Control/Niebla
@onready var niebla2           = $CanvasLayer/Control/Niebla2
@onready var label_estrellas = $CanvasLayer/Control/LabelEstrellas
@onready var portal_final = $portals/Portal_final

var velocidad_niebla := 15.0


func _ready():
	add_child(PAUSE_SCENE.instantiate())
	spawner.set_spawn_function(crear_jugador_personalizado)
	niebla.modulate = Color(1, 1, 1, 0.25)
	aplicar_filtro_segun_rol()
	Game.stars_updated.connect(_on_stars_updated)
	_actualizar_label_estrellas()
	portal_final.visible = false
	portal_final.monitoring = false
	if multiplayer.is_server():
		Game.reset_stars()
		var indice_spawn = 0
		spawner.spawn({"id": 1, "pos": puntos_aparicion[indice_spawn].global_position})
		indice_spawn += 1
		for id in multiplayer.get_peers():
			var punto_actual = puntos_aparicion[indice_spawn % puntos_aparicion.size()]
			spawner.spawn({"id": id, "pos": punto_actual.global_position})
			indice_spawn += 1



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


# ── SABOTAJE: Pantalla oscura ─────────────────────────────────────────────────
# player.gd llama a estos métodos cuando recibe / termina el efecto PANTALLA_OSCURA.

func activar_pantalla_oscura() -> void:
	# Forzar niebla muy densa encima de lo que ya tenga el rol
	niebla.visible = true
	niebla.modulate = Color(1, 1, 1, 0.97)   # casi opaca
	if niebla2:
		niebla2.visible = true
		niebla2.modulate = Color(0, 0, 0, 0.85)  # capa negra encima

func desactivar_pantalla_oscura() -> void:
	# Restaurar la niebla según el rol original
	niebla.modulate = Color(1, 1, 1, 0.25)
	if niebla2:
		niebla2.visible = false
	aplicar_filtro_segun_rol()
# ─────────────────────────────────────────────────────────────────────────────


func _process(delta: float) -> void:
	if not niebla.visible:
		return
	niebla.position.x += velocidad_niebla * delta
	if niebla.position.x > 100:
		niebla.position.x = 0
		
#-------------------L+ogica de estrellas e inventario por equipo 
func _on_stars_updated(team) -> void:
	var mi_team = Game.get_current_player().team
	if team == mi_team:
		_actualizar_label_estrellas()
		_actualizar_portal_final()


func _actualizar_label_estrellas() -> void:
	var mi_data = Game.get_current_player()
	if mi_data == null:
		return
	label_estrellas.text = "Estrellas: %d" % Game.get_team_stars(mi_data.team)
	
func _actualizar_portal_final() -> void:
	var mi_data = Game.get_current_player()
	if mi_data == null:
		return

	var habilitado = Game.team_has_all_stars(mi_data.team)
	portal_final.visible = habilitado
	portal_final.monitoring = habilitado
