extends Node2D

const PAUSE_SCENE := preload("res://ui/pause.tscn")
const PLAYER_SCENE := preload("res://characters/players/player.tscn")
const PORTAL_SCENE := preload("res://portals/portal_2.tscn")
const ZONE_SCENE := preload("res://tutorial/tutorial_zone.tscn")
const ENEMY_SCENE := preload("res://tutorial/tutorial_enemy.tscn")
const STAR_SCENE := preload("res://scenes/Star.tscn")
const TILE_TEXTURE := preload("res://textures/Textures-16.png")

# ID ficticio (no puede colisionar con IDs reales de red, que siempre son > 0
# y normalmente pequeños). El enemigo de práctica permite probar sabotajes.
const ENEMY_ID := 9999

# Laberinto principal (izq) + zona del portal (der), mismo mapa expandido.
# Columnas 0-14 = tutorial principal; 15-16 = corredor; 17-29 = zona portal.
const MAZE := [
	"###############  #############",
	"#.............#  #...........#",
	"#.###.###.###.#  #.#########.#",
	"#.#...#...#...#  #.#.......#.#",
	"#.#.###.###.#.#  #.#.#####.#.#",
	"#.....#.....#.#  #.#...P...#.#",
	"###.#.###.#.#.#  #.#..######.#",
	"#...#...#...#.#  #...........#",
	"#.#######.###.#  #############",
	"#.............#               ",
	"###############               ",
]

const FLOOR_TILE := Vector2i(3, 0)
const WALL_TILE := Vector2i(4, 1)
const MAZE_OFFSET := Vector2(64, 48)
const TILE_SIZE := 16
const SABOTAGE_DEMO_DURATION := 20.0
const START_TILE := Vector2i(2, 1)
# Destino del portal normal: centro de la zona expandida (marca P en el mapa).
const PORTAL_ZONE_TILE := Vector2i(23, 5)
# Portal de retorno dentro de la zona expandida.
const RETURN_PORTAL_TILE := Vector2i(27, 7)
# Estrella final: extremo derecho del pasillo inferior del laberinto principal.
const STAR_TILE := Vector2i(13, 9)

@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var base_layer: TileMapLayer = $base
@onready var barrera_layer: TileMapLayer = $barrera
@onready var spawn_marker: Marker2D = $spawnpoints/spawn1
@onready var hint_label: Label = %HintLabel
@onready var hint_panel: Panel = %HintPanel
@onready var dark_overlay: ColorRect = $CanvasLayer/Control/DarkOverlay
@onready var zones_root: Node2D = $Zones
@onready var contenedor: Node2D = $Contenedor
@onready var stars_root: Node2D = $stars

var _shown_hints: Dictionary = {}
var _enemy: Node = null
var _tutorial_finished := false


func _ready() -> void:
	add_child(PAUSE_SCENE.instantiate())
	Game.reset_stars()
	_build_maze()
	spawn_marker.global_position = _tile_to_world(START_TILE)
	_setup_portals()
	_setup_zones()
	_setup_enemy()
	_setup_star()
	_show_hint(
		"Bienvenido al tutorial.\n\nUsa las flechas o WASD para moverte por el laberinto.\nExplora cada zona para aprender las mecánicas."
	)

	spawner.set_spawn_function(_spawn_player)
	# En tutorial siempre hay un peer local (server o OfflineMultiplayerPeer).
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		spawner.spawn({"id": multiplayer.get_unique_id(), "pos": spawn_marker.global_position})
		var spawn_index := 1
		for id in multiplayer.get_peers():
			var spawn_point := $spawnpoints.get_child(
				spawn_index % $spawnpoints.get_child_count()
			)
			spawner.spawn({"id": id, "pos": spawn_point.global_position})
			spawn_index += 1
	else:
		# Sin red: spawnear el jugador local a mano.
		var local_id := 1
		var p := _spawn_player({"id": local_id, "pos": spawn_marker.global_position})
		contenedor.add_child(p)


# Llamado por el jugador local al pulsar Espacio en el tutorial.
func aplicar_slow_al_enemigo(duracion: float) -> bool:
	if _enemy == null or not is_instance_valid(_enemy):
		_enemy = get_tree().get_first_node_in_group("Enemy")
	if _enemy == null or not _enemy.has_method("aplicar_slow"):
		push_warning("Tutorial: no hay enemigo para aplicar Slow Motion")
		return false
	_enemy.aplicar_slow(duracion)
	return true


func get_tutorial_start_position() -> Vector2:
	return _tile_to_world(START_TILE)


func mostrar_aviso_portal_trampa() -> void:
	# Diferido para que el mensaje no se pierda al teletransportar.
	call_deferred(
		"_show_hint",
		"Portal trampa\n\n¡Caíste en un portal trampa!\nTe llevó al inicio del camino.\nAsí funcionan los portales falsos\nen una partida real."
	)


func _build_maze() -> void:
	var tileset := _create_tileset()
	base_layer.tile_set = tileset
	barrera_layer.tile_set = tileset

	for y in MAZE.size():
		for x in MAZE[y].length():
			var cell := Vector2i(x, y)
			var ch: String = MAZE[y][x]
			if ch == "#":
				barrera_layer.set_cell(cell, 0, WALL_TILE)
			elif ch == "." or ch == "P":
				base_layer.set_cell(cell, 0, FLOOR_TILE)
			# Espacio en blanco = vacío (separación visual entre zonas)

	base_layer.position = MAZE_OFFSET
	barrera_layer.position = MAZE_OFFSET


func _create_tileset() -> TileSet:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0, 1)

	var atlas := TileSetAtlasSource.new()
	atlas.texture = TILE_TEXTURE
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	atlas.create_tile(FLOOR_TILE)
	atlas.create_tile(WALL_TILE)
	tileset.add_source(atlas, 0)

	# Holgura en la colisión de paredes para que el jugador no quede trabado.
	var wall_data := atlas.get_tile_data(WALL_TILE, 0)
	wall_data.add_collision_polygon(0)
	wall_data.set_collision_polygon_points(
		0, 0, PackedVector2Array([
			Vector2(-7, -7), Vector2(7, -7), Vector2(7, 7), Vector2(-7, 7)
		])
	)

	return tileset


func _tile_to_world(tile: Vector2i) -> Vector2:
	return MAZE_OFFSET + Vector2(tile) * TILE_SIZE + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)


func _setup_portals() -> void:
	# Portal trampa: te devuelve al inicio del tutorial.
	var portal_trap := PORTAL_SCENE.instantiate()
	portal_trap.name = "PortalTrap"
	portal_trap.position = _tile_to_world(Vector2i(6, 1))
	portal_trap.scale = Vector2(0.14, 0.14)
	portal_trap.es_trampa = true
	$Portals.add_child(portal_trap)
	_add_portal_label(portal_trap, "¡PORTAL TRAMPA!\nTe lleva al inicio")

	# Portal normal: teletransporta a la zona expandida del mismo mapa.
	var portal_normal := PORTAL_SCENE.instantiate()
	portal_normal.name = "PortalNormal"
	portal_normal.position = _tile_to_world(Vector2i(12, 1))
	portal_normal.scale = Vector2(0.14, 0.14)
	portal_normal.es_trampa = false
	$Portals.add_child(portal_normal)
	portal_normal.get_node("Destino").global_position = _tile_to_world(PORTAL_ZONE_TILE)

	# Un solo portal en la zona expandida: vuelve al inicio del tutorial.
	var portal_return := PORTAL_SCENE.instantiate()
	portal_return.name = "PortalReturn"
	portal_return.position = _tile_to_world(RETURN_PORTAL_TILE)
	portal_return.scale = Vector2(0.14, 0.14)
	portal_return.es_trampa = false
	$Portals.add_child(portal_return)
	portal_return.get_node("Destino").global_position = _tile_to_world(START_TILE)


func _add_portal_label(portal: Node2D, text: String) -> void:
	# Label en coordenadas de mundo (no hereda la escala 0.14 del portal).
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.2, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 6)
	label.z_index = 50
	label.position = portal.position + Vector2(-70, -40)
	label.size = Vector2(140, 40)
	$Portals.add_child(label)


func _setup_zones() -> void:
	_add_zone(
		Vector2i(3, 1),
		"Movimiento\n\nFlechas o WASD mueven a tu personaje.\nSigue el pasillo hacia la derecha.",
		Statics.Sabotaje.NINGUNO
	)
	# Aviso justo antes del portal trampa (celda 6), sin que Freeze lo tape.
	_add_zone(
		Vector2i(5, 1),
		"Portal trampa\n\n¡Cuidado! El siguiente portal es una trampa.\nSi entras, te lleva al inicio del camino\nen vez de avanzar.",
		Statics.Sabotaje.NINGUNO
	)
	_add_zone(
		Vector2i(11, 1),
		"Portal normal\n\nEste portal te lleva a otra zona del mismo mapa\n(la sala de la derecha, con un solo portal).\nEntra para probarlo.",
		Statics.Sabotaje.NINGUNO
	)
	_add_zone(
		Vector2i(7, 9),
		"Slow Motion\n\nTienes equipado Slow Motion.\nPresiona ESPACIO cerca del rival\npara ralentizarlo mucho.",
		Statics.Sabotaje.VELOCIDAD_LENTA
	)
	_add_zone(
		Vector2i(9, 9),
		"Arena de práctica\n\nPresiona ESPACIO cerca del rival\npara aplicarle Slow Motion.\nDebería caminar muchísimo más lento.",
		Statics.Sabotaje.NINGUNO
	)
	_add_zone(
		STAR_TILE,
		"¡Tutorial terminado!\n\nYa conoces movimiento, portales y sabotajes.\nVuelves al menú en 3 segundos.",
		Statics.Sabotaje.NINGUNO,
		false,
		true
	)
	_add_zone(
		PORTAL_ZONE_TILE,
		"Zona del portal\n\nLlegaste por el portal normal.\nUsa el portal de esta sala para volver\nal inicio del tutorial.",
		Statics.Sabotaje.NINGUNO
	)


func _setup_star() -> void:
	# Misma escena que level1; Game.collect_star busca el contenedor "stars".
	var star := STAR_SCENE.instantiate()
	star.name = "Star"
	star.position = _tile_to_world(STAR_TILE)
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	star.get_node("CollisionShape2D").shape = circle
	stars_root.add_child(star)


func _finish_tutorial() -> void:
	if _tutorial_finished:
		return
	_tutorial_finished = true
	await get_tree().create_timer(3.0).timeout
	Lobby.go_to_menu()


func _setup_enemy() -> void:
	# Rival de otro equipo (por si se usa la lógica de partida normal).
	var enemy_data := Statics.PlayerData.new(ENEMY_ID, "Enemigo", 1, Statics.Role.ROLE_C)
	enemy_data.team = Statics.Team.TEAM_WHITE
	Game.add_player(enemy_data)

	var enemy := ENEMY_SCENE.instantiate()
	enemy.name = str(ENEMY_ID)
	enemy.global_position = _tile_to_world(Vector2i(11, 9))
	contenedor.add_child(enemy)
	_enemy = enemy


func _add_zone(
	tile: Vector2i,
	hint: String,
	sabotaje: Statics.Sabotaje,
	apply_demo := false,
	is_finish := false
) -> void:
	var zone: TutorialZone = ZONE_SCENE.instantiate()
	zone.position = _tile_to_world(tile)
	zone.hint_text = hint
	zone.sabotaje_demo = sabotaje if apply_demo else Statics.Sabotaje.NINGUNO
	zone.demo_duration = SABOTAGE_DEMO_DURATION
	zone.one_shot = is_finish or not apply_demo
	zone.zone_triggered.connect(_on_zone_triggered)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE_SIZE * 1.1, TILE_SIZE * 1.1)
	shape.shape = rect
	zone.add_child(shape)

	zones_root.add_child(zone)


func _on_zone_triggered(zone: TutorialZone, body: Node2D) -> void:
	if zone.hint_text in _shown_hints and zone.one_shot:
		return
	_shown_hints[zone.hint_text] = true
	_show_hint(zone.hint_text)

	# En la zona de Slow Motion solo se equipa el sabotaje (no se aplica al jugador).
	if zone.hint_text.begins_with("Slow Motion"):
		Game.set_current_player_sabotaje(Statics.Sabotaje.VELOCIDAD_LENTA)

	if zone.sabotaje_demo != Statics.Sabotaje.NINGUNO:
		body.recibir_sabotaje.rpc(zone.sabotaje_demo, zone.demo_duration)

	if zone.hint_text.begins_with("¡Tutorial terminado"):
		_finish_tutorial()


func _show_hint(text: String) -> void:
	hint_label.text = text
	hint_panel.show()


func _spawn_player(datos: Dictionary) -> Node:
	var player := PLAYER_SCENE.instantiate()
	player.name = str(datos.id)
	player.global_position = datos.pos
	player.set_multiplayer_authority(int(datos.id))
	return player


func activar_pantalla_oscura() -> void:
	dark_overlay.visible = true


func desactivar_pantalla_oscura() -> void:
	dark_overlay.visible = false
