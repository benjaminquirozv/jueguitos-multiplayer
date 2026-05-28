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

# ── SABOTAJES ──────────────────────────────────────────────────────────────────
enum Sabotaje {
	NINGUNO,
	VELOCIDAD_LENTA,      # Se mueve al 40% de velocidad
	PORTAL_TRAMPA,        # Un portal marcado lo manda al inicio
	CONTROLES_INVERTIDOS, # Las flechas van al revés
	PANTALLA_OSCURA       # La pantalla se llena de niebla por 10 segundos
}

static func get_sabotaje_name(s: Sabotaje) -> String:
	match s:
		Sabotaje.NINGUNO:              return "Sin sabotaje"
		Sabotaje.VELOCIDAD_LENTA:      return "Velocidad lenta"
		Sabotaje.PORTAL_TRAMPA:        return "Portal trampa"
		Sabotaje.CONTROLES_INVERTIDOS: return "Controles invertidos"
		Sabotaje.PANTALLA_OSCURA:      return "Pantalla oscura"
	return "Desconocido"
# ──────────────────────────────────────────────────────────────────────────────


static func get_team_name(team: Team) -> String:
	match team:
		Team.NONE:       return "None"
		Team.TEAM_BLACK: return "Black"
		Team.TEAM_WHITE: return "White"
	return "Unknown"


static func get_team_from_role(role: Role) -> Team:
	match role:
		Role.ROLE_A, Role.ROLE_B: return Team.TEAM_BLACK
		Role.ROLE_C, Role.ROLE_D: return Team.TEAM_WHITE
		_:                        return Team.NONE


static func get_role_name(role: Role) -> String:
	match role:
		Role.NONE:   return "None"
		Role.ROLE_A: return "Role A"
		Role.ROLE_B: return "Role B"
		Role.ROLE_C: return "Role C"
		Role.ROLE_D: return "Role D"
	return "Unknown"

static func can_see_role(viewer_role: Role, target_role: Role) -> bool:
	match viewer_role:
		Role.ROLE_A: return target_role != Role.ROLE_D
		Role.ROLE_B: return target_role != Role.ROLE_C
		Role.ROLE_C: return target_role != Role.ROLE_B
		Role.ROLE_D: return target_role != Role.ROLE_A
		_:           return true

static func are_teammates(role_1: Role, role_2: Role) -> bool:
	var team_1 = Statics.get_team_from_role(role_1)
	var team_2 = Statics.get_team_from_role(role_2)
	return team_1 != Team.NONE and team_1 == team_2


class PlayerData:
	var id: int
	var name: String
	var index: int = -1
	var role: Role
	var team: Team
	var vote: bool = false

	# Sabotaje que el jugador POSEE (elegido en el lobby, no cambia en el juego)
	var sabotaje: Sabotaje = Sabotaje.NINGUNO

	# Sabotaje que el jugador está SUFRIENDO ahora mismo (aplicado por otro)
	var sabotaje_activo: Sabotaje = Sabotaje.NINGUNO

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
			"team": team,
			"vote": vote,
			"sabotaje": sabotaje,
			# sabotaje_activo NO se sincroniza por dict, se maneja por RPC directo
		}

	static func from_dict(data: Dictionary) -> PlayerData:
		var player = PlayerData.new(data.id, data.name, data.index, data.role)
		player.vote = data.vote
		player.team = data.team
		player.sabotaje = data.get("sabotaje", Sabotaje.NINGUNO)
		return player

	func update(player_data: PlayerData) -> void:
		if id != player_data.id:
			return
		name = player_data.name
		index = player_data.index
		role = player_data.role
		team = player_data.team
		vote = player_data.vote
		sabotaje = player_data.sabotaje
		# sabotaje_activo no se toca aquí, lo maneja el RPC en player.gd
