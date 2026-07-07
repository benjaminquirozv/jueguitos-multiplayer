extends Node2D

const PAUSE_SCENE := preload("res://ui/pause.tscn")
const PLAYER_SCENE := preload("res://characters/players/player.tscn")
const PORTAL_SCENE := preload("res://portals/portal_2.tscn")
const ZONE_SCENE := preload("res://tutorial/tutorial_zone.tscn")
const TILE_TEXTURE := preload("res://textures/Textures-16.png")

const MAZE := [
	"###############",
	"#.............#",
	"#.###.###.###.#",
	"#.#...#...#...#",
	"#.#.###.###.#.#",
	"#.....#.....#.#",
	"###.#.###.#.#.#",
	"#...#...#...#.#",
	"#.#######.###.#",
	"#.............#",
	"###############",
]

const FLOOR_TILE := Vector2i(3, 0)
const WALL_TILE := Vector2i(4, 1)
const MAZE_OFFSET := Vector2(64, 48)
const TILE_SIZE := 16
const SABOTAGE_DEMO_DURATION := 20.0

@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var base_layer: TileMapLayer = $base
@onready var barrera_layer: TileMapLayer = $barrera
@onready var spawn_marker: Marker2D = $spawnpoints/spawn1
@onready var hint_label: Label = %HintLabel
@onready var hint_panel: Panel = %HintPanel
@onready var dark_overlay: ColorRect = $CanvasLayer/Control/DarkOverlay
@onready var zones_root: Node2D = $Zones

var _shown_hints: Dictionary = {}


func _ready() -> void:
	add_child(PAUSE_SCENE.instantiate())
	_build_maze()
	spawn_marker.global_position = _tile_to_world(Vector2i(2, 1))
	_setup_portals()
	_setup_zones()
	_show_hint(
		"Bienvenido al tutorial.\n\nUsa las flechas o WASD para moverte por el laberinto.\nExplora cada zona para aprender las mecánicas."
	)

	spawner.set_spawn_function(_spawn_player)
	if multiplayer.is_server():
		spawner.spawn({"id": 1, "pos": spawn_marker.global_position})
		var spawn_index := 1
		for id in multiplayer.get_peers():
			var spawn_point := $spawnpoints.get_child(
				spawn_index % $spawnpoints.get_child_count()
			)
			spawner.spawn({"id": id, "pos": spawn_point.global_position})
			spawn_index += 1


func _build_maze() -> void:
	var tileset := _create_tileset()
	base_layer.tile_set = tileset
	barrera_layer.tile_set = tileset

	for y in MAZE.size():
		for x in MAZE[y].length():
			var cell := Vector2i(x, y)
			if MAZE[y][x] == "#":
				barrera_layer.set_cell(cell, 0, WALL_TILE)
			else:
				base_layer.set_cell(cell, 0, FLOOR_TILE)

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

	# El jugador mide 16px de alto (igual que un tile), así que si la
	# colisión de la pared ocupara el tile completo, quedaría encajado a
	# presión entre dos paredes sin margen y move_and_slide() lo dejaría
	# congelado. Se reduce 1px por lado para dejarle holgura para moverse.
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
	# Todos los elementos interactivos viven en los dos pasillos totalmente
	# abiertos del laberinto (fila 1 y fila 9) para evitar quedar embebidos
	# en una pared, lo que bloquearía el movimiento del jugador.
	var portal_normal := PORTAL_SCENE.instantiate()
	portal_normal.name = "PortalNormal"
	portal_normal.position = _tile_to_world(Vector2i(12, 1))
	portal_normal.scale = Vector2(0.14, 0.14)
	portal_normal.es_trampa = false
	$Portals.add_child(portal_normal)
	portal_normal.get_node("Destino").global_position = _tile_to_world(Vector2i(9, 9))

	var portal_trap := PORTAL_SCENE.instantiate()
	portal_trap.name = "PortalTrap"
	portal_trap.position = _tile_to_world(Vector2i(6, 1))
	portal_trap.scale = Vector2(0.14, 0.14)
	portal_trap.es_trampa = true
	$Portals.add_child(portal_trap)
	portal_trap.get_node("Destino").global_position = _tile_to_world(Vector2i(2, 9))


func _setup_zones() -> void:
	# ── Pasillo superior (fila 1) ────────────────────────────────────────────
	_add_zone(
		Vector2i(3, 1),
		"Movimiento\n\nFlechas o WASD mueven a tu personaje.\nSigue el pasillo hacia la derecha.",
		Statics.Sabotaje.NINGUNO
	)
	_add_zone(
		Vector2i(5, 1),
		"Portal trampa\n\nAhora tienes activo el sabotaje Portal Trampa.\nEntra al portal que sigue: como está marcado,\nte devolverá al inicio en vez de teletransportarte.",
		Statics.Sabotaje.PORTAL_TRAMPA,
		true
	)
	_add_zone(
		Vector2i(8, 1),
		"Slow Motion\n\nRalentiza al rival unos segundos.\nCamina aquí para sentir el efecto.",
		Statics.Sabotaje.VELOCIDAD_LENTA,
		true
	)
	_add_zone(
		Vector2i(9, 1),
		"Reverse Controls\n\nInvierte los controles del rival.\nPrueba cómo se siente moverte al revés.",
		Statics.Sabotaje.CONTROLES_INVERTIDOS,
		true
	)
	_add_zone(
		Vector2i(10, 1),
		"Dark Screen\n\nOscurece la pantalla del rival.\nEntra para experimentar la niebla.",
		Statics.Sabotaje.PANTALLA_OSCURA,
		true
	)
	_add_zone(
		Vector2i(11, 1),
		"Portal normal\n\nAl entrar a un portal sin sabotaje activo\nte teletransportas al punto Destino.\nEntra al siguiente portal para probarlo.",
		Statics.Sabotaje.NINGUNO
	)

	# ── Pasillo inferior (fila 9) ────────────────────────────────────────────
	_add_zone(
		Vector2i(2, 9),
		"¡Caíste en la trampa!\n\nEl Portal Trampa te devolvió cerca del inicio\nen vez de teletransportarte. Así funciona\nel sabotaje Portal Trampa en una partida real.",
		Statics.Sabotaje.NINGUNO
	)
	_add_zone(
		Vector2i(9, 9),
		"Usar sabotajes en partida\n\nEn multijugador, presiona ESPACIO cerca de un enemigo\npara aplicar el sabotaje que elegiste en el lobby.\nTienes cooldown entre usos.",
		Statics.Sabotaje.NINGUNO
	)
	_add_zone(
		Vector2i(12, 9),
		"¡Tutorial completado!\n\nYa conoces movimiento, portales y sabotajes.\nVuelve al menú y juega con amigos.",
		Statics.Sabotaje.NINGUNO,
		false,
		true
	)


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

	if zone.sabotaje_demo != Statics.Sabotaje.NINGUNO:
		body.recibir_sabotaje.rpc(zone.sabotaje_demo, zone.demo_duration)

	if zone.hint_text.begins_with("¡Tutorial completado"):
		await get_tree().create_timer(4.0).timeout
		Lobby.go_to_menu()


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
