class_name PageInventory
extends MenuPage
## Ausrüstung & Inventar im Stil klassischer Rollenspiele:
##  * Tab "Ausrüstung": Charakteransicht mit Plätzen links/rechts/unten (Paper-Doll), Gegenstände per Drag & Drop
##    aus dem Inventar auf einen Platz ziehen (oder Doppelklick), Ablegen durch Zurückziehen; Vergleichswerte rechts.
##  * Tab "Händler": Verkauf (Gegenstand auf den Händler ziehen) und ein Angebot, das alle 20 Minuten wechselt.
##  * Tab "Sammlung & Kosmetik": freigeschaltete Kosmetik und Titel.
## Der Charakter links zeigt Waffe und Rüstungsteile live (siehe CharacterModel.gear_looks).

const SLOT_ORDER := ["weapon", "offhand", "head", "chest", "hands", "legs", "feet", "amulet", "ring1", "ring2", "artifact"]
const RARITY_ORDER := ["common", "uncommon", "rare", "epic", "legendary", "mythic"]
const LEFT_SLOTS := ["head", "chest", "hands", "legs", "feet"]
const RIGHT_SLOTS := ["amulet", "ring1", "ring2", "artifact", "offhand"]

var tab := "gear"
var selected_uid := ""
var selected_shop := -1
var filter_slot := "all"
var filter_rarity := "all"
var sort_mode := 0
var _content: Control
var _tab_buttons: Dictionary = {}
var _gold_label: Label
var _preview: CharPreview
var _list_box: VBoxContainer
var _detail: VBoxContainer
var _count_label: Label
var _stats_box: VBoxContainer
var _slot_tiles: Dictionary = {}
var _shop_box: VBoxContainer
var _timer_label: Label
var _shop_rot := -1
var _msg: Label
var _tick := 0.0


func _init() -> void:
	wide = true


func build() -> void:
	var v := VBoxContainer.new()
	add_child(v)
	v.add_child(title("Ausrüstung & Inventar", "Ziehe Gegenstände auf den Charakter, um sie anzulegen. Gesperrte Gegenstände werden nie verkauft oder verworfen."))
	var tb := HBoxContainer.new()
	tb.add_theme_constant_override("separation", 8)
	v.add_child(tb)
	for t in [["gear", "Ausrüstung"], ["shop", "Händler"], ["collection", "Sammlung & Kosmetik"]]:
		var key: String = t[0]
		var b := UI.button(t[1], func(): _set_tab(key), Vector2(190, 38))
		b.toggle_mode = true
		b.button_pressed = key == tab
		_tab_buttons[key] = b
		tb.add_child(b)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb.add_child(sp)
	_gold_label = UI.label("", 20, UI.GOLD, true)
	tb.add_child(_gold_label)
	_msg = UI.label("", 15, UI.TEAL)
	v.add_child(_msg)
	_content = VBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_content)
	_set_tab(tab)


func _set_tab(t: String) -> void:
	tab = t
	for k in _tab_buttons:
		_tab_buttons[k].set_pressed_no_signal(k == t)
	UI.clear(_content)
	_slot_tiles.clear()
	_preview = null
	_say("")
	match t:
		"gear":
			_build_gear()
		"shop":
			_build_shop()
		_:
			var pc := PageCollection.new()
			pc.menu = menu
			pc.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_content.add_child(pc)
			pc.build()
	_update_gold()


func _say(t: String) -> void:
	if _msg != null and is_instance_valid(_msg):
		_msg.text = t


func _update_gold() -> void:
	if _gold_label != null:
		_gold_label.text = "Gold: %d" % int(character().get("gold", 0))
	if menu != null:
		menu.refresh_header()


func refresh() -> void:
	if tab == "gear":
		_fill_slots()
		_fill_list()
		_fill_detail()
		_fill_stats()
		if _preview != null:
			_preview.show_character(character())
	elif tab == "shop":
		_fill_shop()
	_update_gold()
	_update_sell_all_text()


# ------------------------------------------------------------------ Tab Ausrüstung

func _build_gear() -> void:
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 8)
	_content.add_child(h)
	# Paper-Doll
	var dp := UI.panel(Vector2(520, 0))
	h.add_child(dp)
	var dv := VBoxContainer.new()
	dp.add_child(dv)
	var mid := HBoxContainer.new()
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 6)
	dv.add_child(mid)
	mid.add_child(_slot_column(LEFT_SLOTS))
	_preview = CharPreview.new()
	_preview.custom_minimum_size = Vector2(250, 400)
	mid.add_child(_preview)
	mid.add_child(_slot_column(RIGHT_SLOTS))
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	dv.add_child(bottom)
	bottom.add_child(_slot_tile("weapon", Vector2(150, 64)))
	dv.add_child(HSeparator.new())
	_stats_box = VBoxContainer.new()
	dv.add_child(_stats_box)
	# Inventarliste
	var midp := VBoxContainer.new()
	midp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(midp)
	_build_filters(midp)
	midp.add_child(_make_sell_all_button())
	var lp := DropZone.new()
	lp.add_theme_stylebox_override("panel", UI.box(Color("#142033"), 10, Color("#2a3a55"), 2, 8))
	lp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lp.drop_check = func(d: Dictionary) -> bool: return d.get("from", "") == "slot"
	lp.drop_do = func(d: Dictionary): _unequip_uid(str(d["uid"]))
	midp.add_child(lp)
	var lsc := ScrollContainer.new()
	lsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lp.add_child(lsc)
	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lsc.add_child(_list_box)
	# Details
	var dtp := UI.panel(Vector2(340, 0))
	h.add_child(dtp)
	var dsc := ScrollContainer.new()
	dsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dtp.add_child(dsc)
	_detail = VBoxContainer.new()
	_detail.custom_minimum_size = Vector2(315, 0)
	dsc.add_child(_detail)
	refresh()


func _slot_column(slots: Array) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	for s in slots:
		col.add_child(_slot_tile(s, Vector2(104, 72)))
	return col


func _slot_tile(slot: String, size: Vector2) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = size
	_slot_tiles[slot] = holder
	return holder


func _fill_slots() -> void:
	var c := character()
	for s in _slot_tiles:
		var holder: Control = _slot_tiles[s]
		UI.clear(holder)
		var uid: String = c["equipment"].get(s, "")
		var it := SaveSystem.find_item(c, uid) if uid != "" else {}
		var sname: String = GameData.items_cfg["slots"][s]
		var t := ItemTile.make(it, sname, holder.custom_minimum_size, not it.is_empty(), not it.is_empty() and it["uid"] == selected_uid)
		t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var slot_id: String = s
		if not it.is_empty():
			var uu: String = it["uid"]
			t.payload = {"uid": uu, "from": "slot"}
			t.pressed.connect(func():
				selected_uid = uu
				_fill_slots()
				_fill_list()
				_fill_detail())
			t.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and ev.pressed and ev.double_click and ev.button_index == MOUSE_BUTTON_LEFT:
					_unequip_uid(uu))
		t.drop_check = func(d: Dictionary) -> bool: return d.get("from", "") == "inv" and _fits(str(d["uid"]), slot_id)
		t.drop_do = func(d: Dictionary): _equip_to(str(d["uid"]), slot_id)
		holder.add_child(t)


func _fits(uid: String, slot: String) -> bool:
	var it := SaveSystem.find_item(character(), uid)
	if it.is_empty():
		return false
	var s: String = it["slot"]
	if slot.begins_with("ring"):
		return s.begins_with("ring")
	return s == slot


func _equip_to(uid: String, slot: String) -> void:
	var c := character()
	if not _fits(uid, slot):
		return
	if slot.begins_with("ring"):
		SaveSystem._unequip_uid(c, uid)
		c["equipment"][slot] = uid
	else:
		SaveSystem.equip(c, uid)
	selected_uid = uid
	_after_gear_change()


func _unequip_uid(uid: String) -> void:
	var c := character()
	for s in c["equipment"].keys():
		if c["equipment"][s] == uid:
			SaveSystem.unequip(c, s)
	_after_gear_change()


func _after_gear_change() -> void:
	SaveSystem.save_game()
	Sfx.play("loot", 1.0, -8.0)
	menu.show_active_character()
	refresh()


func _fill_stats() -> void:
	UI.clear(_stats_box)
	var st := Stats.compute(character())
	var row := HBoxContainer.new()
	_stats_box.add_child(row)
	var cols := [["Leben", "%d" % st["max_hp"]], ["Schaden", "%.1f" % st["damage"]], ["Krit", "%.1f%%" % (st["crit_chance"] * 100.0)],
			["Rüstung", "%.0f" % st["defense"]], ["Tempo", "%.2f" % st["move_speed"]]]
	for cc in cols:
		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_child(UI.label(cc[0], 12, UI.DIM))
		vb.add_child(UI.label(cc[1], 17, UI.TEXT, true))
		row.add_child(vb)


func _build_filters(parent: Control) -> void:
	var fr := HBoxContainer.new()
	parent.add_child(fr)
	var slot_opt := UI.option()
	slot_opt.add_item("Alle Plätze")
	for s in SLOT_ORDER:
		slot_opt.add_item(GameData.items_cfg["slots"][s])
	slot_opt.item_selected.connect(func(i: int):
		filter_slot = "all" if i == 0 else SLOT_ORDER[i - 1]
		_fill_list())
	slot_opt.custom_minimum_size = Vector2(150, 0)
	fr.add_child(slot_opt)
	var rar_opt := UI.option()
	rar_opt.add_item("Alle Seltenheiten")
	for r in RARITY_ORDER:
		rar_opt.add_item(GameData.rarity_name(r))
	rar_opt.item_selected.connect(func(i: int):
		filter_rarity = "all" if i == 0 else RARITY_ORDER[i - 1]
		_fill_list())
	rar_opt.custom_minimum_size = Vector2(170, 0)
	fr.add_child(rar_opt)
	var sort_opt := UI.option()
	for n in ["Seltenheit", "Stufe", "Name", "Platz"]:
		sort_opt.add_item("Sortiert: " + n)
	sort_opt.item_selected.connect(func(i: int):
		sort_mode = i
		_fill_list())
	sort_opt.custom_minimum_size = Vector2(170, 0)
	fr.add_child(sort_opt)
	_count_label = UI.label("", 15, UI.DIM)
	fr.add_child(_count_label)


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


## Inventarkacheln in ein Raster füllen (gemeinsam für Ausrüstung, Händler und Handel).
func _inventory_grid(parent: Control, items: Array, cols: int, tile: Vector2, on_select: Callable, on_double: Callable) -> void:
	var c := character()
	var grid := GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	parent.add_child(grid)
	for it in items:
		var uid: String = it["uid"]
		var t := ItemTile.make(it, "", tile, _is_equipped(c, uid), uid == selected_uid)
		t.payload = {"uid": uid, "from": "inv"}
		t.pressed.connect(func(): on_select.call(uid))
		t.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.double_click and ev.button_index == MOUSE_BUTTON_LEFT:
				on_double.call(uid))
		grid.add_child(t)


func _fill_list() -> void:
	UI.clear(_list_box)
	var c := character()
	var items := visible_items()
	_count_label.text = "  %d / %d Plätze" % [c["inventory"].size(), SaveSystem.INVENTORY_CAP]
	if items.is_empty():
		_list_box.add_child(UI.label("Keine Gegenstände für diesen Filter.", 15, UI.DIM))
		return
	_inventory_grid(_list_box, items, 4, Vector2(118, 84),
		func(uid: String):
			selected_uid = uid
			_fill_list()
			_fill_slots()
			_fill_detail(),
		func(uid: String):
			selected_uid = uid
			toggle_equip())


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
	return ItemText.stat_line(k, v)


func _fill_detail() -> void:
	UI.clear(_detail)
	var c := character()
	var it := SaveSystem.find_item(c, selected_uid) if selected_uid != "" else {}
	if it.is_empty():
		_detail.add_child(UI.label("Gegenstand wählen", 20, UI.DIM))
		var hl := UI.label("Klicke auf einen Gegenstand oder ziehe ihn auf einen Platz am Charakter. Doppelklick legt an bzw. ab.", 15, UI.DIM)
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(hl)
		return
	_detail_item(_detail, it)
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
		var gl := UI.label("Gesamtwerte: Schaden %.1f → %.1f · Leben %d → %d · Verteidigung %.0f → %.0f" % [before["damage"], after["damage"], before["max_hp"], after["max_hp"], before["defense"], after["defense"]], 14, UI.GOLD)
		gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(gl)
	_detail.add_child(HSeparator.new())
	var eqd := _is_equipped(c, it["uid"])
	_detail.add_child(UI.button("Ablegen" if eqd else "Anlegen (Doppelklick)", func(): toggle_equip(), Vector2(0, 44)))
	_detail.add_child(UI.button("Entsperren" if it.get("locked", false) else "Sperren", func(): toggle_lock(), Vector2(0, 36)))
	var can := Shop.can_sell(c, it)
	var sb := UI.button("Verkaufen (%d Gold)" % Shop.sell_price(it), func(): sell_selected(), Vector2(0, 36))
	sb.disabled = not can
	sb.tooltip_text = "Gesperrte und angelegte Gegenstände können nicht verkauft werden."
	_detail.add_child(sb)
	var db := UI.button("Verwerfen", func(): discard(), Vector2(0, 34))
	db.disabled = not can
	_detail.add_child(db)


## Name, Werte und Text eines Gegenstands (auch vom Händler genutzt).
func _detail_item(box: Control, it: Dictionary) -> void:
	var c := character()
	var col := DataColors.rarity(it["rarity"])
	var nm := UI.label(it["name"], 22, col, true)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(nm)
	if _is_equipped(c, it["uid"]):
		box.add_child(UI.label("✔ ANGELEGT", 15, Color("#5cff9a"), true))
	box.add_child(UI.label("%s · %s · Stufe %d" % [GameData.rarity_name(it["rarity"]), GameData.items_cfg["slots"].get(it["slot"], it["slot"]), it["level"]], 15, UI.DIM))
	if it.has("weapon_type"):
		box.add_child(UI.label("Waffentyp: " + GameData.items_cfg["weapon_types"][it["weapon_type"]]["name"], 15, UI.DIM))
	for k in it["stats"]:
		if k == "flags":
			for f in it["stats"][k]:
				var fl := UI.label("★ " + TalentTree.flag_text(f), 14, UI.GOLD)
				fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				box.add_child(fl)
			continue
		var v: float = float(it["stats"][k])
		box.add_child(UI.label(_stat_line(k, v), 16, UI.RED if v < 0.0 else UI.TEXT))
	if it.get("text", "") != "":
		var t := UI.label(it["text"], 14, UI.GOLD)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(t)
	box.add_child(UI.label("Handelbar: %s" % ("ja" if it.get("tradable", false) and not it.get("locked", false) else "nein"), 14, UI.DIM))


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
		_unequip_uid(selected_uid)
	else:
		SaveSystem.equip(c, selected_uid)
		_after_gear_change()


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
	if not Shop.can_sell(c, it):
		return
	SaveSystem.remove_item(c, selected_uid)
	selected_uid = ""
	SaveSystem.save_game()
	refresh()


func sell_selected() -> void:
	_sell_uid(selected_uid)


func _sell_uid(uid: String) -> void:
	var c := character()
	var it := SaveSystem.find_item(c, uid)
	var nm := str(it.get("name", ""))
	var p := Shop.sell(c, uid)
	if p < 0:
		_say("Dieser Gegenstand kann nicht verkauft werden (gesperrt oder angelegt).")
		return
	if uid == selected_uid:
		selected_uid = ""
	SaveSystem.save_game()
	Sfx.play("loot", 0.8, -6.0)
	_say("%s verkauft für %d Gold." % [nm, p])
	refresh()


# ------------------------------------------------------------------ Tab Händler

func _build_shop() -> void:
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 8)
	_content.add_child(h)
	# Händlerangebot (Drop-Fläche: Gegenstand hierher ziehen = verkaufen)
	var sp := DropZone.new()
	sp.add_theme_stylebox_override("panel", UI.box(Color("#142033"), 10, Color("#2a3a55"), 2, 10))
	sp.custom_minimum_size = Vector2(560, 0)
	sp.drop_check = func(d: Dictionary) -> bool: return d.get("from", "") == "inv" and Shop.can_sell(character(), SaveSystem.find_item(character(), str(d["uid"])))
	sp.drop_do = func(d: Dictionary): _sell_uid(str(d["uid"]))
	h.add_child(sp)
	var ssc := ScrollContainer.new()
	ssc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sp.add_child(ssc)
	_shop_box = VBoxContainer.new()
	_shop_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ssc.add_child(_shop_box)
	# Inventar
	var ip := UI.panel()
	ip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(ip)
	var iv := VBoxContainer.new()
	ip.add_child(iv)
	iv.add_child(UI.label("Dein Inventar", 20, UI.GOLD, true))
	var tip := UI.label("Ziehe einen Gegenstand auf den Händler, um ihn zu verkaufen.", 13, UI.DIM)
	iv.add_child(tip)
	var bulk := UI.button("Alle gewöhnlichen (nicht gesperrt/angelegt) verkaufen", func(): _sell_common(), Vector2(0, 36))
	iv.add_child(bulk)
	iv.add_child(_make_sell_all_button())
	var lsc := ScrollContainer.new()
	lsc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	iv.add_child(lsc)
	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lsc.add_child(_list_box)
	# Details
	var dtp := UI.panel(Vector2(330, 0))
	h.add_child(dtp)
	var dsc := ScrollContainer.new()
	dsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dtp.add_child(dsc)
	_detail = VBoxContainer.new()
	_detail.custom_minimum_size = Vector2(305, 0)
	dsc.add_child(_detail)
	_shop_rot = Shop.rotation_id()
	_fill_shop()


var _sell_all_btns: Array = []
var _sell_all_armed := 0.0


func _sellable_all() -> Array:
	var c := character()
	var out: Array = []
	for it in c["inventory"]:
		if Shop.can_sell(c, it):
			out.append(it)
	return out


func _make_sell_all_button() -> Button:
	_sell_all_btns = _sell_all_btns.filter(func(x): return is_instance_valid(x))
	var b := UI.button("", func(): _sell_all_pressed(), Vector2(0, 38))
	_sell_all_btns.append(b)
	_update_sell_all_text()
	return b


func _update_sell_all_text() -> void:
	var items := _sellable_all()
	var total := 0
	for it in items:
		total += Shop.sell_price(it)
	var armed := _sell_all_armed > 0.0
	for b in _sell_all_btns:
		if is_instance_valid(b):
			b.disabled = items.is_empty()
			b.text = ("Wirklich? %d Gegenstände für %d Gold verkaufen – nochmal klicken" % [items.size(), total]) if armed else ("Alles verkaufen (ohne gesperrte/angelegte): %d Gegenstände, +%d Gold" % [items.size(), total])


func _sell_all_pressed() -> void:
	if _sell_all_armed <= 0.0:
		_sell_all_armed = 4.0
		_update_sell_all_text()
		return
	_sell_all_armed = 0.0
	var c := character()
	var total := 0
	var n := 0
	for it in _sellable_all().duplicate():
		var p := Shop.sell(c, it["uid"])
		if p > 0:
			total += p
			n += 1
	if n > 0:
		SaveSystem.save_game()
		Sfx.play("loot", 0.8, -6.0)
	_say("%d Gegenstände verkauft (+%d Gold). Gesperrte und angelegte bleiben erhalten." % [n, total])
	selected_uid = ""
	refresh()


func _sell_common() -> void:
	var c := character()
	var total := 0
	var n := 0
	for it in c["inventory"].duplicate():
		if it["rarity"] == "common" and Shop.can_sell(c, it):
			var p := Shop.sell(c, it["uid"])
			if p > 0:
				total += p
				n += 1
	if n > 0:
		SaveSystem.save_game()
		Sfx.play("loot", 0.8, -6.0)
	_say("%d gewöhnliche Gegenstände verkauft (+%d Gold)." % [n, total] if n > 0 else "Keine gewöhnlichen Gegenstände zum Verkaufen.")
	selected_uid = ""
	refresh()


func _fill_shop() -> void:
	if _shop_box == null or not is_instance_valid(_shop_box):
		return
	var c := character()
	UI.clear(_shop_box)
	_shop_box.add_child(UI.label("Händler Bram", 22, UI.GOLD, true))
	_timer_label = UI.label("", 14, UI.TEAL)
	_shop_box.add_child(_timer_label)
	_update_timer()
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_shop_box.add_child(grid)
	var st := Shop.stock(c, _shop_rot)
	for e in st:
		var it: Dictionary = e["item"]
		var idx: int = e["idx"]
		var t := ItemTile.make(it, "", Vector2(170, 92), false, selected_shop == idx and selected_uid == "", int(e["price"]))
		t.disabled = false
		if e["sold"]:
			t.modulate = Color(1, 1, 1, 0.35)
			t.tooltip_text = "Verkauft"
		t.pressed.connect(func():
			selected_shop = idx
			selected_uid = ""
			_fill_shop_detail(e)
			_fill_shop())
		t.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.double_click and ev.button_index == MOUSE_BUTTON_LEFT:
				_buy(idx))
		grid.add_child(t)
	UI.clear(_list_box)
	var items: Array = c["inventory"].duplicate()
	items.sort_custom(func(a, b): return RARITY_ORDER.find(a["rarity"]) > RARITY_ORDER.find(b["rarity"]))
	_inventory_grid(_list_box, items, 3, Vector2(150, 80),
		func(uid: String):
			selected_uid = uid
			selected_shop = -1
			_fill_shop_detail({})
			_fill_shop(),
		func(uid: String): _sell_uid(uid))
	if selected_uid != "" or selected_shop < 0:
		_fill_shop_detail({})
	else:
		for e in st:
			if e["idx"] == selected_shop:
				_fill_shop_detail(e)


func _update_timer() -> void:
	if _timer_label != null and is_instance_valid(_timer_label):
		var s := Shop.seconds_left()
		_timer_label.text = "Neues Angebot in %d:%02d Min.  ·  Doppelklick kauft/verkauft" % [s / 60, s % 60]


func _process(delta: float) -> void:
	if _sell_all_armed > 0.0:
		_sell_all_armed -= delta
		if _sell_all_armed <= 0.0:
			_sell_all_armed = 0.0
			_update_sell_all_text()
	_tick += delta
	if tab == "shop" and _tick >= 1.0:
		_tick = 0.0
		if Shop.rotation_id() != _shop_rot:
			var first := _shop_rot < 0
			_shop_rot = Shop.rotation_id()
			selected_shop = -1
			if not first:
				_say("Der Händler hat neue Ware!")
			_fill_shop()
		else:
			_update_timer()


func _fill_shop_detail(entry: Dictionary) -> void:
	UI.clear(_detail)
	var c := character()
	if not entry.is_empty():
		var it: Dictionary = entry["item"]
		_detail_item(_detail, it)
		_detail.add_child(HSeparator.new())
		_detail.add_child(UI.label("Preis: %d Gold" % int(entry["price"]), 18, UI.GOLD, true))
		var eq := equipped_in_slot(c, it["slot"])
		if not eq.is_empty():
			var cmp := Loot.compare(eq, it)
			for k in cmp:
				var d: Dictionary = cmp[k]
				if absf(float(d["diff"])) < 0.0001:
					continue
				var pct: bool = k in GameData.items_cfg["pct_stats"]
				var txt: String = ("%+.1f%%" % (float(d["diff"]) * 100.0)) if pct else ("%+s" % TalentTree._fmt(float(d["diff"])))
				_detail.add_child(UI.label("%s %s gegenüber Angelegtem" % [txt, str(GameData.items_cfg["stat_labels"].get(k, k)).replace(" %", "")], 13, UI.TEAL if float(d["diff"]) > 0.0 else UI.RED))
		var b := UI.button("Kaufen (%d Gold)" % int(entry["price"]), func(): _buy(int(entry["idx"])), Vector2(0, 44))
		b.disabled = bool(entry["sold"]) or int(c.get("gold", 0)) < int(entry["price"])
		_detail.add_child(b)
		return
	var it2 := SaveSystem.find_item(c, selected_uid) if selected_uid != "" else {}
	if it2.is_empty():
		_detail.add_child(UI.label("Händler", 20, UI.DIM))
		var hl := UI.label("Wähle Ware links zum Kaufen oder einen eigenen Gegenstand rechts zum Verkaufen. Das Angebot wechselt alle 20 Minuten.", 15, UI.DIM)
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(hl)
		return
	_detail_item(_detail, it2)
	_detail.add_child(HSeparator.new())
	var sb := UI.button("Verkaufen (%d Gold)" % Shop.sell_price(it2), func(): _sell_uid(selected_uid), Vector2(0, 44))
	sb.disabled = not Shop.can_sell(c, it2)
	_detail.add_child(sb)
	_detail.add_child(UI.button("Entsperren" if it2.get("locked", false) else "Sperren", func():
		it2["locked"] = not it2.get("locked", false)
		SaveSystem.save_game()
		refresh(), Vector2(0, 34)))


func _buy(idx: int) -> void:
	var c := character()
	var err := Shop.buy(c, idx, _shop_rot)
	if err != "":
		_say(err)
		return
	SaveSystem.save_game()
	Sfx.play("rare_loot", 1.0, -8.0)
	_say("Gekauft!")
	refresh()
