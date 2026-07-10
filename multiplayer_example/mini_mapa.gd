extends Control

@onready var background: ColorRect = $Panel/Background
@onready var player_marker: ColorRect = $Panel/Player
@onready var teammate_marker: ColorRect = $Panel/Teammate

var player: Node2D = null
var teammate: Node2D = null

var map_origin := Vector2.ZERO
var map_size_world := Vector2(1, 1)

var marcador_portal_final: ColorRect = null

const COLOR_PORTAL := Color(1, 1, 0)
const COLOR_PORTAL_FINAL := Color(0, 1, 0)
const MARGEN := 200.0


func _ready() -> void:
	player_marker.visible = false
	teammate_marker.visible = false
	_calcular_bounds()
	_crear_marcadores_portales()

	Game.stars_updated.connect(_on_stars_updated)
	_actualizar_portal_final_minimapa()


func _process(_delta: float) -> void:
	if is_instance_valid(player):
		player_marker.visible = true
		player_marker.position = world_to_minimap(player.global_position) - player_marker.size / 2.0
	else:
		player_marker.visible = false

	if is_instance_valid(teammate):
		teammate_marker.visible = true
		teammate_marker.position = world_to_minimap(teammate.global_position) - teammate_marker.size / 2.0
	else:
		teammate_marker.visible = false

func _calcular_bounds() -> void:
	var puntos: Array[Vector2] = []

	var portals = get_tree().current_scene.get_node_or_null("portals")
	if portals:
		for portal in portals.get_children():
			if portal is Node2D:
				puntos.append(portal.global_position)

	var spawnpoints = get_tree().current_scene.get_node_or_null("spawnpoints")
	if spawnpoints:
		for s in spawnpoints.get_children():
			if s is Node2D:
				puntos.append(s.global_position)

	if puntos.is_empty():
		map_origin = Vector2.ZERO
		map_size_world = Vector2(2000, 2000)
		return

	var min_pos := puntos[0]
	var max_pos := puntos[0]
	for p in puntos:
		min_pos.x = min(min_pos.x, p.x)
		min_pos.y = min(min_pos.y, p.y)
		max_pos.x = max(max_pos.x, p.x)
		max_pos.y = max(max_pos.y, p.y)

	min_pos -= Vector2(MARGEN, MARGEN)
	max_pos += Vector2(MARGEN, MARGEN)

	map_origin = min_pos
	map_size_world = max_pos - min_pos


func _crear_marcadores_portales() -> void:
	var portals = get_tree().current_scene.get_node_or_null("portals")
	if portals == null:
		return

	for portal in portals.get_children():
		if not (portal is Node2D):
			continue

		var marcador := ColorRect.new()
		marcador.size = Vector2(6, 6)
		marcador.position = world_to_minimap(portal.global_position) - marcador.size / 2.0

		if portal.name == "portal_final_final":
			marcador.color = COLOR_PORTAL_FINAL
			marcador.visible = false
			marcador_portal_final = marcador
			print("✅ Encontré Portal_final y creé su marcador")
		else:
			marcador.color = COLOR_PORTAL

		$Panel.add_child(marcador)

	print("¿marcador_portal_final quedó asignado? ", marcador_portal_final != null)


func _actualizar_portal_final_minimapa() -> void:
	if marcador_portal_final == null:
		print("⚠ marcador_portal_final es null, no puedo actualizarlo")
		return
	var mi_data = Game.get_current_player()
	if mi_data == null:
		return
	var habilitado = Game.team_has_all_stars(mi_data.team)
	print("Actualizando portal final del minimapa. Habilitado: ", habilitado)
	marcador_portal_final.visible = habilitado

func world_to_minimap(world_pos: Vector2) -> Vector2:
	var relative_pos := world_pos - map_origin
	var x := relative_pos.x / map_size_world.x * background.size.x
	var y := relative_pos.y / map_size_world.y * background.size.y
	x = clamp(x, 0.0, background.size.x)
	y = clamp(y, 0.0, background.size.y)
	return Vector2(x, y)
	
func _on_stars_updated(team) -> void:
	var mi_data = Game.get_current_player()
	if mi_data == null:
		return
	if team == mi_data.team:
		_actualizar_portal_final_minimapa()
