class_name SettingsApply
extends RefCounted
## Wendet gespeicherte Grafik-/Fenster-Einstellungen an (Qualitätsstufen für PC-Leistungsklassen,
## Grundlage für spätere mobile Profile).

const QUALITY_NAMES := ["Niedrig", "Mittel", "Hoch"]


static func apply_graphics(viewport: Viewport = null) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var s: Dictionary = SaveSystem.data.get("settings", {})
	var q: int = clampi(int(s.get("graphics_quality", 2)), 0, 2)
	var vp: Viewport = viewport if viewport != null else Engine.get_main_loop().root
	var msaa := [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X]
	vp.msaa_3d = msaa[q]
	RenderingServer.directional_shadow_atlas_set_size([1024, 2048, 4096][q], true)
	var win := vp.get_window()
	if win != null:
		var want := Window.MODE_FULLSCREEN if s.get("fullscreen", false) else Window.MODE_WINDOWED
		if win.mode != want:
			win.mode = want
	Engine.max_fps = 0
	vp.get_window().content_scale_factor = clampf(float(s.get("ui_scale", 1.0)), 0.75, 1.75)
