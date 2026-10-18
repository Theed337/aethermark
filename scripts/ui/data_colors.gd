class_name DataColors
extends RefCounted
## Kleine Farbhelfer, damit UI-Code nicht überall GameData ansprechen muss.


static func rarity(r: String) -> Color:
	return GameData.rarity_color(r)
