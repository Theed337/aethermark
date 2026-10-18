class_name Hud
extends Control
## Heads-up-Display: Leben, Mana, Erfahrung, Fähigkeiten mit Abklingzeit, Bossleiste, Ereignis-Banner.
## Die Gruppenliste (party_box) ist für bis zu 5 Spieler ausgelegt; im Solo-Modus zeigt sie nur den eigenen Charakter.

var arena: Node
var player: Player
var hp_bar: ProgressBar
var mana_bar: ProgressBar
var xp_bar: ProgressBar
var hp_label: Label
var level_label: Label
var time_label: Label
var info_label: Label
var boss_box: Control
var boss_bar: ProgressBar
var boss_name: Label
var banner: Label
var hint: Label
var slot_nodes: Array = []
var passives_box: HBoxContainer
var party_box: VBoxContainer
var _banner_t := 0.0
var _hurt: ColorRect
var _hint_t := 0.0
var _objective: Label


func bind(a: Node, p: Player) -> void:
	arena = a
	player = p
	theme = UI.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hurt = ColorRect.new()
	_hurt.color = Color(0.8, 0.05, 0.05, 0.0)
	_hurt.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hurt)
	# Oben links: Zeit & Info
	var tl := VBoxContainer.new()
	tl.position = Vector2(20, 14)
	add_child(tl)
	time_label = UI.label("00:00", 26, UI.GOLD, true)
	tl.add_child(time_label)
	info_label = UI.label("", 16, UI.DIM)
	tl.add_child(info_label)
	_objective = UI.label("", 16, UI.TEAL)
	tl.add_child(_objective)
	# Gruppe (links Mitte)
	party_box = VBoxContainer.new()
	party_box.position = Vector2(20, 120)
	add_child(party_box)
	# Unten links: Leben / Mana / Level
	var bl := VBoxContainer.new()
	bl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bl.position = Vector2(24, -130)
	bl.size = Vector2(380, 110)
	add_child(bl)
	var row := HBoxContainer.new()
	bl.add_child(row)
	level_label = UI.label("Stufe 1", 22, UI.GOLD, true)
	row.add_child(level_label)
	hp_label = UI.label("", 16, UI.TEXT)
	row.add_child(hp_label)
	hp_bar = UI.bar(Color("#e0504a"), Vector2(380, 22))
	bl.add_child(hp_bar)
	mana_bar = UI.bar(Color("#4a8fe0"), Vector2(380, 14))
	bl.add_child(mana_bar)
	xp_bar = UI.bar(UI.GOLD, Vector2(380, 8))
	bl.add_child(xp_bar)
	# Unten Mitte: Fähigkeiten
	var bc := HBoxContainer.new()
	bc.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bc.position = Vector2(-150, -112)
	bc.add_theme_constant_override("separation", 10)
	add_child(bc)
	for i in 4:
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(68, 68)
		slot.add_theme_stylebox_override("panel", UI.box(Color(0.06, 0.1, 0.15, 0.85), 10, Color("#2c4a68"), 2, 0))
		var key := UI.label(str(i + 1), 14, UI.DIM)
		key.position = Vector2(6, 2)
		slot.add_child(key)
		var name_l := UI.label("", 13, UI.TEXT)
		name_l.position = Vector2(4, 24)
		name_l.size = Vector2(60, 30)
		name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_child(name_l)
		var cd := ColorRect.new()
		cd.color = Color(0, 0, 0, 0.62)
		cd.size = Vector2(68, 0)
		cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(cd)
		var cd_l := UI.label("", 20, Color.WHITE, true)
		cd_l.position = Vector2(20, 20)
		slot.add_child(cd_l)
		bc.add_child(slot)
		slot_nodes.append({"panel": slot, "name": name_l, "cd": cd, "cd_l": cd_l})
	# Passiv-Leiste
	passives_box = HBoxContainer.new()
	passives_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	passives_box.position = Vector2(-420, -60)
	passives_box.size = Vector2(400, 40)
	passives_box.alignment = BoxContainer.ALIGNMENT_END
	add_child(passives_box)
	# Bossleiste
	boss_box = VBoxContainer.new()
	boss_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_box.position = Vector2(-320, 14)
	boss_box.custom_minimum_size = Vector2(640, 40)
	boss_box.visible = false
	add_child(boss_box)
	boss_name = UI.label("", 22, UI.GOLD, true)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(boss_name)
	boss_bar = UI.bar(Color("#b4ff5a"), Vector2(640, 20))
	boss_box.add_child(boss_bar)
	# Banner
	banner = UI.label("", 34, UI.GOLD, true)
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.position = Vector2(-400, 130)
	banner.size = Vector2(800, 50)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_constant_override("outline_size", 8)
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	add_child(banner)
	hint = UI.label("", 20, Color.WHITE, true)
	hint.set_anchors_preset(Control.PRESET_CENTER)
	hint.position = Vector2(-300, 90)
	hint.size = Vector2(600, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)


func show_banner(text: String, color: Color = UI.GOLD, duration: float = 2.8) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.modulate.a = 1.0
	_banner_t = duration


func show_hint(text: String, duration: float = 1.2) -> void:
	hint.text = text
	_hint_t = duration


func flash_hurt() -> void:
	_hurt.color.a = 0.3


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	hp_bar.max_value = player.stats["max_hp"]
	hp_bar.value = player.hp
	mana_bar.max_value = player.stats["mana_max"]
	mana_bar.value = player.mana
	xp_bar.max_value = GameData.xp_needed(player.level)
	xp_bar.value = player.xp
	level_label.text = "Stufe %d" % player.level
	var sh := ("  (+%d Schild)" % int(player.shield)) if player.shield > 0.5 else ""
	hp_label.text = "  %d / %d%s" % [int(ceil(player.hp)), int(player.stats["max_hp"]), sh]
	var t := int(arena.run_time)
	time_label.text = "%02d:%02d" % [t / 60, t % 60]
	info_label.text = "Besiegt: %d    Eliten: %d    %s" % [arena.run_stats["kills"], arena.run_stats["elites"], arena.area_name()]
	_objective.text = arena.objective_text()
	# Fähigkeiten
	for i in 4:
		var n: Dictionary = slot_nodes[i]
		if i < player.skill_slots.size():
			var id: String = player.skill_slots[i]
			n["name"].text = GameData.skills[id]["name"]
			var base := player.skill_cooldown(id)
			var cdv: float = player.cooldowns.get(id, 0.0)
			n["cd"].size.y = 68.0 * clampf(cdv / maxf(base, 0.1), 0.0, 1.0)
			n["cd"].position.y = 68.0 - n["cd"].size.y
			n["cd_l"].text = "%.1f" % cdv if cdv > 0.0 else ""
			var cost: float = float(GameData.skills[id].get("mana", 0))
			n["panel"].modulate = Color(1, 1, 1, 1) if player.mana >= cost else Color(0.6, 0.6, 0.9, 0.9)
		else:
			n["name"].text = ""
			n["cd"].size.y = 0
			n["cd_l"].text = ""
			n["panel"].modulate = Color(1, 1, 1, 0.4)
	_update_passives()
	_update_party()
	# Boss
	var b = arena.get("boss")   # bewusst untypisiert: der Boss kann schon freigegeben sein
	if b != null and is_instance_valid(b) and not b.dead:
		boss_box.visible = true
		boss_name.text = b.display_name() + ("  – geschützt" if b.shielded else "")
		boss_bar.max_value = b.max_hp
		boss_bar.value = b.hp
	else:
		boss_box.visible = false
	if _banner_t > 0.0:
		_banner_t -= delta
		if _banner_t < 0.6:
			banner.modulate.a = maxf(_banner_t / 0.6, 0.0)
	else:
		banner.text = ""
	if _hint_t > 0.0:
		_hint_t -= delta
	else:
		hint.text = ""
	_hurt.color.a = maxf(_hurt.color.a - delta * 0.8, 0.0)
	if player.hp < player.stats["max_hp"] * 0.3:
		_hurt.color.a = maxf(_hurt.color.a, 0.08 + 0.05 * sin(Time.get_ticks_msec() * 0.008))


var _passive_sig := ""

func _update_passives() -> void:
	var sig := str(player.levels.hash())
	if sig == _passive_sig:
		return
	_passive_sig = sig
	UI.clear(passives_box)
	for id in player.levels:
		var d: Dictionary = GameData.skills[id]
		if d["kind"] != "passive":
			continue
		var chip := UI.label("%s %d" % [d["name"], player.levels[id]], 13, GameData.skill_cfg["rarity_colors"].get(d["rarity"], "#fff") if false else Color(GameData.skill_cfg["rarity_colors"][d["rarity"]]))
		passives_box.add_child(chip)
	for e in player.active_evolutions:
		for ev in GameData.evolutions:
			if ev["id"] == e:
				passives_box.add_child(UI.label("★ " + ev["name"], 13, UI.GOLD))


var _party_rows: Array = []


## Gruppenliste: eine Zeile pro Mitglied (Name, Stufe, Lebensbalken). Solo zeigt nur den eigenen Charakter.
func _update_party() -> void:
	var members: Array = []
	if arena != null and arena.has_method("party_members"):
		members = arena.party_members()
	else:
		members = [{"name": player.character.get("name", "Held"), "hp": player.hp, "max": player.stats["max_hp"], "down": false,
				"away": false, "level": player.level, "self": true, "lost": false}]
	if members.size() != _party_rows.size():
		UI.clear(party_box)
		_party_rows.clear()
		for m in members:
			var l := UI.label("", 14, UI.TEXT)
			party_box.add_child(l)
			var b := UI.bar(Color("#6adf7a"), Vector2(170, 8))
			party_box.add_child(b)
			_party_rows.append({"label": l, "bar": b})
	for i in members.size():
		var m: Dictionary = members[i]
		var row: Dictionary = _party_rows[i]
		var status := ""
		if m["lost"]:
			status = "  (verloren)"
		elif m["down"]:
			status = "  (kampfunfähig)"
		elif m["away"]:
			status = "  (getrennt)"
		row["label"].text = "%s  St. %d%s" % [m["name"], m["level"], status]
		row["label"].modulate = Color(1, 1, 1, 0.55) if (m["away"] or m["lost"]) else (Color(1, 0.6, 0.6) if m["down"] else Color.WHITE)
		row["bar"].max_value = maxf(m["max"], 1.0)
		row["bar"].value = m["hp"]
