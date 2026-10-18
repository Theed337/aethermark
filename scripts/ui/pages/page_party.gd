class_name PageParty
extends MenuPage
## Gruppe & Multiplayer: Gruppe erstellen/beitreten (Lobby-Code oder IP), Mitgliederliste mit Bereit-Status und
## Verbindungsanzeige, Gruppenleiter (Ziel, Schwierigkeit, Start, Entfernen), Chat, Verlassen.

static var _history: Array = []   # Chatverlauf bleibt beim Seitenwechsel erhalten

var _root: VBoxContainer
var _built_for_lobby := false
var _roster_box: VBoxContainer
var _chat_log: VBoxContainer
var _chat_scroll: ScrollContainer
var _status: Label
var _addr_edit: LineEdit
var _port_edit: LineEdit
var _start_btn: Button
var _ready_btn: Button
var _area_opt: OptionButton
var _area_ids: Array = []
var _diff_btns: Array = []
var _leader_note: Label


func build() -> void:
	centered = true
	_root = VBoxContainer.new()
	add_child(_root)
	Net.roster_changed.connect(_on_roster)
	Net.chat_received.connect(_on_chat)
	Net.lobby_ended.connect(_on_lobby_ended)
	Net.join_failed.connect(_on_join_failed)
	Net.joined_lobby.connect(_on_joined)
	_rebuild()


func _exit_tree() -> void:
	for pair in [[Net.roster_changed, _on_roster], [Net.chat_received, _on_chat], [Net.lobby_ended, _on_lobby_ended],
			[Net.join_failed, _on_join_failed], [Net.joined_lobby, _on_joined]]:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])


func _rebuild() -> void:
	UI.clear(_root)
	_built_for_lobby = Net.in_lobby()
	_root.add_child(title("Gruppe & Multiplayer", "Bis zu 5 Spieler. Der Host simuliert den Run, alle Treffer, Beute und Fortschritte werden dort geprüft."))
	if Net.in_lobby():
		_build_lobby()
	else:
		_build_offline()
	menu.refresh_header()


# ------------------------------------------------------------------ Offline

func _build_offline() -> void:
	var host_panel := UI.panel()
	_root.add_child(host_panel)
	var hv := VBoxContainer.new()
	host_panel.add_child(hv)
	hv.add_child(UI.label("Gruppe erstellen", 20, UI.GOLD, true))
	var hr := HBoxContainer.new()
	hv.add_child(hr)
	hr.add_child(UI.label("Port", 16, UI.DIM))
	_port_edit = LineEdit.new()
	_port_edit.text = str(Net.DEFAULT_PORT)
	_port_edit.custom_minimum_size = Vector2(110, 0)
	hr.add_child(_port_edit)
	hr.add_child(UI.button("Gruppe erstellen", func(): _create(), Vector2(200, 40)))
	var join_panel := UI.panel()
	_root.add_child(join_panel)
	var jv := VBoxContainer.new()
	join_panel.add_child(jv)
	jv.add_child(UI.label("Einer Gruppe beitreten", 20, UI.GOLD, true))
	_addr_edit = LineEdit.new()
	_addr_edit.placeholder_text = "Lobby-Code (z. B. 7K3QW-9XD2M) oder IP:Port"
	_addr_edit.text = str(SaveSystem.data["settings"].get("last_address", ""))
	jv.add_child(_addr_edit)
	var jr := HBoxContainer.new()
	jv.add_child(jr)
	jr.add_child(UI.button("Beitreten", func(): _join(), Vector2(200, 40)))
	if Net.state == "joining":
		jr.add_child(UI.button("Abbrechen", func():
			Net.leave()
			_rebuild(), Vector2(140, 40)))
	_addr_edit.text_submitted.connect(func(_t): _join())
	_status = UI.label("Verbinde …" if Net.state == "joining" else Net.last_error, 15, UI.TEAL if Net.state == "joining" else UI.RED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_status)
	var hint := UI.label("Im selben Netzwerk (LAN oder VPN wie Tailscale/ZeroTier) funktioniert der Code direkt. Über das Internet muss der Host den UDP-Port %d weiterleiten. Wer ohne Gruppe startet, spielt solo – ein Run funktioniert allein genauso wie mit fünf." % Net.DEFAULT_PORT, 14, UI.DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(hint)


func _create() -> void:
	var port := int(_port_edit.text) if _port_edit.text.is_valid_int() else Net.DEFAULT_PORT
	var err := Net.host_lobby(clampi(port, 1024, 65535))
	if err != OK:
		_status.text = Net.last_error
		_status.add_theme_color_override("font_color", UI.RED)
	# Bei Erfolg löst joined_lobby den Neuaufbau aus


func _join() -> void:
	if Net.state == "joining":
		return
	var err := Net.join_lobby(_addr_edit.text)
	if err == OK:
		_rebuild()
	else:
		_status.text = Net.last_error
		_status.add_theme_color_override("font_color", UI.RED)


# ------------------------------------------------------------------ Lobby

func _build_lobby() -> void:
	var top := UI.panel()
	_root.add_child(top)
	var tv := VBoxContainer.new()
	top.add_child(tv)
	var code_row := HBoxContainer.new()
	tv.add_child(code_row)
	code_row.add_child(UI.label("Lobby-Code:", 17, UI.DIM))
	code_row.add_child(UI.label(Net.lobby_code(), 26, UI.GOLD, true))
	code_row.add_child(UI.button("Kopieren", func(): DisplayServer.clipboard_set(Net.lobby_code()), Vector2(110, 34)))
	tv.add_child(UI.label("%s:%d  ·  %s" % [Net.host_ip, Net.host_port, "Du bist der Host" if Net.is_host() else "Verbunden mit dem Host"], 14, UI.DIM))
	if Net.is_host():
		var lan := HBoxContainer.new()
		tv.add_child(lan)
		lan.add_child(UI.label("Code im selben WLAN/LAN:", 14, UI.DIM))
		lan.add_child(UI.label(Net.lan_code(), 16, UI.TEXT))
		lan.add_child(UI.button("Kopieren", func(): DisplayServer.clipboard_set(Net.lan_code()), Vector2(90, 28)))
		if Net.upnp_status != "":
			var ul := UI.label(Net.upnp_status, 14, UI.TEAL if Net.external_ip != "" else UI.GOLD)
			ul.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ul.custom_minimum_size = Vector2(700, 0)
			tv.add_child(ul)
	_roster_box = VBoxContainer.new()
	_root.add_child(_roster_box)
	# Ziel & Schwierigkeit
	var sp := UI.panel()
	_root.add_child(sp)
	var sv := VBoxContainer.new()
	sp.add_child(sv)
	sv.add_child(UI.label("Ziel & Schwierigkeit", 18, UI.TEAL, true))
	_area_opt = UI.option()
	_area_ids.clear()
	var c := character()
	for a in GameData.areas:
		if a["id"] in c.get("unlocked_areas", []) and a.get("playable", false):
			_area_opt.add_item(a["name"])
			_area_ids.append(a["id"])
	_area_opt.item_selected.connect(func(i: int): Net.set_lobby_settings(_area_ids[i], Net.difficulty))
	sv.add_child(_area_opt)
	var dr := HBoxContainer.new()
	sv.add_child(dr)
	_diff_btns.clear()
	for d in range(1, 5):
		var dd: int = d
		var b := UI.button(Progression.DIFFICULTY_NAMES[d], func(): Net.set_lobby_settings(Net.area_id, dd), Vector2(100, 36))
		b.toggle_mode = true
		b.tooltip_text = Progression.difficulty_text(dd)
		dr.add_child(b)
		_diff_btns.append(b)
	_leader_note = UI.label("", 14, UI.DIM)
	_leader_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sv.add_child(_leader_note)
	# Aktionen
	var ar := HBoxContainer.new()
	_root.add_child(ar)
	_ready_btn = UI.button("Bereit", func(): _toggle_ready(), Vector2(150, 44))
	ar.add_child(_ready_btn)
	_start_btn = UI.button("Run starten", func(): _start(), Vector2(0, 44))
	_start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ar.add_child(_start_btn)
	ar.add_child(UI.button("Gruppe verlassen", func():
		Net.leave()
		_history.clear()
		_rebuild(), Vector2(170, 44)))
	# Chat
	_chat_scroll = ScrollContainer.new()
	_chat_scroll.custom_minimum_size = Vector2(0, 110)
	_chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(_chat_scroll)
	_chat_log = VBoxContainer.new()
	_chat_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_scroll.add_child(_chat_log)
	for line in _history:
		_append_chat(line[0], line[1], false)
	var ci := LineEdit.new()
	ci.placeholder_text = "Nachricht an die Gruppe … (Enter)"
	ci.max_length = 200
	ci.text_submitted.connect(func(t: String):
		Net.send_chat(t)
		ci.clear())
	_root.add_child(ci)
	_fill_roster()


func _fill_roster() -> void:
	if _roster_box == null or not is_instance_valid(_roster_box):
		return
	UI.clear(_roster_box)
	_roster_box.add_child(UI.label("Gruppe (%d/%d)" % [Net.players.size(), Net.MAX_PLAYERS], 18, UI.TEAL, true))
	for p in Net.player_list():
		var id: int = p["id"]
		var row := HBoxContainer.new()
		_roster_box.add_child(row)
		var lead: bool = id == Net.leader_id
		var wname: String = GameData.items_cfg["weapon_types"].get(p.get("weapon", "sword"), {}).get("name", "")
		var nm := UI.label("%s%s%s" % ["♛ " if lead else "", p["name"], "  (du)" if id == Net.my_id() else ""], 17, UI.GOLD if lead else UI.TEXT, true)
		nm.custom_minimum_size = Vector2(210, 0)
		row.add_child(nm)
		var info := UI.label("Stufe %d · %s · Stärke %.2f" % [int(p["level"]), wname, float(p.get("power", 1.0))], 14, UI.DIM)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var connected: bool = p.get("connected", true)
		var st := "Getrennt (Wiederbeitritt möglich)" if not connected else ("Leiter" if lead else ("Bereit ✓" if p.get("ready", false) else "Wartet"))
		row.add_child(UI.label(st, 14, UI.RED if not connected else (UI.TEAL if (lead or p.get("ready", false)) else UI.DIM)))
		if id != Net.my_id() and Net.state == "lobby":
			if Net.is_host():
				var pb := UI.button("♛", func(): Net.promote_leader(id), Vector2(36, 32))
				pb.tooltip_text = "Zum Gruppenleiter machen"
				row.add_child(pb)
			if Net.is_leader() or Net.is_host():
				var kb := UI.button("✕", func(): Net.kick(id), Vector2(36, 32))
				kb.tooltip_text = "Aus der Gruppe entfernen"
				row.add_child(kb)
	_refresh_controls()


func _refresh_controls() -> void:
	if _start_btn == null or not is_instance_valid(_start_btn):
		return
	var leader := Net.is_leader()
	var running := Net.state == "running"
	# Ziel & Schwierigkeit: nur der Leiter darf ändern
	_area_opt.disabled = not leader or running
	var idx := _area_ids.find(Net.area_id)
	if idx >= 0:
		_area_opt.select(idx)
	for i in _diff_btns.size():
		_diff_btns[i].set_pressed_no_signal(Net.difficulty == i + 1)
		_diff_btns[i].disabled = not leader or running or not Progression.difficulty_unlocked(character(), i + 1)
	_leader_note.text = "Du bestimmst Ziel und Schwierigkeit." if leader else "Nur der Gruppenleiter ändert Ziel und Schwierigkeit."
	var me: Dictionary = Net.players.get(Net.my_id(), {})
	_ready_btn.visible = not leader
	_ready_btn.text = "Nicht bereit" if me.get("ready", false) else "Bereit"
	_start_btn.visible = leader
	var all := Net.all_ready()
	_start_btn.disabled = not all or running or Net.players.size() < 1
	_start_btn.text = "Run starten (%d Spieler)" % Net.players.size() if all else "Warten, bis alle bereit sind …"
	if running:
		_start_btn.text = "Run läuft …"


func _toggle_ready() -> void:
	var me: Dictionary = Net.players.get(Net.my_id(), {})
	Net.set_ready(not me.get("ready", false))


func _start() -> void:
	SaveSystem.save_game()
	Net.host_start_run(Net.area_id, Net.difficulty)


func _on_roster() -> void:
	if Net.in_lobby() != _built_for_lobby:
		_rebuild()
	else:
		_fill_roster()


func _on_joined() -> void:
	_rebuild()


func _on_lobby_ended(reason: String) -> void:
	_history.clear()
	_rebuild()
	if _status != null and is_instance_valid(_status) and reason != "":
		_status.text = reason
		_status.add_theme_color_override("font_color", UI.RED)


func _on_join_failed(reason: String) -> void:
	_rebuild()
	if _status != null and is_instance_valid(_status):
		_status.text = reason
		_status.add_theme_color_override("font_color", UI.RED)


func _on_chat(sender: String, text: String) -> void:
	_history.append([sender, text])
	if _history.size() > 80:
		_history.pop_front()
	_append_chat(sender, text, true)


func _append_chat(sender: String, text: String, scroll: bool) -> void:
	if _chat_log == null or not is_instance_valid(_chat_log):
		return
	var l := UI.label("%s: %s" % [sender, text], 14, UI.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chat_log.add_child(l)
	if scroll:
		await get_tree().process_frame
		if is_instance_valid(_chat_scroll):
			_chat_scroll.scroll_vertical = int(_chat_scroll.get_v_scroll_bar().max_value)
