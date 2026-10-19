class_name Boss
extends Enemy
## Der Wurzelwächter: Hauptboss des Smaragdwaldes. Drei Phasen mit wechselnden Anforderungen:
##  Phase 1: Erdschlag (Zielzone) und Wurzelwellen mit Lücken.
##  Phase 2: ruft Sprösslinge und ist geschützt, bis diese besiegt sind.
##  Phase 3: Sporenregen, danach ist der Kern kurz verwundbar (+50 % Schaden).

var phase := 1
var busy := false
var adds: Array = []
var shielded := false
var _barrier: MeshInstance3D
var _core: MeshInstance3D
var _arms: Array = []
var _summoned_phase := 0
var _attack_idx := 0
var _scaling: Dictionary = {}
var announce: Callable = Callable()


## Boss-Parameter aus data/enemies.json ("bosses" -> kit), damit jedes Gebiet eigene Muster bekommt.
static func kit(key: String, default: Variant) -> Variant:
	return GameData.boss.get("kit", {}).get(key, default)


static func spawn_boss(arena_node: Node, pos: Vector3, scaling: Dictionary) -> Boss:
	var b := Boss.new()
	b.arena = arena_node
	b.type_id = "boss"
	b._scaling = scaling
	var bd: Dictionary = GameData.boss
	b.data = {"name": bd["name"], "behavior": "boss", "color": bd["color"], "accent": bd["accent"], "attack_range": 5.0,
			"windup": 1.0, "cooldown": 2.0, "hp": bd["hp"], "damage": bd["damage"], "speed": 2.4, "xp": bd["xp"], "scale": bd["scale"]}
	b.max_hp = float(bd["hp"]) * float(scaling.get("boss_hp_mult", 1.0))
	b.hp = b.max_hp
	b.dmg = float(bd["damage"]) * float(scaling.get("dmg_mult", 1.0))
	b.speed = 2.4
	b.model_scale = float(bd["scale"])
	b.position = pos
	arena_node.add_child(b)
	return b


func _ready() -> void:
	super._ready()
	show_bar = false
	cd = 2.5


func _is_boss() -> bool:
	return true


func display_name() -> String:
	return GameData.boss["name"]


func _build_visual() -> void:
	if GameData.boss.has("mesh") and _build_mesh_monster(GameData.boss):
		_build_barrier()
		return
	var bark := Color(data["color"])
	var leaf := bark.lightened(0.25)
	var ac := Color(data["accent"])
	var v := _visual
	var trunk := Toon.part(v, "cyl", Vector3(0.8, 2.2, 1.0), bark.darkened(0.2), Vector3(0, 1.1, 0))
	Toon.outline(trunk, 0.03)
	for i in 6:
		var ang := i * TAU / 6.0
		Toon.part(v, "box", Vector3(0.18, 1.8, 0.3), bark.darkened(0.35), Vector3(cos(ang) * 0.78, 1.1, sin(ang) * 0.78), Vector3(0, -rad_to_deg(ang), 0))
		Toon.part(v, "cone", Vector3(0.3, 0.9, 0), bark.darkened(0.3), Vector3(cos(ang) * 1.05, 0.25, sin(ang) * 1.05), Vector3(0, 0, -70) if false else Vector3(0, 0, 0))
	var head := Toon.part(v, "sphere", Vector3(0.7, 0.9, 0), bark, Vector3(0, 2.5, 0.1))
	Toon.outline(head, 0.03)
	for sx in [-1, 1]:
		Toon.part(v, "sphere", Vector3(0.14, 0, 0), ac, Vector3(0.26 * sx, 2.58, 0.7), Vector3.ZERO, Toon.glow_mat(ac, 3.0), false)
		var arm := Node3D.new()
		arm.position = Vector3(1.0 * sx, 1.9, 0)
		v.add_child(arm)
		var a1 := Toon.part(arm, "capsule", Vector3(0.28, 1.9, 0), bark, Vector3(0.35 * sx, -0.7, 0), Vector3(0, 0, 15 * sx))
		Toon.outline(a1, 0.03)
		for k in 3:
			Toon.part(arm, "cone", Vector3(0.08, 0.5, 0), bark.darkened(0.3), Vector3(0.6 * sx + (k - 1) * 0.12, -1.7, 0.1 * (k - 1)), Vector3(180, 0, 0))
		_arms.append(arm)
	var form := str(GameData.boss.get("form", "tree"))
	for i in 7:
		var ang := i * TAU / 7.0 + 0.3
		var cp := Vector3(cos(ang) * 0.9, 3.25 + sin(ang * 3) * 0.12, sin(ang) * 0.9)
		match form:
			"crystal", "ice":
				Toon.part(v, "prism", Vector3(0.3, 1.1 + (i % 3) * 0.3, 0.3), ac.lerp(bark, 0.3), cp + Vector3(0, 0.2, 0), Vector3((i % 3) * 8, 0, (i - 3) * 6), Toon.glow_mat(ac, 1.4, 0.9))
			"flame":
				Toon.part(v, "cone", Vector3(0.4, 1.3 + (i % 3) * 0.3, 0), ac, cp + Vector3(0, 0.3, 0), Vector3.ZERO, Toon.glow_mat(ac, 2.4, 0.9))
			"veil":
				Toon.part(v, "cyl", Vector3(0.55, 0.05, 0.55), ac.lerp(Color.WHITE, 0.3), cp + Vector3(0, 0.2, 0), Vector3(90, rad_to_deg(ang), 0), Toon.glow_mat(ac, 1.6, 0.75))
			"wing":
				Toon.part(v, "box", Vector3(0.12, 1.5, 0.45), leaf, cp + Vector3(0, 0.1, 0), Vector3(0, rad_to_deg(ang), 25))
			_:
				Toon.part(v, "sphere", Vector3(0.75, 0.8, 0), leaf.lerp(bark, randf() * 0.3), cp)
	if form == "tree":
		Toon.part(v, "sphere", Vector3(1.0, 0.75, 0), leaf, Vector3(0, 3.55, 0))
	else:
		Toon.part(v, "prism", Vector3(0.5, 1.4, 0.5), ac, Vector3(0, 3.7, 0), Vector3.ZERO, Toon.glow_mat(ac, 2.0, 0.9))
		if form == "wing":
			for sx in [-1, 1]:
				Toon.part(v, "box", Vector3(0.1, 2.4, 1.6), leaf.lightened(0.15), Vector3(1.6 * sx, 2.6, -0.5), Vector3(0, 0, 55 * sx), Toon.glow_mat(ac, 0.6, 0.85))
	_core = Toon.part(v, "sphere", Vector3(0.3, 0, 0), ac, Vector3(0, 1.5, 0.82), Vector3.ZERO, Toon.glow_mat(ac, 2.5, 0.95), false)
	_build_barrier()
	for n in v.find_children("*", "MeshInstance3D", true, false):
		var m: Material = n.material_override
		if m is ShaderMaterial and m.shader == Toon.shader() and n != _barrier:
			var dup: ShaderMaterial = m.duplicate()
			n.material_override = dup
			_mats.append(dup)


func _build_barrier() -> void:
	_barrier = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 2.2
	sm.height = 4.4
	_barrier.mesh = sm
	_barrier.material_override = Toon.glow_mat(Color(data["accent"]), 1.0, 0.28)
	_barrier.position = Vector3(0, 1.8, 0)
	_barrier.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_barrier.visible = false
	_visual.add_child(_barrier)


func _build_elite_aura() -> void:
	pass


func net_flags() -> int:
	var f := super.net_flags()
	if shielded:
		f |= 1
	if dmg_taken_mult > 1.2:
		f |= 8
	return f


func apply_net_flags(flags: int) -> void:
	super.apply_net_flags(flags)
	shielded = (flags & 1) != 0
	if _barrier != null:
		_barrier.visible = shielded
	if _core != null:
		_core.scale = Vector3.ONE * (1.6 if (flags & 8) != 0 else 1.0)


# ------------------------------------------------------------------ KI

func _ai(delta: float, player: Node3D) -> Vector3:
	var to_p: Vector3 = player.global_position - global_position
	to_p.y = 0.0
	var dist := to_p.length()
	var dir := to_p / maxf(dist, 0.001)
	_update_phase()
	if busy:
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 0.05)
		return Vector3.ZERO
	_face(dir, delta)
	if cd <= 0.0:
		_next_attack(player)
		return Vector3.ZERO
	if dist > 9.0:
		return dir * speed
	return Vector3.ZERO


func _update_phase() -> void:
	var r := hp / max_hp
	var np := 1 if r > 0.66 else (2 if r > 0.33 else 3)
	if np != phase:
		phase = np
		if announce.is_valid():
			announce.call("Phase %d" % phase)
		FX.ring(arena, global_position, 12.0, Color(data["accent"]), 0.8, 0.08)
		Sfx.play("boss", 1.0, -2.0)
		_cancel_telegraph()
	# Barriere nur sichtbar solange Sprösslinge leben
	adds = adds.filter(func(a): return is_instance_valid(a) and not a.dead)
	if shielded and adds.is_empty():
		shielded = false
		shield_mult = 1.0
		_barrier.visible = false
		if announce.is_valid():
			announce.call("Der Schutz ist gebrochen!")
		FX.burst(arena, global_position + Vector3(0, 2, 0), Color("#8fe86a"), 24, 8.0, 0.2, 0.7)


func _next_attack(player: Node3D) -> void:
	if phase >= 2 and _summoned_phase < phase and adds.is_empty():
		_summoned_phase = phase
		_do_summon()
		return
	_attack_idx += 1
	if bool(kit("line", false)) and _attack_idx % 4 == 1:
		_do_line(player)
	elif phase == 3 and _attack_idx % 3 == 0:
		_do_spore_rain(player)
	elif _attack_idx % 2 == 0:
		_do_roots()
	else:
		_do_slam(player)


func _wait(t: float) -> bool:
	## true = weiter, false = Gegner tot (Coroutine abbrechen)
	await get_tree().create_timer(t, false).timeout
	return not dead and is_inside_tree()


func _raise_arms(up: bool) -> void:
	for a in _arms:
		var tw := create_tween()
		tw.tween_property(a, "rotation:z", (-2.4 if a.position.x > 0 else 2.4) if up else 0.0, 0.35)


func _hit_circle(center: Vector3, r: float, mult: float = 1.0) -> void:
	FX.ring(arena, center, r, Color(data["accent"]).lightened(0.2), 0.35)
	FX.burst(arena, center + Vector3(0, 0.3, 0), Color("#8a6a3a"), 16, 6.0, 0.18, 0.6)
	Sfx.play("boom", 0.8, -4.0)
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p) or p.is_down():
			continue
		var d: Vector3 = p.global_position - center
		d.y = 0.0
		if d.length() <= r + 0.4:
			p.take_damage(dmg * mult, center)


func _do_slam(player: Node3D) -> void:
	busy = true
	var windup := 1.15 if phase < 3 else 0.85
	var r := float(kit("slam_r", 4.4))
	var count := int(kit("slam_count", 1)) + (1 if phase == 3 and int(kit("slam_count", 1)) > 1 else 0)
	for k in count:
		var target := player.global_position
		var tele := FX.telegraph(arena, target, r, windup)
		_telegraph = tele
		_raise_arms(true)
		_flash = 0.4
		if not await _wait(windup):
			return
		if is_instance_valid(tele):
			tele.queue_free()
		_raise_arms(false)
		_hit_circle(target, r, 1.2)
		if k < count - 1 and not await _wait(0.25):
			return
	busy = false
	cd = 1.8 if phase < 3 else 1.2


func _do_roots() -> void:
	busy = true
	_raise_arms(true)
	var waves := int(kit("waves", 3))
	var teles: Array = []
	for w in waves:
		var radius := 5.0 + w * 3.6
		var n := 10 + w * 3
		var gap := randf() * TAU
		for k in n:
			var ang := k * TAU / n
			if absf(wrapf(ang - gap, -PI, PI)) < 0.45:
				continue      # sichere Lücke
			var pos := global_position + Vector3(cos(ang), 0, sin(ang)) * radius
			teles.append([w, pos, FX.telegraph(arena, pos, 1.5, 0.9 + w * 0.5)])
	if not await _wait(0.9):
		return
	for w in waves:
		for t in teles:
			if t[0] == w:
				if is_instance_valid(t[2]):
					t[2].queue_free()
				_hit_circle(t[1], 1.5, 0.8)
		if w < waves - 1:
			if not await _wait(0.5):
				return
	_raise_arms(false)
	busy = false
	cd = 2.2 if phase < 3 else 1.5


func _do_summon() -> void:
	busy = true
	_raise_arms(true)
	if announce.is_valid():
		announce.call(str(kit("summon_text", "%s ruft Sprösslinge!")) % display_name())
	if not await _wait(0.8):
		return
	var n := 2 * int(_scaling.get("boss_adds", 1)) + 1
	for i in n:
		var ang := i * TAU / n
		var pos := global_position + Vector3(cos(ang), 0, sin(ang)) * 5.0
		var e := Enemy.spawn(arena, str(kit("add_type", "grunt")), pos, _scaling)
		e.max_hp *= 0.8
		e.hp = e.max_hp
		adds.append(e)
		if arena.has_method("register_enemy"):
			arena.register_enemy(e)
		FX.burst(arena, pos + Vector3(0, 0.5, 0), Color("#8fe86a"), 10, 4.0)
	shielded = true
	shield_mult = 0.12
	_barrier.visible = true
	_raise_arms(false)
	busy = false
	cd = 2.0


func _do_spore_rain(player: Node3D) -> void:
	busy = true
	_raise_arms(true)
	if announce.is_valid():
		announce.call(str(kit("rain_text", "Sporenregen!")))
	for i in int(kit("rain_n", 7)):
		var off := Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
		var pos: Vector3 = player.global_position + off * (0.3 if i % 2 == 0 else 1.0)
		var tele := FX.telegraph(arena, pos, 1.9, 1.0, Color("#b4ff5a"))
		_spore_hit(tele, pos)
		if not await _wait(0.5):
			return
	if not await _wait(1.2):
		return
	_raise_arms(false)
	# Erschöpft: Kern liegt offen (taktisches Fenster)
	dmg_taken_mult = 1.5
	if announce.is_valid():
		announce.call("Der Kern liegt offen – jetzt angreifen!")
	if _core != null:
		_core.scale = Vector3.ONE * 1.6
	busy = false
	cd = 3.5
	if not await _wait(3.5):
		return
	dmg_taken_mult = 1.0
	if _core != null:
		_core.scale = Vector3.ONE


## Linienangriff: markiert eine Schneise zum Ziel, danach stürmt der Boss hindurch.
func _do_line(player: Node3D) -> void:
	busy = true
	_raise_arms(true)
	var from := global_position
	var to: Vector3 = player.global_position
	var dir := to - from
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.1 else Vector3.FORWARD
	if announce.is_valid():
		announce.call(str(kit("line_text", "Ansturm!")))
	var teles: Array = []
	var pts: Array = []
	for i in 6:
		var pos := from + dir * (3.0 + i * 2.6)
		pts.append(pos)
		teles.append(FX.telegraph(arena, pos, 2.0, 1.1, Color(data["accent"])))
	if not await _wait(1.1):
		return
	for t in teles:
		if is_instance_valid(t):
			t.queue_free()
	var end: Vector3 = pts[pts.size() - 1]
	var tw := create_tween()
	tw.tween_property(self, "global_position", Vector3(end.x, global_position.y, end.z), 0.35)
	for pt in pts:
		_hit_circle(pt, 2.0, 1.0)
	_raise_arms(false)
	busy = false
	cd = 2.0


func _spore_hit(tele: Node3D, pos: Vector3) -> void:
	await get_tree().create_timer(1.0, false).timeout
	if is_instance_valid(tele):
		tele.queue_free()
	if not dead:
		_hit_circle(pos, 1.9, 0.9)


func die(killed_by_player: bool, silent_explosion: bool = false) -> void:
	if ghost:
		super.die(killed_by_player, silent_explosion)
		return
	for a in adds:
		if is_instance_valid(a) and not a.dead:
			a.die(false)
	adds.clear()
	if announce.is_valid():
		announce.call("%s ist gefallen!" % display_name())
	super.die(killed_by_player, silent_explosion)
