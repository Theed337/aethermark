extends Control
## Aethermark-Launcher: prüft beim Start auf die aktuelle Version, bietet den Download an, installiert (entpackt) das Spiel
## neben dem Launcher in den Ordner "Aethermark" und startet es.
## Konfiguration: Datei "launcher.cfg" neben der EXE (Zeile 1 = URL der version.json) überschreibt den Standard.

const DEFAULT_VERSION_URL := "https://raw.githubusercontent.com/Theed337/aethermark/main/dist/version.json"
const GAME_DIR := "Aethermark"
const GAME_EXE := "Aethermark.exe"

var _base_dir := ""
var _version_url := DEFAULT_VERSION_URL
var _installed := ""
var _latest := ""
var _zip_url := ""
var _parts: Array = []   # mehrere Teil-URLs (GitHub erlaubt max. 100 MB je Datei); werden zusammengesetzt
var _part_i := 0
var _notes := ""
var _http: HTTPRequest
var _downloading := false
var _status: Label
var _info: Label
var _notes_label: Label
var _bar: ProgressBar
var _btn_main: Button
var _btn_play: Button
var _btn_quit: Button


func _ready() -> void:
	_base_dir = OS.get_executable_path().get_base_dir()
	if OS.has_feature("editor"):
		_base_dir = ProjectSettings.globalize_path("res://").path_join("_test_install")
		DirAccess.make_dir_recursive_absolute(_base_dir)
	var cfg := _base_dir.path_join("launcher.cfg")
	if FileAccess.file_exists(cfg):
		var u := FileAccess.get_file_as_string(cfg).strip_edges().split("\n")[0].strip_edges()
		if u.begins_with("http"):
			_version_url = u
	_build_ui()
	_installed = _read_installed()
	_refresh_info()
	_check_latest()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#0f1624")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 36
	box.offset_right = -36
	box.offset_top = 28
	box.offset_bottom = -28
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	var title := Label.new()
	title.text = "AETHERMARK"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color("#e8b84a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Label.new()
	sub.text = "3D-Koop-Roguelite · Launcher"
	sub.add_theme_color_override("font_color", Color("#7f93ad"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 18)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_info)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 20)
	_status.add_theme_color_override("font_color", Color("#4ecdc4"))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	_notes_label = Label.new()
	_notes_label.add_theme_color_override("font_color", Color("#9fb0c6"))
	_notes_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notes_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_notes_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_notes_label)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 22)
	_bar.visible = false
	box.add_child(_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	_btn_main = Button.new()
	_btn_main.custom_minimum_size = Vector2(0, 52)
	_btn_main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_main.pressed.connect(_on_main)
	_btn_main.visible = false
	row.add_child(_btn_main)
	_btn_play = Button.new()
	_btn_play.text = "Spielen"
	_btn_play.custom_minimum_size = Vector2(0, 52)
	_btn_play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_play.pressed.connect(_launch)
	_btn_play.visible = false
	row.add_child(_btn_play)
	_btn_quit = Button.new()
	_btn_quit.text = "Beenden"
	_btn_quit.custom_minimum_size = Vector2(120, 52)
	_btn_quit.pressed.connect(func(): get_tree().quit())
	row.add_child(_btn_quit)


func _read_installed() -> String:
	var vf := _base_dir.path_join(GAME_DIR).path_join("version.txt")
	if FileAccess.file_exists(vf) and FileAccess.file_exists(_base_dir.path_join(GAME_DIR).path_join(GAME_EXE)):
		return FileAccess.get_file_as_string(vf).strip_edges()
	return ""


func _refresh_info() -> void:
	_info.text = "Installierte Version: %s" % (_installed if _installed != "" else "— (noch nicht installiert)")
	_btn_play.visible = _installed != ""


func _check_latest() -> void:
	_status.text = "Suche nach Updates …"
	_http = HTTPRequest.new()
	_http.timeout = 10.0
	add_child(_http)
	_http.request_completed.connect(_on_version)
	if _http.request(_version_url) != OK:
		_offline("Update-Prüfung konnte nicht gestartet werden.")


func _on_version(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	_http.request_completed.disconnect(_on_version)
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_offline("Keine Verbindung zum Update-Server (Code %d)." % code)
		return
	var d = JSON.parse_string(body.get_string_from_utf8())
	if not (d is Dictionary) or not d.has("version") or not (d.has("url") or d.has("parts")):
		_offline("Update-Information ist fehlerhaft.")
		return
	_latest = str(d["version"])
	_zip_url = str(d.get("url", ""))
	_parts = d.get("parts", [_zip_url]) if d.has("parts") else [_zip_url]
	_notes = str(d.get("notes", ""))
	_notes_label.text = _notes
	if _installed == "":
		_status.text = "Aethermark %s ist bereit zur Installation." % _latest
		_btn_main.text = "Installieren (Download)"
		_btn_main.visible = true
		if OS.get_environment("LAUNCHER_AUTOINSTALL") != "":
			_on_main()
	elif _is_newer(_latest, _installed):
		_status.text = "Neue Version verfügbar: %s" % _latest
		_btn_main.text = "Update herunterladen"
		_btn_main.visible = true
	else:
		_status.text = "Du hast die aktuelle Version."
		_btn_main.visible = false


func _offline(msg: String) -> void:
	_status.text = msg + ("\nDu kannst trotzdem spielen." if _installed != "" else "\nBitte Internetverbindung prüfen und neu starten.")
	_status.add_theme_color_override("font_color", Color("#e8b84a"))


func _is_newer(a: String, b: String) -> bool:
	var pa := a.split(".")
	var pb := b.split(".")
	for i in 3:
		var x := int(pa[i]) if i < pa.size() else 0
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y:
			return x > y
	return false


func _on_main() -> void:
	if _downloading:
		return
	_downloading = true
	_btn_main.visible = false
	_btn_play.visible = false
	_bar.visible = true
	_bar.value = 0
	_status.text = "Lade Version %s herunter …" % _latest
	_part_i = 0
	_start_part()


func _start_part() -> void:
	var tmp := _base_dir.path_join("download.tmp.part%d" % _part_i)
	_http = HTTPRequest.new()
	_http.download_file = tmp
	_http.timeout = 0.0
	_http.max_redirects = 10
	add_child(_http)
	_http.request_completed.connect(_on_downloaded.bind(tmp))
	if _http.request(str(_parts[_part_i])) != OK:
		_fail("Download konnte nicht gestartet werden.")


var _shot_t := 0.0


func _process(delta: float) -> void:
	if OS.get_environment("LAUNCHER_SHOT") != "":   # Entwicklungs-Hilfe: Screenshot nach 4 s
		_shot_t += delta
		if _shot_t > 4.0:
			get_viewport().get_texture().get_image().save_png(OS.get_environment("LAUNCHER_SHOT"))
			get_tree().quit()
	if _downloading and _http != null:
		var total := _http.get_body_size()
		var got := _http.get_downloaded_bytes()
		if total > 0:
			_bar.value = 100.0 * got / total
			_status.text = "Lade herunter … %.1f / %.1f MB%s" % [got / 1048576.0, total / 1048576.0, ("  (Teil %d/%d)" % [_part_i + 1, _parts.size()]) if _parts.size() > 1 else ""]
		else:
			_bar.value = 0
			_status.text = "Lade herunter … %.1f MB" % (got / 1048576.0)


func _on_downloaded(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray, tmp: String) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_downloading = false
		DirAccess.remove_absolute(tmp)
		_fail("Download fehlgeschlagen (Code %d)." % code)
		return
	_http.queue_free()
	if _part_i + 1 < _parts.size():
		_part_i += 1
		_start_part()
		return
	_downloading = false
	_status.text = "Installiere …"
	_bar.value = 100
	await get_tree().process_frame
	var full := _base_dir.path_join("download.tmp")
	if not _join_parts(full):
		_fail("Teile konnten nicht zusammengesetzt werden.")
		return
	var err := _extract(full)
	DirAccess.remove_absolute(full)
	if err != "":
		_fail(err)
		return
	var vf := FileAccess.open(_base_dir.path_join(GAME_DIR).path_join("version.txt"), FileAccess.WRITE)
	if vf == null:
		_fail("Version konnte nicht gespeichert werden.")
		return
	vf.store_string(_latest)
	vf.close()
	_installed = _latest
	_bar.visible = false
	_refresh_info()
	_status.text = "Fertig! Version %s ist installiert." % _latest
	_status.add_theme_color_override("font_color", Color("#5cff9a"))


func _join_parts(dest: String) -> bool:
	var out := FileAccess.open(dest, FileAccess.WRITE)
	if out == null:
		return false
	for i in _parts.size():
		var pth := _base_dir.path_join("download.tmp.part%d" % i)
		var f := FileAccess.open(pth, FileAccess.READ)
		if f == null:
			return false
		while not f.eof_reached():
			out.store_buffer(f.get_buffer(8 * 1024 * 1024))
		f.close()
		DirAccess.remove_absolute(pth)
	out.close()
	return true


func _extract(zip_path: String) -> String:
	var zr := ZIPReader.new()
	if zr.open(zip_path) != OK:
		return "Die heruntergeladene Datei ist keine gültige ZIP-Datei."
	var target := _base_dir.path_join(GAME_DIR)
	DirAccess.make_dir_recursive_absolute(target)
	for f in zr.get_files():
		var rel := f
		# optional enthaltenen Oberordner "Aethermark/" entfernen
		if rel.begins_with(GAME_DIR + "/"):
			rel = rel.substr(GAME_DIR.length() + 1)
		if rel == "" or rel.ends_with("/"):
			if rel != "":
				DirAccess.make_dir_recursive_absolute(target.path_join(rel))
			continue
		if rel.contains(".."):
			continue
		var out := target.path_join(rel)
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		var fa := FileAccess.open(out, FileAccess.WRITE)
		if fa == null:
			zr.close()
			return "Datei konnte nicht geschrieben werden: %s (läuft das Spiel noch? Bitte schließen und erneut versuchen.)" % rel
		fa.store_buffer(zr.read_file(f))
		fa.close()
	zr.close()
	return ""


func _fail(msg: String) -> void:
	_downloading = false
	_bar.visible = false
	_status.text = msg
	_status.add_theme_color_override("font_color", Color("#ff6a5a"))
	_btn_main.text = "Erneut versuchen"
	_btn_main.visible = true
	_btn_play.visible = _installed != ""


func _launch() -> void:
	var exe := _base_dir.path_join(GAME_DIR).path_join(GAME_EXE)
	if not FileAccess.file_exists(exe):
		_status.text = "Spieldatei nicht gefunden – bitte installieren."
		return
	OS.create_process(exe, [])
	get_tree().quit()
