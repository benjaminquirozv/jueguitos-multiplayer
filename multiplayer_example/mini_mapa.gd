extends Control

@export var map_origin := Vector2.ZERO
@export var map_size_world := Vector2(3000, 2000)

@onready var background: ColorRect = $Panel/Background
@onready var player_marker: ColorRect = $Panel/Player
@onready var teammate_marker: ColorRect = $Panel/Teammate

var player: Node2D = null
var teammate: Node2D = null

func _ready() -> void:
	player_marker.visible = false
	teammate_marker.visible = false

func _process(_delta: float) -> void:
	if is_instance_valid(player):
		player_marker.visible = true
		player_marker.position = world_to_minimap(player.global_position) - player_marker.size / 2.0

	if is_instance_valid(teammate):
		teammate_marker.visible = true
		teammate_marker.position = world_to_minimap(teammate.global_position) - teammate_marker.size / 2.0
	else:
		teammate_marker.visible = false

func world_to_minimap(world_pos: Vector2) -> Vector2:
	var relative_pos := world_pos - map_origin

	var x := relative_pos.x / map_size_world.x * background.size.x
	var y := relative_pos.y / map_size_world.y * background.size.y

	x = clamp(x, 0.0, background.size.x)
	y = clamp(y, 0.0, background.size.y)

	return Vector2(x, y)
