class_name MainMenu
extends Node3D
## Hauptmenü: atmosphärische 3D-Szene mit dem eigenen Charakter, Navigation zu allen Bereichen.
## Jede Schaltfläche ist verdrahtet (siehe tests/menu_test.gd, der jede Seite öffnet und Buttons auslöst).

const NARROW_W := 600.0

const PAGE_DEFS := [
	["play", "Spielen", "res://scripts/ui/pages/page_play.gd"],
	["party", "Gruppe & Multiplayer", "res://scripts/ui/pages/page_party.gd"],
	["character", "Charakter", "res://scripts/ui/pages/page_character.gd"],
	["talents", "Talentbaum", "res://scripts/ui/pages/page_talents.gd"],
	["inventory", "Ausrüstung & Inventar", "res://scripts/ui/pages/page_inventory.gd"],
	["collection", "Sammlung & Kosmetik", "res://scripts/ui/pages/page_collection.gd"],
	["world", "Weltkarte", "res://scripts/ui/pages/page_world.gd"],
	["achievements", "Erfolge & Statistiken", "res://scripts/ui/pages/page_achievements.gd"],
	["settings", "Einstellungen", "res://scripts/ui/pages/page_settings.gd"],
	["trade", "Freunde & Handel", "res://scripts/ui/pages/page_trade.gd"],
]

var cam: Camera3D
var pedestal: Node3D
var model: Dictionary = {}
var current := ""
var page: MenuPage = null
var pages: Dictionary = {}
var nav_buttons: Dictionary = {}
var content_holder: PanelContainer
var header_label: Label
var header_sub: Label
var status_label: Label
var creating_new := false
var selected_area := "emerald_forest"
var selected_difficulty := 1
var spin_speed := 0.0
var _rot_drag := false
var _t := 0.0
var _cam_target := Vector3(0, 1.2, 3.4)
var _cam_look := Vector3(0, 1.0, 0)
var preview_appearance: Dictionary = {}
var preview_weapon := "sword"
var preview_gear: Dictionary = {}
var _ui: CanvasLayer
var _root_ui: Control
var _fireflies: Array = []
var _mirrors: Array = []   # {cam, center, normal, right, up, size}


func _ready() -> void:
	SettingsApply.apply_graphics(get_viewport())
	Sfx.apply_volumes()
	_build_scene()
	_build_ui()
	if not SaveSystem.has_character():
		go("character")
	else:
		var c := SaveSystem.active_character()
		Cosmetics.sanitize(c)
		go("play")
	refresh_header()
	# Hinweise auf Handelsanfragen und Gruppenereignisse auch außerhalb der jeweiligen Seite
	Net.trade.request_received.connect(func(from_name: String, _id: int): toast("%s möchte mit dir handeln → Freunde & Handel" % from_name))
	Net.lobby_ended.connect(func(reason: String):
		refresh_header()
		if reason != "":
			toast(reason))
	Net.roster_changed.connect(refresh_header)


# ------------------------------------------------------------------ 3D-Szene

func _build_scene() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#0e1f3a")
	sky_mat.sky_horizon_color = Color("#3d6f78")
	sky_mat.ground_horizon_color = Color("#3d6f78")
	sky_mat.ground_bottom_color = Color("#0c1a1c")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#6f9fb0")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color("#2d5a60")
	env.fog_density = 0.02
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 35, 0)
	key.light_color = Color("#ffe2b8")
	key.light_energy = 1.4
	key.shadow_enabled = OS.get_environment("SHOT_NOSHADOW") == ""
	add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-2.5, 2.5, -2.5)
	rim.light_color = Color("#4ecdc4")
	rim.light_energy = 2.2
	rim.omni_range = 9.0
	add_child(rim)
	# Boden, Sockel und Ruinenbögen
	Toon.part(self, "disc", Vector3(30, 0.4, 0), Color("#2f6b45"), Vector3(0, -0.4, 0))
	pedestal = Node3D.new()
	add_child(pedestal)
	var base := Toon.part(self, "disc", Vector3(1.05, 0.25, 0), Color("#8d9aa5"), Vector3(0, 0.0, 0))
	Toon.outline(base, 0.02)
	Toon.part(self, "disc", Vector3(0.85, 0.08, 0), Color("#4ecdc4"), Vector3(0, 0.15, 0), Vector3.ZERO, Toon.glow_mat(Color("#4ecdc4"), 1.4), false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 26:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(5.0, 17.0)
		var pos := Vector3(cos(ang) * dist, 0, sin(ang) * dist - 2.0)
		var h := rng.randf_range(2.5, 6.5)
		var trunk := Toon.part(self, "cyl", Vector3(0.28, h, 0.36), Color("#5a3b26"), pos + Vector3(0, h * 0.5, 0))
		Toon.outline(trunk, 0.03)
		for k in 3:
			var crown := Toon.part(self, "cone", Vector3(1.5 - k * 0.3, 2.0, 0), Color("#2f8f55").lightened(rng.randf() * 0.15), pos + Vector3(0, h + k * 0.9 - 0.3, 0))
			Toon.outline(crown, 0.03)
	for i in 7:
		var ang := i * TAU / 7.0 + 0.3
		var p := Vector3(cos(ang) * 4.6, 0, sin(ang) * 4.6 - 0.5)
		if false:
			pass
		else:
			var pillar := Toon.part(self, "box", Vector3(0.6, rng.randf_range(1.6, 3.0), 0.6), Color("#9aa7ad"), p + Vector3(0, 0.9, 0), Vector3(0, rad_to_deg(-ang), 0))
			Toon.outline(pillar, 0.025)
	_make_mirror(Vector3(-2.2, 0, -2.4))
	_make_mirror(Vector3(2.2, 0, -2.4))
	# Glühwürmchen
	for i in 40:
		var f := Toon.part(self, "sphere", Vector3(0.035, 0, 0), Color("#f8ff9a"), Vector3.ZERO, Vector3.ZERO, Toon.glow_mat(Color("#f8ff9a"), 3.0), false)
		f.position = Vector3(rng.randf_range(-8, 8), rng.randf_range(0.3, 3.5), rng.randf_range(-9, 3))
		f.set_meta("seed", rng.randf() * 10.0)
		f.set_meta("home", f.position)
		_fireflies.append(f)
	cam = Camera3D.new()
	cam.fov = 45.0
	cam.position = _cam_target
	add_child(cam)
	cam.look_at(_cam_look)
	cam.current = true


const MIRROR_SIZE := Vector2(1.5, 2.6)


## Echter Spiegel: Steinrahmen + Quad, das das Bild einer an der Spiegelebene gespiegelten Kamera (SubViewport) zeigt.
func _make_mirror(p: Vector3) -> void:
	var center := Vector3(0, 1.3, -0.5)
	var pos := p + Vector3(0, MIRROR_SIZE.y * 0.5 + 0.1, 0)
	var n := (Vector3(center.x, pos.y, center.z) - pos).normalized()
	var u := Vector3.UP
	var r := u.cross(n).normalized()
	var basis := Basis(r, u, n)
	var holder := Node3D.new()
	add_child(holder)
	holder.transform = Transform3D(basis, pos)
	# Rahmen (hinter und um den Spiegel)
	var frame := Toon.part(holder, "box", Vector3(MIRROR_SIZE.x + 0.24, MIRROR_SIZE.y + 0.24, 0.12), Color("#7d6a4a"), Vector3(0, 0, -0.08))
	Toon.outline(frame, 0.02)
	Toon.part(holder, "box", Vector3(MIRROR_SIZE.x + 0.5, 0.18, 0.3), Color("#8d9aa5"), Vector3(0, -MIRROR_SIZE.y * 0.5 - 0.2, -0.05))
	var vp := SubViewport.new()
	vp.size = Vector2i(256, 444)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.transparent_bg = false
	add_child(vp)
	var mc := Camera3D.new()
	mc.projection = Camera3D.PROJECTION_FRUSTUM
	mc.keep_aspect = Camera3D.KEEP_HEIGHT
	mc.cull_mask = 1   # Ebene 2 (Spiegel selbst) bleibt unsichtbar
	vp.add_child(mc)
	var quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = MIRROR_SIZE
	quad.mesh = qm
	quad.layers = 2
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/mirror.gdshader")
	mat.set_shader_parameter("refl", vp.get_texture())
	quad.material_override = mat
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(quad)
	_mirrors.append({"cam": mc, "node": holder, "pos": pos, "n": n, "r": r, "u": u})


func _update_mirrors() -> void:
	var hidden := page != null and page.wide
	for m in _mirrors:
		var c: Camera3D = m["cam"]
		(c.get_parent() as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED if hidden else SubViewport.UPDATE_ALWAYS
		if hidden:
			continue
		var n: Vector3 = m["n"]
		var r: Vector3 = m["r"]
		var u: Vector3 = m["u"]
		var pos: Vector3 = m["pos"]
		var d := (cam.global_position - pos).dot(n)
		if d < 0.2:
			continue
		var refl: Vector3 = cam.global_position - 2.0 * d * n
		# Kamera hinter der Spiegelebene, blickt entlang +n, rechts = -r (Spiegelung)
		c.global_transform = Transform3D(Basis(-r, u, -n), refl)
		var rel := pos - refl
		c.size = MIRROR_SIZE.y
		c.frustum_offset = Vector2(-rel.dot(-r), rel.dot(u))
		c.near = d
		c.far = 60.0


func set_preview(appearance: Dictionary, weapon_type: String = "", gear: Variant = null) -> void:
	if gear is Dictionary:
		preview_gear = gear
	preview_appearance = appearance.duplicate(true)
	if weapon_type != "":
		preview_weapon = weapon_type
	var yaw := 0.0
	if not model.is_empty():
		yaw = model["root"].rotation.y
		model["root"].queue_free()
	model = CharacterModel.build(preview_appearance, preview_weapon, preview_gear)
	pedestal.add_child(model["root"])
	model["root"].position = Vector3(0, 0.15, 0)
	model["root"].rotation.y = yaw
	var arms: Array = model["arms"]
	arms[1].rotation.x = -0.35


func show_active_character() -> void:
	var c := SaveSystem.active_character()
	if c.is_empty():
		set_preview(SaveSystem.default_appearance(), "sword", {})
		return
	var w := "sword"
	var eq: Dictionary = c.get("equipment", {})
	if eq.has("weapon"):
		w = SaveSystem.find_item(c, eq["weapon"]).get("weapon_type", "sword")
	set_preview(c["appearance"], w, CharacterModel.gear_looks(c))


## Kamera-Voreinstellungen für den Charaktereditor.
func camera_view(view: String) -> void:
	match view:
		"front":
			_cam_target = Vector3(0, 1.2, 3.4)
			_cam_look = Vector3(0, 0.95, 0)
		"head":
			_cam_target = Vector3(0, 1.75, 1.8)
			_cam_look = Vector3(0, 1.62, 0)
		"far":
			_cam_target = Vector3(0, 1.4, 5.4)
			_cam_look = Vector3(0, 1.0, 0)
		"back":
			_cam_target = Vector3(0, 1.25, 3.6)
			_cam_look = Vector3(0, 1.0, 0)
			if not model.is_empty():
				model["root"].rotation.y = PI
	cam.h_offset = 0.0


func _process(delta: float) -> void:
	_t += delta
	if _toast != null and _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t / 1.0, 0.0, 1.0)
	if not model.is_empty() and not _rot_drag:
		model["root"].rotation.y += delta * spin_speed
	cam.position = cam.position.lerp(_cam_target, clampf(delta * 4.0, 0, 1))
	cam.look_at(_cam_look)
	_update_mirrors()
	# Charakter in die Mitte des freien Bereichs zwischen Navigation und Seitenpanel schieben
	var shift := -0.4 if (page != null and not page.wide) else 0.0
	pedestal.position.x = lerpf(pedestal.position.x, shift, clampf(delta * 5.0, 0, 1))
	pedestal.visible = page == null or not page.wide
	for f in _fireflies:
		var s: float = f.get_meta("seed")
		var h: Vector3 = f.get_meta("home")
		f.position = h + Vector3(sin(_t * 0.7 + s) * 0.6, sin(_t * 1.1 + s * 2.0) * 0.4, cos(_t * 0.6 + s) * 0.6)


func _unhandled_input(event: InputEvent) -> void:
	# Charakter per Maus drehen (links ziehen im freien 3D-Bereich)
	if model.is_empty() or (page != null and page.wide):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_rot_drag = event.pressed
	elif event is InputEventMouseMotion and _rot_drag:
		model["root"].rotation.y += event.relative.x * 0.01


# ------------------------------------------------------------------ UI

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	_root_ui = Control.new()
	_root_ui.theme = UI.theme()
	_root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_root_ui)
	# Navigation links
	var nav_panel := UI.panel(Vector2(260, 0))
	nav_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	nav_panel.offset_left = 16
	nav_panel.offset_top = 16
	nav_panel.offset_bottom = -16
	nav_panel.offset_right = 276
	_root_ui.add_child(nav_panel)
	var nv := VBoxContainer.new()
	nav_panel.add_child(nv)
	var logo := UI.label("AETHERMARK", 30, UI.GOLD, true)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nv.add_child(logo)
	var tag := UI.label("3D-Koop-Roguelite · Alpha", 13, UI.DIM)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nv.add_child(tag)
	header_label = UI.label("", 18, UI.TEXT, true)
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nv.add_child(header_label)
	header_sub = UI.label("", 14, UI.TEAL)
	header_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nv.add_child(header_sub)
	nv.add_child(HSeparator.new())
	for d in PAGE_DEFS:
		var id: String = d[0]
		var b := UI.button(d[1], func(): go(id), Vector2(0, 40))
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		nv.add_child(b)
		nav_buttons[id] = b
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nv.add_child(sp)
	status_label = UI.label("", 13, UI.DIM)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nv.add_child(status_label)
	var ver := UI.label("Version " + UpdateCheck.current_version(), 12, UI.DIM)
	nv.add_child(ver)
	var upd := UpdateCheck.new()
	add_child(upd)
	upd.update_available.connect(func(v: String, url: String, _n: String):
		ver.text = "Update %s verfügbar – %s" % [v, url])
	upd.check()
	nv.add_child(UI.button("Spiel beenden", func(): quit_game(), Vector2(0, 38)))
	# Inhaltsbereich rechts
	content_holder = UI.panel()
	content_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_holder.offset_left = 292
	content_holder.offset_top = 16
	content_holder.offset_right = -16
	content_holder.offset_bottom = -16
	content_holder.clip_contents = true
	content_holder.visible = false
	_root_ui.add_child(content_holder)


var _toast: Label
var _toast_t := 0.0


## Kurze Einblendung unten in der Mitte (Handelsanfragen, Gruppenmeldungen).
func toast(text: String) -> void:
	if _toast == null:
		_toast = UI.label("", 18, UI.GOLD, true)
		_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_toast.position = Vector2(-300, -70)
		_toast.size = Vector2(700, 30)
		_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast.add_theme_constant_override("outline_size", 6)
		_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		_root_ui.add_child(_toast)
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast_t = 5.0


func quit_game() -> void:
	SaveSystem.save_game()
	if has_node("/root/Net"):
		get_node("/root/Net").leave()
	get_tree().quit()


## Öffnet eine Seite. Pro Seite wird die UI bei jedem Öffnen neu aufgebaut (immer aktueller Spielstand).
func go(id: String, keep_new: bool = false) -> void:
	if not keep_new:
		creating_new = false
	if not SaveSystem.has_character() and id != "character":
		id = "character"
	if page != null:
		page.queue_free()
		page = null
	current = id
	for k in nav_buttons:
		nav_buttons[k].set_pressed_no_signal(k == id)
	var def: Array = []
	for d in PAGE_DEFS:
		if d[0] == id:
			def = d
	var script: GDScript = load(def[2])
	var p: MenuPage = script.new()
	p.menu = self
	content_holder.add_child(p)
	page = p
	p.build()
	_wrap_long_labels(p)
	content_holder.visible = true
	if id != "character":
		show_active_character()
		camera_view("front")
	# Schmale Seiten (z. B. Charaktereditor) sitzen rechts, der Charakter bleibt in der Mitte frei sichtbar
	if p.wide:
		content_holder.anchor_left = 0.0
		content_holder.offset_left = 292
	else:
		content_holder.anchor_left = 1.0
		content_holder.offset_left = -NARROW_W - 16
	refresh_header()


## Lange Texte ohne Umbruch würden das Seitenpanel über den Bildschirmrand dehnen -> automatisch umbrechen.
func _wrap_long_labels(n: Node) -> void:
	if n is Label and n.autowrap_mode == TextServer.AUTOWRAP_OFF and n.text.length() > 34 and n.get_parent() is Container:
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		n.custom_minimum_size.x = maxf(n.custom_minimum_size.x, 1.0)
	for c in n.get_children():
		_wrap_long_labels(c)


func refresh_header() -> void:
	var c := SaveSystem.active_character()
	if c.is_empty():
		header_label.text = "Kein Charakter"
		header_sub.text = "Erstelle deinen Helden"
	else:
		header_label.text = c["name"]
		header_sub.text = "%s · Stufe %d · %d Talentpunkte" % [c.get("title", "Wanderer"), c["meta_level"], c["talent_points"]]
	var n := get_node_or_null("/root/Net")
	if n != null and n.in_lobby():
		status_label.text = "Gruppe: %d/5 Spieler" % n.players.size()
	else:
		status_label.text = "Solo – %d/%d Gebiete freigeschaltet" % [c.get("unlocked_areas", []).size(), GameData.areas.size()] if not c.is_empty() else ""
