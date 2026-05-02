class_name Statics
extends Node


const MAX_CLIENTS = 4
const PORT = 5409 # Number between 1024 and 65535.


enum Role {
	NONE,
	ROLE_A,
	ROLE_B,
	ROLE_C,
	ROLE_D
}
enum Team {
	NONE,
	TEAM_BLACK,
	TEAM_WHITE
}



static func get_team_name(team: Team) -> String:
	match team:
		Team.NONE:
			return "None"
		Team.TEAM_BLACK:
			return "Black"
		Team.TEAM_WHITE:
			return "White"
	return "Unknown"
	
	
static func get_team_from_role(role: Role) -> Team:
	match role:
		Role.ROLE_A, Role.ROLE_B:
			return Team.TEAM_BLACK
		Role.ROLE_C, Role.ROLE_D:
			return Team.TEAM_WHITE
		_:
			return Team.NONE
			

static func get_role_name(role: Role) -> String:
	match role:
		Role.NONE:
			return "None"
		Role.ROLE_A:
			return "Role A"
		Role.ROLE_B:
			return "Role B"
		Role.ROLE_C:
			return "Role C"
		Role.ROLE_D:
			return "Role D"
	return "Unknown"


class PlayerData:
	var id: int
	var name: String
	# Position relative to other players
	var index: int = -1
	var role: Role
	var team: Team

	var vote: bool = false
	
	func _init(new_id: int, new_name: String, new_index: int = -1, new_role: Role = Role.NONE) -> void:
		id = new_id
		name = new_name
		index = new_index
		role = new_role
		team = Statics.get_team_from_role(new_role)

		
	
	func _to_string() -> String:
		return "Player: {id: %d, name: %s, index: %d, role: %d}" % [id, name, index, Statics.get_role_name(role)]
	
	func to_dict() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"index": index,
			"role": role,
			"team":team,
			"vote": vote
		}
	
	static func from_dict(data: Dictionary) -> PlayerData:
		var player = PlayerData.new(data.id, data.name, data.index, data.role)
		player.vote = data.vote
		player.team = data.team 

		return player
	
	func update(player_data: PlayerData) -> void:
		if id != player_data.id:
			return
		name = player_data.name
		index = player_data.index
		role = player_data.role
		team = player_data.team

		vote = player_data.vote
