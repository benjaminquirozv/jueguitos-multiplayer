extends Node

# Script helper para manejar transiciones de juego
# Singleton - agregar a AutoLoad en Project Settings como "GameManager"

func go_to_final_cachipun() -> void:
	# Función para ir a la escena final del cachipún
	get_tree().change_scene_to_file("res://ui/final_cachipun.tscn")

func declare_winner_team() -> void:
	# Función que se puede llamar cuando un equipo gana
	# Por ahora va directo al cachipún final
	go_to_final_cachipun()
