class_name MenuPage
extends MarginContainer
## Basisklasse aller Hauptmenü-Seiten. Seiten bauen ihre UI in build() und aktualisieren sich in refresh().

var menu: Node = null          # MainMenu
var wide := false              # true = Seite braucht die volle Breite (z. B. Talentbaum)


func build() -> void:
	pass


func refresh() -> void:
	pass


func character() -> Dictionary:
	return SaveSystem.active_character()


func title(text: String, sub: String = "") -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_child(UI.label(text, 30, UI.GOLD, true))
	if sub != "":
		var l := UI.label(sub, 15, UI.DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	return v
