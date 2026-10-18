class_name UpdateCheck
extends Node
## Optionaler, nicht blockierender Update-Hinweis (kein Auto-Updater).
## Lädt eine kleine JSON-Datei {"version": "0.9.1", "url": "https://…", "notes": "…"} von UPDATE_URL.
## Solange UPDATE_URL leer ist (Standard), passiert gar nichts – kein Netzwerkzugriff.
## Einen echten Launcher/Installer braucht das Spiel nicht; siehe docs/BUILD_UND_UPDATE.md.

const UPDATE_URL := "https://raw.githubusercontent.com/Theed337/aethermark/main/dist/version.json"

signal update_available(version: String, url: String, notes: String)


static func current_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


## True, wenn a neuer ist als b (Vergleich Major.Minor.Patch).
static func is_newer(a: String, b: String) -> bool:
	var pa := a.split(".")
	var pb := b.split(".")
	for i in 3:
		var x := int(pa[i]) if i < pa.size() else 0
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y:
			return x > y
	return false


func check() -> void:
	if UPDATE_URL == "":
		return
	var req := HTTPRequest.new()
	req.timeout = 6.0
	add_child(req)
	req.request_completed.connect(func(_r, code, _h, body: PackedByteArray):
		req.queue_free()
		if code != 200:
			return
		var d = JSON.parse_string(body.get_string_from_utf8())
		if d is Dictionary and is_newer(str(d.get("version", "0")), current_version()):
			update_available.emit(str(d["version"]), str(d.get("url", "")), str(d.get("notes", ""))))
	if req.request(UPDATE_URL) != OK:
		req.queue_free()
