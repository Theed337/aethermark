class_name Hud
extends Control
## Heads-up-Display im Stil klassischer Action-Rollenspiele:
##  * unten Mitte: Lebenskugel links, Ressourcenkugel (Mana) rechts, dazwischen die Fähigkeitenleiste (LMT, RMT, 1–4)
##    mit Abklingzeit-Sektor, darunter die Erfahrungsleiste; darüber die erworbenen Passiv-Fähigkeiten
##  * oben links: Gruppenrahmen (bis 5 Spieler); oben rechts: Radar, Zeit, Besiegt-Zähler
##  * oben Mitte: Bossleiste und Ziel; Taste K (halten): Übersicht aller erlernten Fähigkeiten mit Stufen
## Alle Größen beziehen sich auf die Basisauflösung 1920x1080 (siehe project.godot, wird automatisch skaliert).

const BAR_W := 1040.0
const BAR_H := 176.0
const SLOT := 80.0

var arena: Node
var player: Player
var health_orb: Orb
var mana_orb: Orb
var xp_bar: ProgressBar
var level_label: Label
var time_label: Label
var info_label: Label
var area_label: Label
var boss_box: Control
var boss_bar: ProgressBar
var boss_name: Label
var banner: Label
var hint: Label
var slots: Array = []                # SkillIcon x 6 (LMT, RMT, 1–4)
var passives_box: HBoxContainer
var party_box: VBoxContainer
var minimap: Minimap
var overview: PanelContainer
var _overview_body: VBoxContainer
var _overview_sig := ""
var _banner_t := 0.0
var _hurt: TextureRect
var _hint_t := 0.0
var _objective: Label
var _hp_prev := -1.0
var _shown_hurt := 0.0
var _passive_sig := ""
var _party_rows: Array = []


func bind(a: Node, p: Player) -> void:
	arena = a
	player = p
	theme = UI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_hurt_vignette()
	_build_top_left()
	_build_top_right()
	_build_top_center()
	_build_bottom()
	_build_overview()


# ------------------------------------------------------------------ Aufbau

func _build_hurt_vignette() -> void:
	_hurt = TextureRect.new()
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	var gr := Gradient.new()
	gr.colors = PackedColorArray([Color(0.7, 0.0, 0.0, 0.0), Color(0.7, 0.0, 0.0, 0.0), Color(0.75, 0.02, 0.02, 0.85)])
	gr.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.gradient = gr
	g.width = 256
	g.height = 256
	_hurt.texture = g
	_hurt.stretch_mode = TextureRect.STRETCH_SCALE
	_hurt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hurt.modulate.a = 0.0
	add_child(_hurt)


func _build_top_left() -> void:
	party_box = VBoxContainer.new()
	party_box.position = Vector2(24, 22)
	party_box.add_theme_constant_override("separation", 6)
	party_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(party_box)


func _build_top_right() -> void:
	minimap = Minimap.new()
	_anchor(minimap, 1.0, 0.0, -264, 22, 240, 240)
	minimap.bind(arena, player)
	add_child(minimap)
	var v := VBoxContainer.new()
	_anchor(v, 1.0, 0.0, -264, 268, 240, 60)
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	area_label = _outlined(UI.label("", 15, Color("#d8c9a0")))
	area_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(area_label)
	time_label = _outlined(UI.label("00:00", 24, UI.GOLD, true))
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(time_label)
	info_label = _outlined(UI.label("", 14, UI.DIM))
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info_label)


func _build_top_center() -> void:
	boss_box = VBoxContainer.new()
	_anchor(boss_box, 0.5, 0.0, -380, 22, 760, 40)
	boss_box.visible = false
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(boss_box)
	boss_name = _outlined(UI.label("", 22, UI.GOLD, true))
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(boss_name)
	boss_bar = UI.bar(Color("#c0301f"), Vector2(760, 22))
	boss_bar.add_theme_stylebox_override("background", UI.box(Color(0.05, 0.03, 0.03, 0.9), 4, Color("#8a6a2a"), 3, 0))
	boss_bar.add_theme_stylebox_override("fill", UI.box(Color("#c0301f"), 3, Color(0, 0, 0, 0), 0, 0))
	boss_box.add_child(boss_bar)
	_objective = _outlined(UI.label("", 17, Color("#9be8e0")))
	_anchor(_objective, 0.5, 0.0, -380, 26, 760, 26)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_objective)
	banner = UI.label("", 40, UI.GOLD, true)
	_anchor(banner, 0.5, 0.0, -500, 190, 1000, 60)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_constant_override("outline_size", 10)
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	add_child(banner)
	hint = _outlined(UI.label("", 22, Color.WHITE, true))
	_anchor(hint, 0.5, 0.5, -400, 120, 800, 34)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)


func _build_bottom() -> void:
	var bar := Control.new()
	_anchor(bar, 0.5, 1.0, -BAR_W * 0.5, -BAR_H - 6, BAR_W, BAR_H)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	# Steinplatte zwischen den Kugeln
	var plate := Panel.new()
	plate.position = Vector2(110, 62)
	plate.size = Vector2(BAR_W - 220, BAR_H - 62)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.055, 0.05, 0.96)
	sb.border_color = Color("#6b5226")
	sb.set_border_width_all(3)
	sb.border_width_top = 4
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 8
	plate.add_theme_stylebox_override("panel", sb)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(plate)
	var trim := Panel.new()
	trim.position = plate.position + Vector2(6, 6)
	trim.size = plate.size - Vector2(12, 8)
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0, 0, 0, 0)
	tsb.border_color = Color("#2d2112")
	tsb.set_border_width_all(2)
	tsb.corner_radius_top_left = 10
	tsb.corner_radius_top_right = 10
	trim.add_theme_stylebox_override("panel", tsb)
	trim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(trim)
	# Kugeln
	health_orb = Orb.new()
	health_orb.position = Vector2(4, 12)
	health_orb.size = Vector2(164, 164)
	health_orb.setup(Color("#5a0508"), Color("#f02a1e"))
	bar.add_child(health_orb)
	mana_orb = Orb.new()
	mana_orb.position = Vector2(BAR_W - 168, 12)
	mana_orb.size = Vector2(164, 164)
	mana_orb.setup(Color("#06235a"), Color("#2a8cff"))
	mana_orb.frame_color = Color("#6a7a9a")
	bar.add_child(mana_orb)
	# Fähigkeitenleiste
	var keys := ["LMT", "RMT", "1", "2", "3", "4"]
	var gap := 12.0
	var total := 6.0 * SLOT + 5.0 * gap
	var x0 := (BAR_W - total) * 0.5
	for i in 6:
		var ic := SkillIcon.new()
		ic.size = Vector2(SLOT, SLOT)
		ic.position = Vector2(x0 + i * (SLOT + gap), 78)
		ic.key_text = keys[i]
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(ic)
		slots.append(ic)
	# Erfahrungsleiste und Stufe
	xp_bar = UI.bar(Color("#e0b030"), Vector2(total, 10))
	xp_bar.position = Vector2(x0, 168 - 14)
	xp_bar.size = Vector2(total, 10)
	xp_bar.add_theme_stylebox_override("background", UI.box(Color(0.02, 0.02, 0.03, 0.95), 3, Color("#4a3a1a"), 2, 0))
	xp_bar.add_theme_stylebox_override("fill", UI.box(Color("#d8a830"), 2, Color(0, 0, 0, 0), 0, 0))
	bar.add_child(xp_bar)
	level_label = _outlined(UI.label("Stufe 1", 17, UI.GOLD, true))
	level_label.position = Vector2(x0, 50)
	bar.add_child(level_label)
	var ov := _outlined(UI.label("K halten: Fähigkeiten-Übersicht", 13, Color(0.8, 0.75, 0.6, 0.75)))
	ov.position = Vector2(x0 + total - 250, 52)
	ov.size = Vector2(250, 20)
	ov.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(ov)
	# Passive Fähigkeiten über der Leiste
	passives_box = HBoxContainer.new()
	_anchor(passives_box, 0.5, 1.0, -460, -BAR_H - 62, 920, 46)
	passives_box.alignment = BoxContainer.ALIGNMENT_CENTER
	passives_box.add_theme_constant_override("separation", 6)
	passives_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(passives_box)


func _build_overview() -> void:
	overview = PanelContainer.new()
	_anchor(overview, 0.5, 0.5, -510, -330, 1020, 10)
	overview.visible = false
	overview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overview.add_theme_stylebox_override("panel", UI.box(Color(0.05, 0.045, 0.05, 0.96), 10, Color("#8a6a2a"), 3, 16))
	add_child(overview)
	_overview_body = VBoxContainer.new()
	_overview_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overview.add_child(_overview_body)


## Platziert ein Control relativ zu einem Ankerpunkt (ax, ay in 0..1) mit festen Offsets. Unabhängig von der aktuellen Elterngröße.
func _anchor(c: Control, ax: float, ay: float, x: float, y: float, w: float, h: float) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = x
	c.offset_top = y
	c.offset_right = x + w
	c.offset_bottom = y + h


func _outlined(l: Label) -> Label:
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	return l


# ------------------------------------------------------------------ API für Arena/ClientArena

func show_banner(text: String, color: Color = UI.GOLD, duration: float = 2.8) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.modulate.a = 1.0
	_banner_t = duration


func show_hint(text: String, duration: float = 1.2) -> void:
	hint.text = text
	_hint_t = duration


func flash_hurt() -> void:
	_shown_hurt = 0.55


# ------------------------------------------------------------------ Aktualisierung

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var maxhp: float = maxf(float(player.stats["max_hp"]), 1.0)
	health_orb.set_level(player.hp / maxhp, delta)
	var shield_txt := ("+%d" % int(player.shield)) if player.shield > 0.5 else ""
	health_orb.text = "%d%s" % [int(ceil(player.hp)), (" " + shield_txt) if shield_txt != "" else ""]
	health_orb.set_pulse(0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012) if player.hp < maxhp * 0.25 else 0.0)
	health_orb.queue_redraw()
	var maxmana: float = maxf(float(player.stats["mana_max"]), 1.0)
	mana_orb.set_level(player.mana / maxmana, delta)
	mana_orb.text = "%d" % int(player.mana)
	mana_orb.queue_redraw()
	xp_bar.max_value = GameData.xp_needed(player.level)
	xp_bar.value = player.xp
	level_label.text = "Stufe %d   (%d / %d EP)" % [player.level, player.xp, GameData.xp_needed(player.level)]
	var t := int(arena.run_time)
	time_label.text = "%02d:%02d" % [t / 60, t % 60]
	area_label.text = arena.area_name()
	info_label.text = "Besiegt %d   Elite %d" % [arena.run_stats["kills"], arena.run_stats["elites"]]
	_objective.text = arena.objective_text()
	_update_slots()
	_update_passives()
	_update_party()
	_update_boss()
	_update_overview()
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
	_shown_hurt = maxf(_shown_hurt - delta * 0.9, 0.0)
	var low := 0.0
	if player.hp < maxhp * 0.3:
		low = 0.18 + 0.1 * sin(Time.get_ticks_msec() * 0.008)
	_hurt.modulate.a = maxf(_shown_hurt, low)


func _update_slots() -> void:
	var wid_light := "_light"
	var wid_heavy := "_heavy"
	slots[0].setup(wid_light, 0) if slots[0].skill_id != wid_light else null
	slots[1].setup(wid_heavy, 0) if slots[1].skill_id != wid_heavy else null
	for i in 4:
		var ic: SkillIcon = slots[2 + i]
		if i < player.skill_slots.size():
			var id: String = player.skill_slots[i]
			var lv := player.skill_lv(id)
			if ic.skill_id != id or ic.level != lv:
				ic.setup(id, lv)
			var base := player.skill_cooldown(id)
			var cdv: float = player.cooldowns.get(id, 0.0)
			ic.cd_frac = clampf(cdv / maxf(base, 0.1), 0.0, 1.0)
			ic.cd_text = ("%.1f" % cdv) if cdv > 0.0 else ""
			var cost: float = float(GameData.skills[id].get("mana", 0))
			ic.dim = player.mana < cost
		else:
			if ic.skill_id != "":
				ic.setup("", 0)
			ic.cd_frac = 0.0
		ic.queue_redraw()


func _update_boss() -> void:
	var b = arena.get("boss")   # bewusst untypisiert: der Boss kann schon freigegeben sein
	if b != null and is_instance_valid(b) and not b.dead:
		boss_box.visible = true
		boss_name.text = b.display_name() + ("  – geschützt" if b.shielded else "")
		boss_bar.max_value = b.max_hp
		boss_bar.value = b.hp
		_objective.position.y = 100
	else:
		boss_box.visible = false
		_objective.position.y = 26


func _update_passives() -> void:
	var sig := str(player.levels.hash()) + str(player.active_evolutions)
	if sig == _passive_sig:
		return
	_passive_sig = sig
	UI.clear(passives_box)
	for id in player.levels:
		var d: Dictionary = GameData.skills[id]
		if d["kind"] != "passive" or int(player.levels[id]) <= 0:
			continue
		var ic := SkillIcon.new()
		ic.custom_minimum_size = Vector2(44, 44)
		ic.setup(id, int(player.levels[id]))
		ic.key_text = ""
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		passives_box.add_child(ic)
		var lv := _outlined(UI.label(str(player.levels[id]), 13, Color.WHITE, true))
		lv.position = Vector2(30, 24)
		ic.add_child(lv)
	for e in player.active_evolutions:
		for ev in GameData.evolutions:
			if ev["id"] == e:
				var star := _outlined(UI.label("★ " + ev["name"], 15, UI.GOLD, true))
				passives_box.add_child(star)


## Gruppenrahmen: Porträtkreis, Name, Stufe, Lebensbalken. Solo zeigt nur den eigenen Charakter.
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
		for i in members.size():
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var port := PartyPortrait.new()
			port.custom_minimum_size = Vector2(58, 58)
			row.add_child(port)
			var col := VBoxContainer.new()
			col.add_theme_constant_override("separation", 2)
			col.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var l := _outlined(UI.label("", 15, UI.TEXT, true))
			col.add_child(l)
			var b := UI.bar(Color("#c02a22"), Vector2(190, 12))
			b.add_theme_stylebox_override("background", UI.box(Color(0.03, 0.02, 0.02, 0.9), 3, Color("#5a4420"), 2, 0))
			col.add_child(b)
			row.add_child(col)
			party_box.add_child(row)
			_party_rows.append({"label": l, "bar": b, "portrait": port})
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
		var port: PartyPortrait = row["portrait"]
		port.set_member(str(m["name"]), i, bool(m["down"]), bool(m["self"]))


# ------------------------------------------------------------------ Fähigkeiten-Übersicht (Taste K halten)

func _update_overview() -> void:
	var want := Input.is_action_pressed("skills_overview")
	overview.visible = want
	if not want:
		return
	var sig := str(player.levels.hash()) + str(player.active_evolutions) + str(player.skill_slots)
	if sig == _overview_sig:
		return
	_overview_sig = sig
	UI.clear(_overview_body)
	_overview_body.add_child(UI.label("Deine Fähigkeiten in diesem Run", 26, UI.GOLD, true))
	var actives: Array = []
	var passives: Array = []
	for id in player.levels:
		if int(player.levels[id]) <= 0:
			continue
		if GameData.skills[id]["kind"] == "active":
			actives.append(id)
		else:
			passives.append(id)
	if actives.is_empty() and passives.is_empty():
		var l := UI.label("Noch nichts erlernt – bei jedem Stufenaufstieg wählst du eine neue Fähigkeit.", 17, UI.DIM)
		_overview_body.add_child(l)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	cols.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overview_body.add_child(cols)
	cols.add_child(_overview_column("Aktive Fähigkeiten (Tasten 1–4)", actives))
	cols.add_child(_overview_column("Passive Fähigkeiten", passives))
	if not player.active_evolutions.is_empty():
		_overview_body.add_child(UI.label("Aktive Entwicklungen", 18, UI.TEAL, true))
		for e in player.active_evolutions:
			for ev in GameData.evolutions:
				if ev["id"] == e:
					var l := UI.label("★ %s – %s" % [ev["name"], ev["desc"]], 15, UI.GOLD)
					l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					l.custom_minimum_size = Vector2(960, 0)
					_overview_body.add_child(l)
	var open_evo: Array = []
	for ev in GameData.evolutions:
		if not (ev["id"] in player.active_evolutions):
			var parts: Array = []
			for rid in ev["requires"]:
				parts.append("%s %d/%d" % [GameData.skills[rid]["name"], player.skill_lv(rid), int(ev["requires"][rid])])
			open_evo.append("%s: %s" % [ev["name"], ", ".join(parts)])
	if not open_evo.is_empty():
		var l := UI.label("Mögliche Entwicklungen – " + "  |  ".join(open_evo), 13, UI.DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(960, 0)
		_overview_body.add_child(l)


func _overview_column(title: String, ids: Array) -> Control:
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(480, 0)
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(UI.label(title, 18, UI.TEAL, true))
	if ids.is_empty():
		v.add_child(UI.label("–", 15, UI.DIM))
	for id in ids:
		var d: Dictionary = GameData.skills[id]
		var lv := int(player.levels[id])
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := SkillIcon.new()
		ic.custom_minimum_size = Vector2(52, 52)
		ic.setup(id, lv)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ic)
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 0)
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var head := "%s  –  Stufe %d/%d" % [d["name"], lv, int(d["max_level"])]
		if d["kind"] == "active":
			head += "   (%.0f s, %d Mana)" % [float(d.get("cooldown", 0)), int(d.get("mana", 0))]
		var rc := Color(GameData.skill_cfg["rarity_colors"].get(d["rarity"], "#fff"))
		tv.add_child(UI.label(head, 16, rc, true))
		var txt := UI.label(str(d["levels"][mini(lv, d["levels"].size()) - 1]), 13, UI.DIM)
		txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		txt.custom_minimum_size = Vector2(410, 0)
		tv.add_child(txt)
		row.add_child(tv)
		v.add_child(row)
	return v


## Kleines rundes Porträt für den Gruppenrahmen (Anfangsbuchstabe, Farbe je Platz).
class PartyPortrait:
	extends Control
	const COLORS := [Color("#d8a02a"), Color("#3aa0d8"), Color("#5ad86a"), Color("#c85ad8"), Color("#d85a5a")]
	var nm := ""
	var idx := 0
	var down := false
	var is_self := false

	func set_member(n: String, i: int, d: bool, s: bool) -> void:
		if n != nm or i != idx or d != down or s != is_self:
			nm = n
			idx = i
			down = d
			is_self = s
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.0
		var col: Color = COLORS[idx % COLORS.size()]
		draw_circle(c, r, Color(0.04, 0.03, 0.03, 0.95))
		draw_circle(c, r - 4.0, col.darkened(0.55) if not down else Color(0.3, 0.3, 0.3))
		var f := ThemeDB.fallback_font
		var ch := nm.substr(0, 1).to_upper()
		var ts := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 28)
		draw_string(f, c + Vector2(-ts.x * 0.5, ts.y * 0.32), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, col.lightened(0.5))
		draw_arc(c, r, 0, TAU, 40, Color("#2a1e0c"), 5.0, true)
		draw_arc(c, r - 1.0, 0, TAU, 40, col if is_self else Color("#8a6a2a"), 2.5, true)
