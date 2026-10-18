class_name PageCollection
extends MenuPage
## Sammlung & Kosmetik: alle kosmetischen Freischaltungen mit Bedingung und Status, Titel auswählen.


func build() -> void:
	var c := character()
	var v := VBoxContainer.new()
	add_child(v)
	var cnt := Cosmetics.count_unlocked(c)
	v.add_child(title("Sammlung & Kosmetik", "Kosmetik wird nur durch Spielen freigeschaltet – nie gekauft. %d von %d freigeschaltet." % [cnt.x, cnt.y]))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(box)
	var kinds := {"outfit": "Kleidung", "hair_style": "Frisuren", "beard": "Bärte", "horns": "Hörner", "tattoo": "Tätowierungen", "title": "Titel"}
	for kind in kinds:
		box.add_child(UI.label(kinds[kind], 19, UI.TEAL, true))
		for e in GameData.cosmetics:
			if e["kind"] != kind:
				continue
			var got := Cosmetics.is_unlocked(c, kind, e["value"])
			var r := HBoxContainer.new()
			var l := UI.label(("✓ " if got else "✗ ") + e["name"], 16, UI.GOLD if got else UI.DIM)
			l.custom_minimum_size = Vector2(300, 0)
			r.add_child(l)
			r.add_child(UI.label("" if got else "Freischalten: " + e["unlock"]["text"], 14, UI.DIM))
			if got and kind == "title":
				var tv: String = e["value"]
				var b := UI.button("Aktiv" if c.get("title", "Wanderer") == tv else "Wählen", Callable(), Vector2(90, 32))
				b.disabled = c.get("title", "Wanderer") == tv
				b.pressed.connect(func():
					c["title"] = tv
					SaveSystem.save_game()
					menu.go("collection"))
				r.add_child(b)
			box.add_child(r)
	box.add_child(HSeparator.new())
	box.add_child(UI.label("Weitere Kosmetik (Emotes, Heimatbasis-Trophäen) ist geplant und noch nicht implementiert.", 14, UI.DIM))
