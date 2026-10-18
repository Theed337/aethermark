class_name PageInventory
extends MenuPage
## Ausrüstung & Inventar: Plätze, Filter, Sortierung, Vergleich mit der angelegten Ausrüstung, Sperren, Verwerfen.

const SLOT_ORDER := ["weapon", "offhand", "head", "chest", "hands", "legs", "feet", "amulet", "ring1", "ring2", "artifact"]
const RARITY_ORDER := ["common", "uncommon", "rare", "epic", "legendary", "mythic"]

var selected_uid := ""
var filter_slot := "all"
var filter_rarity := "all"
var sort_mode := 0
var _equip_box: VBoxContainer
var _list_box: VBoxContainer
var _detail: VBoxContainer
var _count_label: Label


func _init() -> void:
	wide = true


func build() -> void:
	var v := VBoxContainer.new()
	add_child(v)
	v.add_child(title("Ausrüstung & Inventar", "Gefundene Ausrüstung bleibt dauerhaft erhalten. Gesperrte Gegenstände werden nie verworfen oder getauscht."))
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(h)
	# Ausrüstungsplätze
	var ep := UI.panel(Vector2(300, 0))
	h.add_child(ep)
	var esc := ScrollContainer.new()
	ep.add_child(esc)
	_equip_box = VBoxContainer.new()
	_equip_box.custom_minimum_size = Vector2(275, 0)
	esc.add_child(_equip_box)
	# Liste
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(mid)
	var fr := HBoxContainer.new()
	mid.add_child(fr)
	var slot_opt := UI.option()
	slot_opt.add_item("Alle Plätze")
	for s in SLOT_ORDER:
		slot_opt.add_item(GameData.items_cfg["slots"][s])
	slot_opt.item_selected.connect(func(i: int):
		filter_slot = "all" if i == 0 else SLOT_ORDER[i - 1]
		_fill_list())
	fr.add_child(slot_opt)
	var rar_opt := UI.option()
	rar_opt.add_item("Alle Seltenheiten")
	for r in RARITY_ORDER:
		rar_opt.add_item(GameData.rarity_name(r))
	rar_opt.item_selected.connect(func(i: int):
		filter_rarity = "all" if i == 0 else RARITY_ORDER[i - 1]
		_fill_list())
	fr.add_child(rar_opt)
	var sort_opt := UI.option()
	for n in ["Seltenheit", "Stufe", "Name", "Platz"]:
		sort_opt.add_item("Sortiert: " + n)
	sort_opt.item_selected.connect(func(i: int):
		sort_mode = i
		_fill_list())
	fr.add_child(sort_opt)
	_count_label = UI.label("", 15, UI.DIM)
	fr.add_child(_count_label)
	var lp := UI.panel()
	lp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(lp)
	var lsc := ScrollContainer.new()
	lsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lp.add_child(lsc)
	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 3)
	lsc.add_child(_list_box)
	# Details
	var dp := UI.panel(Vector2(360, 0))
	h.add_child(dp)
	var dsc := ScrollContainer.new()
	dsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dp.add_child(dsc)
	_detail = VBoxContainer.new()
	_detail.custom_minimum_size = Vector2(335, 0)
	dsc.add_child(_detail)
	refresh()


func refresh() -> void:
	_fill_equipment()
	_fill_list()
	_fill_detail()
	menu.refresh_header()


func _fill_equipment() -> void:
	UI.clear(_equip_box)
	var c := character()
	_equip_box.add_child(UI.label("Angelegt", 20, UI.GOLD, true))
	for s in SLOT_ORDER:
		var uid: String = c["equipment"].get(s, "")
		var it := SaveSystem.find_item(c, uid) if uid != "" else {}
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 44)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		var sname: String = GameData.items_cfg["slots"][s]
		if it.is_empty():
			b.text = "%s: —" % sname
			b.add_theme_color_override("font_color", UI.DIM)
			b.disabled = false
		else:
			b.text = "%s: %s" % [sname, it["name"]]
			b.add_theme_color_override("font_color", DataColors.rarity(it["rarity"]))
			var uu: String = it["uid"]
			b.pressed.connect(func():
				selected_uid = uu
				_fill_detail())
		_equip_box.add_child(b)
	_equip_box.add_child(HSeparator.new())
	var st := Stats.compute(c)
	_equip_box.add_child(UI.label("Werte", 18, UI.TEAL, true))
	for row in [["Leben", "%d" % st["max_hp"]], ["Schaden", "%.1f" % st["damage"]], ["Krit", "%.1f%%" % (st["crit_chance"] * 100.0)],
			["Verteidigung", "%.0f" % st["defense"]], ["Tempo", "%.2f" % st["move_speed"]]]:
		_equip_box.add_child(UI.label("%s: %s" % row, 15))


func visible_items() -> Array:
	var c := character()
	var out: Array = []
	for it in c["inventory"]:
		if filter_slot != "all":
			var s: String = it["slot"]
			if filter_slot.begins_with("ring"):
				if not s.begins_with("ring"):
					continue
			elif s != filter_slot:
				continue
		if filter_rarity != "all" and it["rarity"] != filter_rarity:
			continue
		out.append(it)
	match sort_mode:
		0: out.sort_custom(func(a, b): return RARITY_ORDER.find(a["rarity"]) > RARITY_ORDER.find(b["rarity"]))
		1: out.sort_custom(func(a, b): return int(a["level"]) > int(b["level"]))
		2: out.sort_custom(func(a, b): return str(a["name"]) < str(b["name"]))
		3: out.sort_custom(func(a, b): return SLOT_ORDER.find(a["slot"]) < SLOT_ORDER.find(b["slot"]))
	return out


func _fill_list() -> void:
	UI.clear(_list_box)
	var c := character()
	var items := visible_items()
	_count_label.text = "  %d / %d Plätze" % [c["inventory"].size(), SaveSystem.INVENTORY_CAP]
	if items.is_empty():
		_list_box.add_child(UI.label("Keine Gegenstände für diesen Filter.", 15, UI.DIM))
	for it in items:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 40)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		var equipped := _is_equipped(c, it["uid"])
		b.text = "%s%s%s   [%s · Stufe %d]" % ["⚿ " if it.get("locked", false) else "", "[A] " if equipped else "", it["name"], GameData.items_cfg["slots"].get(it["slot"], it["slot"]), it["level"]]
		b.add_theme_color_override("font_color", DataColors.rarity(it["rarity"]))
		b.add_theme_color_override("font_hover_color", DataColors.rarity(it["rarity"]).lightened(0.4))
		var uid: String = it["uid"]
		b.pressed.connect(func():
			selected_uid = uid
			_fill_detail())
		_list_box.add_child(b)


func _is_equipped(c: Dictionary, uid: String) -> bool:
	for s in c["equipment"]:
		if c["equipment"][s] == uid:
			return true
	return false


func equipped_in_slot(c: Dictionary, slot: String) -> Dictionary:
	var s := slot
	if slot.begins_with("ring"):
		s = "ring1"
	var uid: String = c["equipment"].get(s, "")
	return SaveSystem.find_item(c, uid) if uid != "" else {}


func _stat_line(k: String, v: float) -> String:
	var labels: Dictionary = GameData.items_cfg["stat_labels"]
	var pct: Array = GameData.items_cfg["pct_stats"]
	var sign := "+" if v >= 0.0 else ""
	if k in pct:
		return "%s%.1f%% %s" % [sign, v * 100.0, str(labels.get(k, k)).replace(" %", "")]
	return "%s%s %s" % [sign, TalentTree._fmt(v), labels.get(k, k)]


func _fill_detail() -> void:
	UI.clear(_detail)
	var c := character()
	var it := SaveSystem.find_item(c, selected_uid) if selected_uid != "" else {}
	if it.is_empty():
		_detail.add_child(UI.label("Gegenstand wählen", 20, UI.DIM))
		_detail.add_child(UI.label("Klicke links oder in der Liste auf einen Gegenstand, um Werte und den Vergleich mit deiner Ausrüstung zu sehen.", 15, UI.DIM))
		return
	var col := DataColors.rarity(it["rarity"])
	var nm := UI.label(it["name"], 22, col, true)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(nm)
	_detail.add_child(UI.label("%s · %s · Stufe %d" % [GameData.rarity_name(it["rarity"]), GameData.items_cfg["slots"].get(it["slot"], it["slot"]), it["level"]], 15, UI.DIM))
	if it.has("weapon_type"):
		_detail.add_child(UI.label("Waffentyp: " + GameData.items_cfg["weapon_types"][it["weapon_type"]]["name"], 15, UI.DIM))
	for k in it["stats"]:
		if k == "flags":
			for f in it["stats"][k]:
				var fl := UI.label("★ " + TalentTree.flag_text(f), 14, UI.GOLD)
				fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				_detail.add_child(fl)
			continue
		var v: float = float(it["stats"][k])
		_detail.add_child(UI.label(_stat_line(k, v), 16, UI.RED if v < 0.0 else UI.TEXT))
	if it.get("text", "") != "":
		var t := UI.label(it["text"], 14, UI.GOLD)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(t)
	_detail.add_child(UI.label("Handelbar: %s" % ("ja" if it.get("tradable", false) and not it.get("locked", false) else "nein"), 14, UI.DIM))
	# Vergleich
	var equipped := equipped_in_slot(c, it["slot"])
	if not equipped.is_empty() and equipped["uid"] != it["uid"]:
		_detail.add_child(HSeparator.new())
		_detail.add_child(UI.label("Vergleich mit: " + equipped["name"], 16, UI.TEAL, true))
		var cmp := Loot.compare(equipped, it)
		for k in cmp:
			var d: Dictionary = cmp[k]
			var diff: float = d["diff"]
			if absf(diff) < 0.0001:
				continue
			var r := HBoxContainer.new()
			var l := UI.label(str(GameData.items_cfg["stat_labels"].get(k, k)).replace(" %", ""), 14)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r.add_child(l)
			var pct: bool = k in GameData.items_cfg["pct_stats"]
			var f := func(x: float) -> String: return ("%.1f%%" % (x * 100.0)) if pct else TalentTree._fmt(x)
			r.add_child(UI.label("%s → %s" % [f.call(d["a"]), f.call(d["b"])], 14, UI.DIM))
			r.add_child(UI.label(("  +" if diff > 0 else "  ") + f.call(diff), 14, UI.TEAL if diff > 0.0 else UI.RED, true))
			_detail.add_child(r)
		var after := hypothetical_stats(c, it["uid"])
		var before := Stats.compute(c)
		_detail.add_child(UI.label("Gesamtwerte: Schaden %.1f → %.1f · Leben %d → %d · Verteidigung %.0f → %.0f" % [before["damage"], after["damage"], before["max_hp"], after["max_hp"], before["defense"], after["defense"]], 14, UI.GOLD))
	# Aktionen
	_detail.add_child(HSeparator.new())
	var eqd := _is_equipped(c, it["uid"])
	var ab := UI.button("Ablegen" if eqd else "Anlegen", func(): toggle_equip(), Vector2(0, 42))
	_detail.add_child(ab)
	var lb := UI.button("Entsperren" if it.get("locked", false) else "Sperren", func(): toggle_lock(), Vector2(0, 38))
	_detail.add_child(lb)
	var db := UI.button("Verwerfen", func(): discard(), Vector2(0, 38))
	db.disabled = it.get("locked", false) or eqd
	db.tooltip_text = "Gesperrte und angelegte Gegenstände können nicht verworfen werden."
	_detail.add_child(db)


func hypothetical_stats(c: Dictionary, uid: String) -> Dictionary:
	var copy: Dictionary = c.duplicate(true)
	SaveSystem.equip(copy, uid)
	return Stats.compute(copy)


func toggle_equip() -> void:
	var c := character()
	var it := SaveSystem.find_item(c, selected_uid)
	if it.is_empty():
		return
	if _is_equipped(c, selected_uid):
		for s in c["equipment"].keys():
			if c["equipment"][s] == selected_uid:
				SaveSystem.unequip(c, s)
	else:
		SaveSystem.equip(c, selected_uid)
	SaveSystem.save_game()
	Sfx.play("loot", 1.0, -8.0)
	refresh()


func toggle_lock() -> void:
	var it := SaveSystem.find_item(character(), selected_uid)
	if it.is_empty():
		return
	it["locked"] = not it.get("locked", false)
	SaveSystem.save_game()
	refresh()


func discard() -> void:
	var c := character()
	var it := SaveSystem.find_item(c, selected_uid)
	if it.is_empty() or it.get("locked", false) or _is_equipped(c, selected_uid):
		return
	SaveSystem.remove_item(c, selected_uid)
	selected_uid = ""
	SaveSystem.save_game()
	refresh()
