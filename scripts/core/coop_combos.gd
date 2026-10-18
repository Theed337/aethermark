class_name CoopCombos
extends RefCounted
## Koop-Elementkombos: Treffen zwei verschiedene Spieler denselben Gegner mit passenden Elementen
## (innerhalb weniger Sekunden), löst eine Reaktion aus. Läuft nur beim Host/Solo-Spieler (dort steht die Schadenslogik).

const WINDOW := 4.0
const ELEMENTS := ["fire", "frost", "lightning", "earth"]

## Schlüssel = sortierte Elementpaare.
const COMBOS := {
	"fire+frost": {"name": "Dampfexplosion", "radius": 3.2, "mult": 1.4, "color": "#e0f0ff"},
	"frost+lightning": {"name": "Schockfrost", "radius": 3.5, "mult": 0.8, "stun": 1.5, "color": "#9fe8ff"},
	"earth+fire": {"name": "Magmaeruption", "radius": 3.5, "mult": 1.0, "burn": 4.0, "color": "#ff8a3a"},
	"fire+lightning": {"name": "Überladung", "radius": 4.0, "mult": 1.8, "color": "#ffe066"},
	"earth+lightning": {"name": "Erdung", "radius": 3.0, "mult": 1.0, "stun": 0.8, "color": "#c0a070"},
}


static func combo_key(a: String, b: String) -> String:
	var arr := [a, b]
	arr.sort()
	return "%s+%s" % arr


## Aufruf nach jedem Spielertreffer. dealt = verursachter Schaden dieses Treffers.
static func on_hit(p: Node, e: Node, tags: Array, dealt: float) -> void:
	if e == null or not is_instance_valid(e) or e.dead:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var hits: Dictionary = e.elem_hits
	var fired := false
	for t in tags:
		if not (t in ELEMENTS):
			continue
		if not fired and now >= e.combo_cd:
			for o in hits:
				if o == t:
					continue
				var rec: Array = hits[o]     # [Spieler, Zeit]
				if rec[0] != p and is_instance_valid(rec[0]) and now - float(rec[1]) <= WINDOW:
					_fire(p, rec[0], e, combo_key(t, o), dealt)
					e.combo_cd = now + 1.5
					hits.erase(o)
					fired = true
					break
		hits[t] = [p, now]


static func _fire(p: Node, other: Node, e: Node, key: String, dealt: float) -> void:
	if not COMBOS.has(key):
		return
	var c: Dictionary = COMBOS[key]
	var arena: Node = e.arena
	var pos: Vector3 = e.global_position
	var dmg := maxf(dealt, 20.0) * float(c["mult"]) + 12.0
	FX.ring(arena, pos, float(c["radius"]), Color(c["color"]), 0.5)
	FX.burst(arena, pos + Vector3(0, 1, 0), Color(c["color"]), 18, 6.0, 0.18, 0.6)
	FX.float_text(arena, pos + Vector3(0, 2.2, 0), "%s!" % c["name"], Color(c["color"]), 46)
	Sfx.play("boom", 1.1, -5.0)
	for o in e.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(o) or o.dead:
			continue
		if o.global_position.distance_to(pos) <= float(c["radius"]):
			o.last_hit_by = p
			var dealt_aoe: float = o.take_damage(dmg, false, pos, 3.0)
			p.run_stats["damage_dealt"] += dealt_aoe
			if c.has("stun"):
				o.apply_stun(float(c["stun"]))
			if c.has("burn"):
				o.apply_burn(float(c["burn"]), 10.0)
	for pl in [p, other]:
		if is_instance_valid(pl):
			pl.run_stats["combos"] = int(pl.run_stats.get("combos", 0)) + 1
