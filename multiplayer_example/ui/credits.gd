class_name Credits
extends Control

@onready var back_button: Button = %BackButton
@onready var credits_text: RichTextLabel = %CreditsText
@onready var page_button: Button = %PageButton

var _page := 0

const PAGE_IP := """[center][b]Propiedad intelectual[/b][/center]

[b]Arte y sprites[/b]
• Sprite del equipo negro y fondos de la escena final del cachipún — "Pixel Delivery Pack 3.0" por AIKRD (mariiya.itch.io) — CC0
• Sprite del personaje (animación idle) — "The Female Adventurer - Free" por Sscary (sscary.itch.io)
• Sprite de la estrella coleccionable — NYKNCK (nyknck.itch.io)
• Pantalla de victoria — "Pixel art 8-bit You Win", ilustración de Maderla (123RF)
• Pantalla de derrota — imagen de licencia libre
• Fondo espacial del menú y lobby — imagen obtenida de Pinterest
• Mano de piedra (cachipún) — crédito: Jolygon (licencia estándar)
• Manos de papel y tijera (cachipún) — generadas con IA a partir de la imagen de referencia de la mano de piedra
• Sprite del equipo blanco y logo del título — recursos gráficos del proyecto

[b]Música y sonido[/b]
• "Cinematic Epicness" — MaxKoMusic, vía chosic.com (CC BY-SA 3.0)
• Música de la sala de espera del lobby — chosic.com
• "Monk Chant Fantasy" — Pixabay (freesound_community)
• "Walking on Gravel" (pasos del jugador) — Pixabay (JJBinx)
• Efecto de recolección de estrella — Pixabay (freesound_community)"""

const PAGE_DEVS := """[center][b]Equipo de desarrollo — Twin Dimension[/b]

[b]Desarrollado por[/b]
Lady Esquivel
Benjamín Quiroz
Maira Rojas
Loonette Villegas

[b]Basado en[/b]
[i]multiplayer_example[/i] de Elías Zelada (github.com/elixs)

[i]¡Gracias por jugar![/i][/center]"""


func _ready() -> void:
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://ui/main_menu.tscn"))
	page_button.pressed.connect(_on_page_button_pressed)
	_update_page()


func _on_page_button_pressed() -> void:
	_page = 1 - _page
	_update_page()


func _update_page() -> void:
	if _page == 0:
		credits_text.text = PAGE_IP
		page_button.text = "Equipo de desarrollo →"
	else:
		credits_text.text = PAGE_DEVS
		page_button.text = "← Propiedad intelectual"
