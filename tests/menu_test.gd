extends Node
## Öffnet jede Seite des Hauptmenüs und löst die wichtigsten Schaltflächen aus.
## Start:  godot --headless --path . res://tests/menu_test.tscn      Exit-Code 0 = bestanden.

var ok := true
var menu: MainMenu


func check(c: bool, msg: String) -> void:
	if c:
		print("  OK     ", msg)
	else:
		ok = false
		printerr("  FEHLER ", msg)


func _ready() -> void:
	Net.use_upnp = false
	SaveSystem.save_path = "user://menu_test_save.json"
	for suf in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists("user://menu_test_save.json" + suf):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://menu_test_save.json" + suf))
	SaveSystem.data = SaveSystem.default_data()
	menu = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	check(menu.current == "character", "Ohne Charakter öffnet das Menü den Charaktereditor")
	var c := SaveSystem.new_character("Menütester", SaveSystem.default_appearance())
	for d in MainMenu.PAGE_DEFS:
		menu.go(d[0])
		await get_tree().process_frame
		check(menu.page != null and is_instance_valid(menu.page) and menu.current == d[0], "Seite öffnet: %s" % d[1])
		menu.page.refresh()
	# Gruppenmenü: Lobby erstellen und wieder verlassen (Ein-Personen-Gruppe)
	menu.go("party")
	await get_tree().process_frame
	var err := Net.host_lobby(24999)
	check(err == OK, "Lobby lässt sich erstellen")
	await get_tree().process_frame
	check(Net.in_lobby() and Net.players.size() == 1 and Net.lobby_code().length() == 11, "Lobby-Code erzeugt: %s" % Net.lobby_code())
	var parsed := Net.parse_target(Net.lobby_code())
	check(not parsed.is_empty() and parsed["port"] == 24999, "Lobby-Code lässt sich wieder auflösen (%s)" % str(parsed))
	menu.go("play")
	await get_tree().process_frame
	check(menu.page._start_btn.text.begins_with("GRUPPEN-RUN"), "Spielen-Seite zeigt Gruppen-Start")
	menu.go("trade")
	await get_tree().process_frame
	Net.leave()
	await get_tree().process_frame
	check(not Net.in_lobby(), "Gruppe lässt sich verlassen")
	# Freunde speichern
	menu.go("trade")
	await get_tree().process_frame
	menu.page._name_edit.text = "Freundin"
	menu.page._code_edit.text = "192.168.1.20:24680"
	menu.page._add_friend()
	check(SaveSystem.data["settings"]["friends"].size() == 1, "Freund wird gespeichert")
	print("")
	print("Menü-Test: ", "BESTANDEN" if ok else "FEHLGESCHLAGEN")
	get_tree().quit(0 if ok else 1)
