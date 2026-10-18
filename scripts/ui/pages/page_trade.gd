class_name PageTrade
extends MenuPage
## Freunde & Handel. Links: gespeicherte Freunde (Name + Lobby-Adresse zum schnellen Beitreten).
## Rechts: sicherer Direkthandel mit Gruppenmitgliedern in der Lobby. Ablauf: Anfrage -> Annahme -> beide legen Angebote
## ein -> beide prüfen die vollständigen Werte -> beide bestätigen -> der Host schließt atomar ab. Jede Änderung eines
## Angebots hebt beide Bestätigungen auf. Nur handelbare, nicht gesperrte, nicht angelegte Gegenstände sind wählbar.

var _friends_box: VBoxContainer
var _trade_box: VBoxContainer
var _msg: Label
var _selected: Dictionary = {}    # uid -> true (eigenes Angebot, lokaler Spiegel)
var _last_trade_id := -1
var _name_edit: LineEdit
var _code_edit: LineEdit


func _init() -> void:
	wide = true


func build() -> void:
	var v := VBoxContainer.new()
	add_child(v)
	v.add_child(title("Freunde & Handel", "Tausche Ausrüstung sicher mit deiner Gruppe. Handel funktioniert ohne Echtgeld und ohne Zufallsmechaniken."))
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(h)
	var fp := UI.panel(Vector2(330, 0))
	h.add_child(fp)
	_friends_box = VBoxContainer.new()
	_friends_box.custom_minimum_size = Vector2(305, 0)
	fp.add_child(_friends_box)
	var tp := UI.panel()
	tp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tp)
	var tsc := ScrollContainer.new()
	tsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tp.add_child(tsc)
	_trade_box = VBoxContainer.new()
	_trade_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tsc.add_child(_trade_box)
	_msg = UI.label("", 15, UI.TEAL)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_msg)
	Net.trade.state_changed.connect(_on_state)
	Net.trade.message.connect(_on_msg)
	Net.roster_changed.connect(_refresh_trade)
	Net.lobby_ended.connect(_on_lobby_ended)
	_fill_friends()
	_refresh_trade()


func _exit_tree() -> void:
	for pair in [[Net.trade.state_changed, _on_state], [Net.trade.message, _on_msg], [Net.roster_changed, _refresh_trade], [Net.lobby_ended, _on_lobby_ended]]:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])


# ------------------------------------------------------------------ Freunde

func _friends() -> Array:
	return SaveSystem.data["settings"]["friends"]


func _fill_friends() -> void:
	UI.clear(_friends_box)
	_friends_box.add_child(UI.label("Freunde", 22, UI.GOLD, true))
	var hint := UI.label("Speichere Namen und Lobby-Code (oder IP:Port) deiner Freunde, um schnell beizutreten.", 13, UI.DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_friends_box.add_child(hint)
	var fr: Array = _friends()
	if fr.is_empty():
		_friends_box.add_child(UI.label("Noch keine Freunde gespeichert.", 15, UI.DIM))
	for i in fr.size():
		var f: Dictionary = fr[i]
		var row := HBoxContainer.new()
		_friends_box.add_child(row)
		var l := UI.label("%s\n%s" % [f["name"], f["code"]], 14)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var idx := i
		var jb := UI.button("Beitreten", func():
			var err := Net.join_lobby(f["code"])
			_say("Verbinde mit %s …" % f["name"] if err == OK else Net.last_error), Vector2(0, 34))
		jb.disabled = Net.in_lobby() or Net.state == "joining"
		row.add_child(jb)
		row.add_child(UI.button("✕", func():
			_friends().remove_at(idx)
			SaveSystem.save_game()
			_fill_friends(), Vector2(34, 34)))
	_friends_box.add_child(HSeparator.new())
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Name des Freundes"
	_name_edit.max_length = 16
	_friends_box.add_child(_name_edit)
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "Lobby-Code oder IP:Port"
	_friends_box.add_child(_code_edit)
	_friends_box.add_child(UI.button("Freund speichern", func(): _add_friend(), Vector2(0, 38)))
	if Net.in_lobby():
		_friends_box.add_child(UI.button("Aktuelle Gruppe merken", func():
			_friends().append({"name": "Gruppe von %s" % Net.players.get(Net.leader_id, {}).get("name", "?"), "code": Net.lobby_code()})
			SaveSystem.save_game()
			_fill_friends(), Vector2(0, 38)))


func _add_friend() -> void:
	var nm := _name_edit.text.strip_edges()
	var code := _code_edit.text.strip_edges()
	if SaveSystem.validate_name(nm) != "":
		_say(SaveSystem.validate_name(nm))
		return
	if Net.parse_target(code).is_empty():
		_say("Ungültiger Lobby-Code oder ungültige Adresse.")
		return
	for f in _friends():
		if f["name"] == nm:
			f["code"] = code
			SaveSystem.save_game()
			_fill_friends()
			return
	if _friends().size() >= 30:
		_say("Du kannst höchstens 30 Freunde speichern.")
		return
	_friends().append({"name": nm, "code": code})
	SaveSystem.save_game()
	_fill_friends()


# ------------------------------------------------------------------ Handel

func _say(t: String) -> void:
	if _msg != null and is_instance_valid(_msg):
		_msg.text = t


func _on_msg(t: String) -> void:
	_say(t)
	menu.refresh_header()


func _on_lobby_ended(_reason: String) -> void:
	_fill_friends()
	_refresh_trade()


func _on_state(_snap: Dictionary) -> void:
	_refresh_trade()


func _refresh_trade() -> void:
	if _trade_box == null or not is_instance_valid(_trade_box):
		return
	UI.clear(_trade_box)
	_trade_box.add_child(UI.label("Handel", 22, UI.GOLD, true))
	var cur: Dictionary = Net.trade.current
	if cur.is_empty():
		_selected.clear()
		_last_trade_id = -1
		_build_idle()
	elif cur["status"] == "requested":
		_build_request(cur)
	else:
		if cur["id"] != _last_trade_id:
			_selected.clear()
			_last_trade_id = cur["id"]
		_build_open(cur)


func _build_idle() -> void:
	if not Net.in_lobby():
		var l := UI.label("Handel ist nur in einer Gruppe möglich. Erstelle oder betrete im Menü „Gruppe & Multiplayer“ eine Lobby.", 16, UI.DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_trade_box.add_child(l)
		return
	if Net.state != "lobby":
		_trade_box.add_child(UI.label("Während eines Runs ist kein Handel möglich.", 16, UI.DIM))
		return
	_trade_box.add_child(UI.label("Wähle ein Gruppenmitglied:", 16, UI.TEXT))
	var any := false
	for p in Net.player_list():
		if p["id"] == Net.my_id():
			continue
		any = true
		var row := HBoxContainer.new()
		_trade_box.add_child(row)
		var l := UI.label("%s  (Stufe %d)" % [p["name"], int(p["level"])], 17)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var pid: int = p["id"]
		var b := UI.button("Handel anfragen", func():
			Net.trade.request_trade(pid)
			_say("Anfrage gesendet."), Vector2(180, 38))
		b.disabled = not p.get("connected", true)
		row.add_child(b)
	if not any:
		_trade_box.add_child(UI.label("Du bist allein in der Gruppe.", 15, UI.DIM))


func _build_request(cur: Dictionary) -> void:
	var me: String = cur["me"]
	var other: Dictionary = cur["b" if me == "a" else "a"]
	if me == "b":
		_trade_box.add_child(UI.label("%s möchte mit dir handeln." % other["name"], 18, UI.TEXT))
		var row := HBoxContainer.new()
		_trade_box.add_child(row)
		row.add_child(UI.button("Annehmen", func(): Net.trade.answer(cur["id"], true), Vector2(160, 42)))
		row.add_child(UI.button("Ablehnen", func(): Net.trade.answer(cur["id"], false), Vector2(160, 42)))
	else:
		_trade_box.add_child(UI.label("Warte auf die Antwort von %s …" % other["name"], 18, UI.TEXT))
		_trade_box.add_child(UI.button("Abbrechen", func(): Net.trade.cancel(), Vector2(160, 42)))


func _build_open(cur: Dictionary) -> void:
	var me: String = cur["me"]
	var mine: Dictionary = cur[me]
	var theirs: Dictionary = cur["b" if me == "a" else "a"]
	_trade_box.add_child(UI.label("Handel mit %s" % theirs["name"], 18, UI.TEAL, true))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	_trade_box.add_child(cols)
	# Eigenes Angebot (Auswahl aus dem Inventar)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	left.add_child(UI.label("Dein Angebot (%d/%d)" % [mine["offer"].size(), TradeLedger.MAX_ITEMS], 17, UI.GOLD, true))
	var c := character()
	var shown := 0
	for it in c["inventory"]:
		if not ItemText.tradable_now(c, it):
			continue
		shown += 1
		var uid: String = it["uid"]
		var b := Button.new()
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.custom_minimum_size = Vector2(0, 36)
		b.text = "%s  [Stufe %d]" % [it["name"], int(it["level"])]
		b.add_theme_color_override("font_color", DataColors.rarity(it["rarity"]))
		b.tooltip_text = "\n".join(ItemText.lines(it))
		b.set_pressed_no_signal(_selected.has(uid))
		b.toggled.connect(func(on: bool):
			if on:
				_selected[uid] = true
			else:
				_selected.erase(uid)
			_send_offer())
		left.add_child(b)
	if shown == 0:
		var nl := UI.label("Keine handelbaren Gegenstände (angelegte, gesperrte und gebundene bleiben bei dir).", 14, UI.DIM)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		left.add_child(nl)
	# Angebot des Partners mit allen Werten
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(UI.label("Angebot von %s" % theirs["name"], 17, UI.GOLD, true))
	if theirs["offer"].is_empty():
		right.add_child(UI.label("Noch nichts angeboten.", 14, UI.DIM))
	for it in theirs["offer"]:
		var card := UI.panel()
		right.add_child(card)
		var cv := VBoxContainer.new()
		card.add_child(cv)
		cv.add_child(UI.label(it["name"], 16, DataColors.rarity(it["rarity"]), true))
		for line in ItemText.lines(it):
			var ll := UI.label(line, 13, UI.TEXT)
			ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cv.add_child(ll)
	# Bestätigung
	_trade_box.add_child(HSeparator.new())
	var st := UI.label("Du: %s   ·   %s: %s" % ["bestätigt ✓" if mine["confirmed"] else "noch nicht bestätigt", theirs["name"], "bestätigt ✓" if theirs["confirmed"] else "noch nicht bestätigt"], 15, UI.DIM)
	_trade_box.add_child(st)
	var ar := HBoxContainer.new()
	_trade_box.add_child(ar)
	var cb := UI.button("Bestätigung zurücknehmen" if mine["confirmed"] else "Handel bestätigen", func(): Net.trade.confirm(not mine["confirmed"]), Vector2(240, 44))
	cb.disabled = mine["offer"].is_empty() and theirs["offer"].is_empty()
	ar.add_child(cb)
	ar.add_child(UI.button("Handel abbrechen", func(): Net.trade.cancel(), Vector2(200, 44)))
	var note := UI.label("Prüfe die Werte beider Angebote genau. Ändert jemand sein Angebot, müssen beide neu bestätigen.", 13, UI.DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trade_box.add_child(note)


func _send_offer() -> void:
	var c := character()
	var items: Array = []
	for it in c["inventory"]:
		if _selected.has(it["uid"]) and ItemText.tradable_now(c, it):
			items.append(it.duplicate(true))
	Net.trade.set_offer(items)
