class_name PageWorld
extends MenuPage
## Weltkarte: alle sechs Gebiete, Freischaltbedingungen, Fortschritt. Auswahl setzt das Zielgebiet.


func _init() -> void:
	wide = true


func unlock_text(a: Dictionary) -> String:
	var u: Dictionary = a["unlock"]
	match u["type"]:
		"none":
			return "Von Anfang an offen."
		"boss":
			return "Besiege den Boss: " + _boss_name(u["id"])
		"area_clear":
			return "Schließe ab: " + GameData.area_by_id(u["id"]).get("name", u["id"])
	return ""


func _boss_name(id: String) -> String:
	for a in GameData.areas:
		if a["boss"] == id:
			return BOSS_NAMES.get(id, id)
	return id


const BOSS_NAMES := {"rootwarden": "Wurzelwächter", "clockwork_guardian": "Mechanischer Wächter", "lava_titan": "Lavatitan",
		"frost_wyrm": "Frostwyrm", "mirror_witch": "Spiegelhexe", "sky_sovereign": "Himmelsherrscher"}
const ACCENTS := {"emerald_forest": "#4fb872", "sunken_ruins": "#4aa3c8", "ash_lands": "#e8643a", "frost_cliffs": "#9fd8ff",
		"shadow_wood": "#8a5ad6", "sky_fortress": "#f0c65a"}


func build() -> void:
	var c := character()
	var v := VBoxContainer.new()
	add_child(v)
	v.add_child(title("Weltkarte", "Neue Gebiete schaltest du durch Bossfortschritt frei. Jedes Gebiet hat eigene Gegner, Gefahren und einen eigenen Hauptboss."))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(grid)
	for a in GameData.areas:
		grid.add_child(_card(a, c))


func _card(a: Dictionary, c: Dictionary) -> Control:
	var unlocked: bool = a["id"] in c["unlocked_areas"]
	var cleared: bool = a["id"] in c["cleared_areas"]
	var accent := Color(ACCENTS.get(a["id"], "#ffffff"))
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(300, 210)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", UI.box(Color("#12212f") if unlocked else Color("#0d1620"), 12, accent if unlocked else Color("#27384a"), 3 if a["id"] == menu.selected_area else 2))
	var v := VBoxContainer.new()
	p.add_child(v)
	v.add_child(UI.label(a["name"], 20, accent if unlocked else UI.DIM, true))
	var d := UI.label(a["desc"], 14, UI.TEXT if unlocked else UI.DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(d)
	v.add_child(UI.label("Boss: %s · Schwierigkeit %d" % [BOSS_NAMES.get(a["boss"], a["boss"]), a["difficulty"]], 14, UI.DIM))
	var status := ""
	if cleared:
		status = "✓ Abgeschlossen"
	elif unlocked:
		status = "Freigeschaltet"
	else:
		status = "Gesperrt – " + unlock_text(a)
	var sl := UI.label(status, 14, UI.GOLD if cleared else (UI.TEAL if unlocked else UI.RED))
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sl)
	if not a["playable"]:
		v.add_child(UI.label("Spielbar: in Entwicklung", 13, UI.DIM))
	var b := UI.button("Zielgebiet wählen" if unlocked else "Gesperrt", Callable(), Vector2(0, 36))
	b.disabled = not unlocked
	var aid: String = a["id"]
	b.pressed.connect(func():
		menu.selected_area = aid
		menu.go("play"))
	v.add_child(b)
	return p
