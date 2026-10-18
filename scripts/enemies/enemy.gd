class_name Enemy
extends CharacterBody3D
## Gegner mit vier Verhaltensweisen: chaser, ranged, exploder, healer.
## Eliten tragen eine Modifikation (flink, gepanzert, blutsaugend). Zwischenbosse sind große Eliten.

signal died(enemy: Enemy)

var type_id: String = "grunt"
var data: Dictionary = {}
var arena: Node = null
var hp: float = 10.0
var max_hp: float = 10.0
var dmg: float = 5.0
var speed: float = 3.0
var dead: bool = false
var model_scale: float = 1.0
var elite_mod: String = ""
var is_mini: bool = false
var flank_angle: float = 0.0
var flanker: bool = false

# Status
var slow_t := 0.0
var slow_mult := 1.0
var freeze_t := 0.0
var stun_t := 0.0
var burn_t := 0.0
var burn_dps := 0.0
var mark_t := 0.0
var dmg_taken_mult := 1.0
var shield_mult := 1.0            # < 1: Schadensreduktion (Boss-Schild)

# KI
var state := "move"
var state_t := 0.0
var cd := 0.0
var _aim_dir := Vector3.FORWARD
var _telegraph: Node3D = null
var _flash := 0.0
var _anim_t := randf() * 10.0
var _visual: Node3D
var _mats: Array = []
var _rig_anim: AnimationPlayer = null
var _rig_mats: Array = []     # StandardMaterial3D der Skelett-Modelle (Treffer-Blitz per Emission)
var _rig_clip := ""
var _last_pos := Vector3.ZERO
var _rig_attack_t := 0.0
var _bar_fill: MeshInstance3D
var _bar_root: Node3D
var _knock := Vector3.ZERO
var _burn_tick := 0.0
var show_bar := true

# Multiplayer
var net_id := 0                  # vom Host vergeben (0 = Solo)
var ghost := false               # Client: nur Darstellung, keine KI, kein Schaden
var net_pos := Vector3.ZERO
var net_yaw := 0.0
var elem_hits: Dictionary = {}     # Element -> [Spieler, Zeit] für Koop-Kombos
var combo_cd := 0.0
var last_hit_by: Node = null     # Spieler, der zuletzt Schaden verursacht hat (Kill-Zuordnung)

const GRAVITY := 26.0


static func spawn(arena_node: Node, type_id_: String, pos: Vector3, scaling: Dictionary, elite: String = "", mini: bool = false) -> Enemy:
	var e := Enemy.new()
	e.arena = arena_node
	e.type_id = type_id_
	e.data = GameData.enemy_types[type_id_]
	e.elite_mod = elite
	e.is_mini = mini
	e.flanker = bool(scaling.get("flank", false)) and randf() < 0.5
	e.flank_angle = randf_range(-1.2, 1.2)
	e.max_hp = float(e.data["hp"]) * float(scaling.get("hp_mult", 1.0))
	e.dmg = float(e.data["damage"]) * float(scaling.get("dmg_mult", 1.0))
	e.speed = float(e.data["speed"]) * float(scaling.get("speed_mult", 1.0))
	e.model_scale = float(e.data["scale"])
	if elite != "":
		e.max_hp *= 2.4
		e.dmg *= 1.25
		e.model_scale *= 1.25
		if elite == "swift":
			e.speed *= float(GameData.elite_mods["swift"]["speed_mult"])
	if mini:
		e.max_hp *= 3.2
		e.dmg *= 1.4
		e.model_scale *= 1.45
	e.hp = e.max_hp
	e.position = pos
	arena_node.add_child(e)
	return e


## Client-Kopie eines Host-Gegners (nur Darstellung). desc: [id, type, x, y, z, elite, is_mini, scale, max_hp, is_boss]
static func spawn_ghost(arena_node: Node, desc: Array) -> Enemy:
	var e: Enemy = Boss.new() if bool(desc[9]) else Enemy.new()
	e.ghost = true
	e.net_id = int(desc[0])
	e.arena = arena_node
	e.type_id = str(desc[1])
	if bool(desc[9]):
		var bd: Dictionary = GameData.boss
		e.data = {"name": bd["name"], "behavior": "boss", "color": bd["color"], "accent": bd["accent"], "attack_range": 5.0,
				"windup": 1.0, "cooldown": 2.0, "hp": bd["hp"], "damage": bd["damage"], "speed": 2.4, "xp": bd["xp"], "scale": bd["scale"]}
	else:
		e.data = GameData.enemy_types[e.type_id]
	e.elite_mod = str(desc[5])
	e.is_mini = bool(desc[6])
	e.model_scale = float(desc[7])
	e.max_hp = float(desc[8])
	e.hp = e.max_hp
	e.position = Vector3(desc[2], desc[3], desc[4])
	e.net_pos = e.position
	arena_node.add_child(e)
	return e


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4 if not ghost else 0
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = 0.45 * model_scale
	sh.height = 1.6 * model_scale
	cs.shape = sh
	cs.position.y = 0.8 * model_scale
	add_child(cs)
	_visual = Node3D.new()
	_visual.scale = Vector3.ONE * model_scale
	add_child(_visual)
	_build_visual()
	_build_bar()
	if elite_mod != "" or is_mini:
		_build_elite_aura()
	_aim_dir = Vector3.FORWARD
	cd = randf_range(0.3, 1.2)


func _col(key: String) -> Color:
	var c := Color(data[key])
	if elite_mod != "":
		c = c.lerp(Color(GameData.elite_mods[elite_mod]["color"]), 0.35)
	return c


const SK_DIR := "res://assets/skeleton/"
const SK_WEAPONS := {"blade": "Skeleton_Blade", "axe": "Skeleton_Axe", "staff": "Skeleton_Staff", "crossbow": "Skeleton_Crossbow",
		"shield": "Skeleton_Shield_Small_A", "shield_big": "Skeleton_Shield_Large_A"}
static var _sk_loops := false


## Skelett-Gegner (KayKit Skeletons, CC0): Modell, Waffen und Farbton kommen aus den Gebiets-Skins (data/areas.json).
func _build_rigged() -> bool:
	var path := SK_DIR + str(data["model"]) + ".glb"
	if not ResourceLoader.exists(path):
		return false
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	inst.scale = Vector3.ONE * 0.5
	_visual.add_child(inst)
	var sk: Skeleton3D = inst.find_child("Skeleton3D", true, false)
	_rig_anim = inst.find_child("AnimationPlayer", true, false)
	if _rig_anim != null and not _sk_loops:
		_sk_loops = true
		for n in ["Idle", "Idle_Combat", "Walking_A", "Walking_B", "Walking_C", "Walking_D_Skeletons", "Running_A", "Running_B", "Spellcasting", "2H_Melee_Idle", "Blocking", "1H_Ranged_Aiming"]:
			if _rig_anim.has_animation(n):
				_rig_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	var tint := Color(str(data.get("tint", "#ffffff")))
	var glow := str(data.get("glow", ""))
	if elite_mod != "":
		tint = tint.lerp(Color(GameData.elite_mods[elite_mod]["color"]), 0.3)
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var src: Material = (mi as MeshInstance3D).get_active_material(0)
		if src is StandardMaterial3D:
			var m: StandardMaterial3D = src.duplicate()
			m.albedo_color = tint
			if glow != "":
				m.emission_enabled = true
				m.emission = Color(glow)
				m.emission_energy_multiplier = 0.35
			(mi as MeshInstance3D).material_override = m
			_rig_mats.append(m)
	if sk != null:
		for slot in [["handslot.r", str(data.get("weapon", ""))], ["handslot.l", str(data.get("offhand", ""))]]:
			if slot[1] == "" or not SK_WEAPONS.has(slot[1]):
				continue
			var wp := SK_DIR + "weapons/%s.gltf" % SK_WEAPONS[slot[1]]
			if not ResourceLoader.exists(wp) or sk.find_bone(slot[0]) < 0:
				continue
			var ba := BoneAttachment3D.new()
			ba.bone_name = slot[0]
			sk.add_child(ba)
			var w: Node3D = (load(wp) as PackedScene).instantiate()
			ba.add_child(w)
			w.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0.0333, 0))
	_rig_play("Idle")
	return true


func _rig_play(clip: String) -> void:
	if _rig_anim == null or clip == _rig_clip and _rig_anim.is_playing():
		return
	if _rig_anim.has_animation(clip):
		_rig_clip = clip
		_rig_anim.play(clip, 0.15)


func _rig_update(delta: float) -> void:
	if _rig_anim == null:
		return
	var spd := (global_position - _last_pos).length() / maxf(delta, 0.0001)
	_last_pos = global_position
	if dead:
		return
	if _rig_attack_t > 0.0:
		_rig_attack_t -= delta
		return
	if state == "windup":
		var atk := "2H_Melee_Attack_Chop"
		match str(data.get("model", "")):
			"Skeleton_Rogue": atk = "1H_Ranged_Shoot"
			"Skeleton_Mage": atk = "Spellcast_Shoot"
			"Skeleton_Minion": atk = "1H_Melee_Attack_Slice_Horizontal"
			"Skeleton_Warrior": atk = "1H_Melee_Attack_Chop"
		if _rig_anim.has_animation(atk):
			_rig_clip = atk
			_rig_anim.play(atk, 0.1)
			_rig_attack_t = maxf(float(data.get("windup", 0.6)), 0.5)
			return
	_rig_play("Walking_C" if spd > 0.4 else "Idle")
	_rig_anim.speed_scale = clampf(spd / 3.0, 0.7, 1.8) if spd > 0.4 else 1.0


func _flash_all(f: float) -> void:
	for m in _mats:
		if m is ShaderMaterial:
			m.set_shader_parameter("flash", f)
	for m in _rig_mats:
		m.emission_enabled = true
		m.emission = Color(1, 1, 1)
		m.emission_energy_multiplier = f * 1.4 if f > 0.0 else 0.0
		if f <= 0.0:
			var g := str(data.get("glow", ""))
			if g != "":
				m.emission = Color(g)
				m.emission_energy_multiplier = 0.35
			else:
				m.emission_enabled = false


func _build_visual() -> void:
	if data.has("model") and _build_rigged():
		return
	var c := _col("color")
	var ac := Color(data["accent"])
	var v := _visual
	match type_id:
		"grunt":
			var b := Toon.part(v, "sphere", Vector3(0.55, 0.85, 0), c, Vector3(0, 0.55, 0))
			Toon.outline(b, 0.03)
			Toon.part(v, "cone", Vector3(0.18, 0.35, 0), ac, Vector3(0, 1.15, 0), Vector3(0, 0, 12))   # Blatt
			for sx in [-1, 1]:
				Toon.part(v, "sphere", Vector3(0.09, 0, 0), Color.WHITE, Vector3(0.2 * sx, 0.7, 0.42), Vector3.ZERO, null, false)
				Toon.part(v, "sphere", Vector3(0.045, 0, 0), Color("#1b1b1b"), Vector3(0.2 * sx, 0.7, 0.5), Vector3.ZERO, null, false)
				Toon.part(v, "sphere", Vector3(0.14, 0, 0), c.darkened(0.2), Vector3(0.5 * sx, 0.3, 0.15))   # Händchen
		"archer":
			var b := Toon.part(v, "capsule", Vector3(0.32, 1.2, 0), c, Vector3(0, 0.75, 0))
			Toon.outline(b, 0.03)
			Toon.part(v, "cone", Vector3(0.36, 0.5, 0), c.darkened(0.25), Vector3(0, 1.55, 0))   # Kapuze
			Toon.part(v, "sphere", Vector3(0.18, 0, 0), ac, Vector3(0, 1.3, 0.08))
			for sx in [-1, 1]:
				Toon.part(v, "sphere", Vector3(0.04, 0, 0), Color("#ff4"), Vector3(0.07 * sx, 1.33, 0.24), Vector3.ZERO, Toon.glow_mat(Color("#ffee44"), 2.0), false)
			Toon.part(v, "torus", Vector3(0.5, 0.025, 0), Color("#5a3a1a"), Vector3(0.38, 0.9, 0.2), Vector3(0, 90, 0))   # Bogen
		"bomber":
			var b := Toon.part(v, "sphere", Vector3(0.5, 0, 0), c, Vector3(0, 0.5, 0), Vector3.ZERO, Toon.make_mat(c, 0.15))
			Toon.outline(b, 0.03)
			_mats.append(b.material_override)
			for i in 6:
				var ang := i * TAU / 6.0
				Toon.part(v, "cone", Vector3(0.1, 0.25, 0), ac, Vector3(cos(ang) * 0.46, 0.5 + sin(ang * 2) * 0.2, sin(ang) * 0.46), Vector3(0, 0, 0))
			Toon.part(v, "cyl", Vector3(0.04, 0.3, 0), Color("#444"), Vector3(0, 1.1, 0))
			Toon.part(v, "sphere", Vector3(0.09, 0, 0), ac, Vector3(0, 1.28, 0), Vector3.ZERO, Toon.glow_mat(ac, 3.0), false)
		"shaman":
			var b := Toon.part(v, "cone", Vector3(0.5, 1.4, 0), c, Vector3(0, 0.7, 0))
			Toon.outline(b, 0.03)
			Toon.part(v, "sphere", Vector3(0.22, 0, 0), ac, Vector3(0, 1.5, 0))
			Toon.part(v, "cone", Vector3(0.16, 0.5, 0), c.lightened(0.1), Vector3(0, 1.85, 0))   # Hut
			Toon.part(v, "cyl", Vector3(0.03, 1.8, 0), Color("#5a3a1a"), Vector3(0.5, 0.9, 0.1))
			Toon.part(v, "sphere", Vector3(0.14, 0, 0), ac, Vector3(0.5, 1.85, 0.1), Vector3.ZERO, Toon.glow_mat(Color("#7dffb0"), 2.2))
		"brute":
			var b := Toon.part(v, "sphere", Vector3(0.65, 0.9, 0), c, Vector3(0, 0.75, 0))
			Toon.outline(b, 0.035)
			for i in 5:
				Toon.part(v, "cone", Vector3(0.14, 0.3, 0), ac.darkened(0.2), Vector3(0, 1.3 - i * 0.02, -0.4 + i * 0.2), Vector3(-30 + i * 15, 0, 0))   # Rückenstacheln
			Toon.part(v, "sphere", Vector3(0.3, 0, 0), c.lightened(0.08), Vector3(0, 1.35, 0.3))
			for sx in [-1, 1]:
				Toon.part(v, "sphere", Vector3(0.38, 0, 0), c.darkened(0.15), Vector3(0.75 * sx, 0.45, 0.1))   # Fäuste
				Toon.part(v, "sphere", Vector3(0.06, 0, 0), Color("#ff6a3a"), Vector3(0.12 * sx, 1.42, 0.55), Vector3.ZERO, Toon.glow_mat(Color("#ff6a3a"), 2.0), false)
		"crawler":
			# Spinne: Körper, Kopf mit Augen, acht abgewinkelte Beine
			var body := Toon.part(v, "sphere", Vector3(0.36, 0.26, 0), c, Vector3(0, 0.38, -0.08))
			Toon.outline(body, 0.03)
			Toon.part(v, "sphere", Vector3(0.2, 0, 0), c.lightened(0.1), Vector3(0, 0.4, 0.3))
			for sx in [-1, 1]:
				for ey in [0.0, 0.07]:
					Toon.part(v, "sphere", Vector3(0.045, 0, 0), ac, Vector3(0.07 * sx, 0.46 + ey * 0.4, 0.46 - ey), Vector3.ZERO, Toon.glow_mat(ac, 2.0), false)
				for i in 4:
					var z := -0.25 + i * 0.17
					Toon.part(v, "cyl", Vector3(0.03, 0.55, 0), c.darkened(0.3), Vector3(0.3 * sx, 0.25, z), Vector3(0, 0, -62 * sx))
		"sentinel":
			# steinerner Wächter: Sockel, Rumpf, Kopf mit Visier, schwebende Kristalle
			var sb := Toon.part(v, "cyl", Vector3(0.38, 0.9, 0), c, Vector3(0, 0.45, 0))
			Toon.outline(sb, 0.03)
			Toon.part(v, "sphere", Vector3(0.3, 0, 0), c.lightened(0.1), Vector3(0, 1.15, 0))
			Toon.part(v, "box", Vector3(0.34, 0.07, 0.1), ac, Vector3(0, 1.17, 0.26), Vector3.ZERO, Toon.glow_mat(ac, 2.5), false)
			for i in 3:
				var an := i * TAU / 3.0
				Toon.part(v, "cone", Vector3(0.1, 0.3, 0), ac, Vector3(cos(an) * 0.6, 0.9 + sin(an * 2.0) * 0.1, sin(an) * 0.6), Vector3(0, 0, 180), Toon.glow_mat(ac, 2.0), false)
		"splitter", "splitling":
			# Gallertblob mit leuchtendem Kern
			var jb := Toon.part(v, "sphere", Vector3(0.58, 0.7, 0), c, Vector3(0, 0.5, 0), Vector3.ZERO, Toon.make_mat(c, 0.25))
			Toon.outline(jb, 0.03)
			_mats.append(jb.material_override)
			Toon.part(v, "sphere", Vector3(0.2, 0, 0), ac, Vector3(0, 0.55, 0.05), Vector3.ZERO, Toon.glow_mat(ac, 2.5), false)
			for sx in [-1, 1]:
				Toon.part(v, "sphere", Vector3(0.08, 0, 0), Color.WHITE, Vector3(0.18 * sx, 0.75, 0.46), Vector3.ZERO, null, false)
				Toon.part(v, "sphere", Vector3(0.04, 0, 0), Color("#1b1b1b"), Vector3(0.18 * sx, 0.75, 0.53), Vector3.ZERO, null, false)
		"cultist":
			var cb := Toon.part(v, "cone", Vector3(0.45, 1.5, 0), c, Vector3(0, 0.75, 0))
			Toon.outline(cb, 0.03)
			Toon.part(v, "sphere", Vector3(0.22, 0, 0), c.darkened(0.3), Vector3(0, 1.5, 0))
			Toon.part(v, "sphere", Vector3(0.12, 0, 0), ac, Vector3(0, 1.5, 0.12), Vector3.ZERO, Toon.glow_mat(ac, 2.0), false)
			Toon.part(v, "torus", Vector3(0.28, 0.03, 0), ac, Vector3(0, 1.0, 0), Vector3(90, 0, 0), Toon.glow_mat(ac, 1.5), false)
		_:
			Toon.part(v, "sphere", Vector3(0.5, 0, 0), c, Vector3(0, 0.5, 0))
	# Materialien für Treffer-Blitz einzeln halten
	for n in v.find_children("*", "MeshInstance3D", true, false):
		var m: Material = n.material_override
		if m is ShaderMaterial and m.shader == Toon.shader():
			var dup: ShaderMaterial = m.duplicate()
			n.material_override = dup
			_mats.append(dup)


func _build_bar() -> void:
	_bar_root = Node3D.new()
	_bar_root.position = Vector3(0, 2.1 * model_scale + 0.3, 0)
	add_child(_bar_root)
	for i in 2:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.0, 0.11)
		mi.mesh = q
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.no_depth_test = true
		m.render_priority = 10 + i
		m.albedo_color = Color(0.1, 0.05, 0.08, 0.85) if i == 0 else (Color("#ff5a4a") if elite_mod == "" and not is_mini else Color("#ffb340"))
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_bar_root.add_child(mi)
		if i == 1:
			_bar_fill = mi
	_bar_root.visible = false


func _build_elite_aura() -> void:
	var col := Color("#ffd24a") if elite_mod == "" else Color(GameData.elite_mods[elite_mod]["color"])
	var ringm := Toon.part(self, "torus", Vector3(0.9 * model_scale, 0.9 * model_scale - 0.06, 0), col, Vector3(0, 0.08, 0), Vector3.ZERO, Toon.glow_mat(col, 2.0, 0.8), false)
	ringm.name = "AuraRing"
	var crown := Toon.part(_visual, "cone", Vector3(0.12, 0.3, 0), col, Vector3(0, 2.15, 0), Vector3.ZERO, Toon.glow_mat(col, 2.5), false)
	crown.name = "Crown"


func display_name() -> String:
	var n: String = data["name"]
	if is_mini:
		return "Alpha-" + n
	if elite_mod != "":
		return "%s %s" % [GameData.elite_mods[elite_mod]["name"], n]
	return n


# ------------------------------------------------------------------ Update

func _ghost_step(delta: float) -> void:
	_anim_t += delta
	position = position.lerp(net_pos, clampf(delta * 14.0, 0.0, 1.0))
	rotation.y = lerp_angle(rotation.y, net_yaw, clampf(delta * 12.0, 0.0, 1.0))
	var moving := position.distance_to(net_pos) > 0.05
	if _rig_anim == null:
		_visual.position.y = sin(_anim_t * (9.0 if moving else 3.0)) * 0.05
	_rig_update(delta)
	_update_flash(delta)
	_visual_tint_ghost()
	_bar_root.visible = show_bar and hp < max_hp and not dead
	if _bar_fill != null:
		var f := clampf(hp / max_hp, 0.001, 1.0)
		_bar_fill.scale.x = f
		_bar_fill.position.x = -0.5 * (1.0 - f)
	_bar_root.scale = Vector3.ONE * maxf(model_scale, 0.9)


func _visual_tint_ghost() -> void:
	if freeze_t > 0.0:
		_set_tint(Color(0.6, 0.85, 1.0), 0.55)
	elif slow_t > 0.0:
		_set_tint(Color(0.55, 0.8, 1.0), 0.3)
	elif _flash <= 0.0:
		_set_tint(Color.WHITE, 0.0)


## Trefferdarstellung auf dem Client (Schadenszahl kommt separat als Effekt-Ereignis).
func ghost_hit() -> void:
	_flash = 1.0
	_flash_all(1.0)


## Statusflags aus dem Snapshot (Bits: 1 Schild, 2 gefroren, 4 verlangsamt, 8 verwundbar, 16 Vorbereitung).
func apply_net_flags(flags: int) -> void:
	freeze_t = 0.3 if (flags & 2) != 0 else 0.0
	slow_t = 0.3 if (flags & 4) != 0 else 0.0
	if (flags & 16) != 0 and _flash < 0.4:
		_flash = 0.5


func net_flags() -> int:
	var f := 0
	if freeze_t > 0.0:
		f |= 2
	if slow_t > 0.0:
		f |= 4
	if state == "windup":
		f |= 16
	return f


func _physics_process(delta: float) -> void:
	if ghost:
		if not dead:
			_ghost_step(delta)
		return
	if dead:
		return
	if RunState.world_freeze > 0.0:
		return
	_anim_t += delta
	_update_status(delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	var player: Node3D = pick_target()
	var move_vec := Vector3.ZERO
	if freeze_t > 0.0 or stun_t > 0.0:
		_cancel_telegraph()
		state = "move"
	elif player != null and not player.is_down():
		move_vec = _ai(delta, player)
	var sm := slow_mult if slow_t > 0.0 else 1.0
	velocity.x = move_vec.x * sm + _knock.x
	velocity.z = move_vec.z * sm + _knock.z
	_knock = _knock.move_toward(Vector3.ZERO, 28.0 * delta)
	move_and_slide()
	# Stilisierte Animation
	var bob := sin(_anim_t * (9.0 if move_vec.length() > 0.1 else 3.0)) * 0.05
	if _rig_anim == null:
		_visual.position.y = bob
	_rig_update(delta)
	if move_vec.length() > 0.1 and state == "move":
		_face(move_vec, delta)
	_update_flash(delta)
	_bar_root.visible = show_bar and hp < max_hp and not dead
	if _bar_fill != null:
		var f := clampf(hp / max_hp, 0.001, 1.0)
		_bar_fill.scale.x = f
		_bar_fill.position.x = -0.5 * (1.0 - f)
	_bar_root.scale = Vector3.ONE * maxf(model_scale, 0.9)


## Nächster Spieler, der kämpfen kann (nicht kampfunfähig, nicht getrennt). Im Koop wechselt das Ziel dadurch laufend.
func pick_target() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p) or p.is_down() or p.get("net_away") == true:
			continue
		var d: float = p.global_position.distance_squared_to(global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


func _face(dir: Vector3, delta: float) -> void:
	var target := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, target, clampf(delta * 10.0, 0.0, 1.0))


func _update_status(delta: float) -> void:
	slow_t = maxf(slow_t - delta, 0.0)
	freeze_t = maxf(freeze_t - delta, 0.0)
	stun_t = maxf(stun_t - delta, 0.0)
	mark_t = maxf(mark_t - delta, 0.0)
	cd = maxf(cd - delta, 0.0)
	if burn_t > 0.0:
		burn_t -= delta
		_burn_tick -= delta
		if _burn_tick <= 0.0:
			_burn_tick = 0.5
			take_damage(burn_dps * 0.5, false, global_position, 0.0, true)
			FX.burst(arena, global_position + Vector3(0, 1, 0), Color("#ff7a2a"), 3, 1.5, 0.07, 0.3)
	_visual_tint()


func _visual_tint() -> void:
	if freeze_t > 0.0:
		_set_tint(Color(0.6, 0.85, 1.0), 0.55)
	elif slow_t > 0.0:
		_set_tint(Color(0.55, 0.8, 1.0), 0.3)
	elif _flash <= 0.0:
		_set_tint(Color.WHITE, 0.0)


func _set_tint(_c: Color, amount: float) -> void:
	_flash_all(maxf(amount, _flash))


func _update_flash(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 6.0, 0.0)
		_flash_all(_flash)


func _cancel_telegraph() -> void:
	if _telegraph != null and is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null


# ------------------------------------------------------------------ KI

func _ai(delta: float, player: Node3D) -> Vector3:
	var to_p: Vector3 = player.global_position - global_position
	to_p.y = 0.0
	var dist := to_p.length()
	var dir := to_p / maxf(dist, 0.001)
	var rng_a: float = float(data["attack_range"])
	match String(data["behavior"]):
		"chaser":
			return _ai_chaser(delta, player, dir, dist, rng_a)
		"ranged":
			return _ai_ranged(delta, player, dir, dist, rng_a)
		"exploder":
			return _ai_exploder(delta, player, dir, dist, rng_a)
		"healer":
			return _ai_healer(delta, player, dir, dist, rng_a)
	return Vector3.ZERO


func _chase_dir(dir: Vector3, dist: float) -> Vector3:
	# Flankieren (ab 3 Spielern): Verfolger nähern sich in einem Bogen
	if flanker and dist > 4.0:
		return dir.rotated(Vector3.UP, flank_angle * clampf((dist - 3.0) / 10.0, 0.0, 1.0))
	return dir


func _ai_chaser(delta: float, player: Node3D, dir: Vector3, dist: float, rng_a: float) -> Vector3:
	match state:
		"move":
			if dist <= rng_a * 0.9 and cd <= 0.0:
				state = "windup"
				state_t = float(data["windup"])
				_aim_dir = dir
				_telegraph = FX.telegraph(arena, global_position + dir * rng_a * 0.5, rng_a * 0.55, state_t)
				_flash = 0.5
				return Vector3.ZERO
			return _chase_dir(dir, dist) * speed
		"windup":
			state_t -= delta
			rotation.y = lerp_angle(rotation.y, atan2(_aim_dir.x, _aim_dir.z), 0.3)
			_visual.scale = Vector3.ONE * model_scale * Vector3(1.0 + 0.15 * sin(state_t * 30), 1.0 - 0.1, 1.0)
			if state_t <= 0.0:
				_cancel_telegraph()
				_visual.scale = Vector3.ONE * model_scale
				var center := global_position + _aim_dir * rng_a * 0.5
				if player.global_position.distance_to(center) <= rng_a * 0.55 + 0.45:
					player.take_damage(dmg, global_position)
				FX.burst(arena, center + Vector3(0, 0.5, 0), Color(data["accent"]), 8, 4.0)
				Sfx.play("swing", 0.8, -8.0)
				if elite_mod == "vampiric":
					hp = minf(hp + dmg * float(GameData.elite_mods["vampiric"]["lifesteal"]), max_hp)
				state = "move"
				cd = float(data["cooldown"])
			return Vector3.ZERO
	return Vector3.ZERO


func _ai_ranged(delta: float, player: Node3D, dir: Vector3, dist: float, rng_a: float) -> Vector3:
	match state:
		"move":
			var want := rng_a * 0.65
			var mv := Vector3.ZERO
			if dist > want + 2.0:
				mv = dir * speed
			elif dist < want - 3.0:
				mv = -dir * speed
			else:
				mv = dir.rotated(Vector3.UP, PI * 0.5 * (1.0 if int(_anim_t * 0.3) % 2 == 0 else -1.0)) * speed * 0.6
			_face(dir, delta)
			if dist <= rng_a and cd <= 0.0:
				state = "windup"
				state_t = float(data["windup"])
				_flash = 0.4
			return mv
		"windup":
			state_t -= delta
			rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 0.3)
			if state_t <= 0.0:
				var pr := Projectile.new()
				pr.from_player = false
				pr.damage = dmg
				pr.radius = 0.35
				pr.life = 2.6
				var from := global_position + Vector3(0, 1.2 * model_scale, 0) + dir * 0.6
				var lead: Vector3 = player.global_position + Vector3(0, 0.9, 0) + player.velocity * 0.25
				pr.setup(arena, from, (lead - from).normalized() * 12.0, Color("#ffb84a"), 0.18)
				Sfx.play("cast", 1.3, -10.0)
				state = "move"
				cd = float(data["cooldown"]) * (0.7 if elite_mod == "swift" else 1.0)
			return Vector3.ZERO
	return Vector3.ZERO


func _ai_exploder(delta: float, player: Node3D, dir: Vector3, dist: float, rng_a: float) -> Vector3:
	match state:
		"move":
			if dist <= rng_a:
				state = "windup"
				state_t = float(data["windup"])
				_telegraph = FX.telegraph(arena, global_position, 3.2 * model_scale, state_t)
				_telegraph.reparent(self, true)
				return Vector3.ZERO
			return _chase_dir(dir, dist) * speed
		"windup":
			state_t -= delta
			var k := 1.0 + (1.0 - state_t / float(data["windup"])) * 0.5
			_visual.scale = Vector3.ONE * model_scale * k
			_flash = 0.5 + 0.5 * sin(state_t * 40.0)
			if state_t <= 0.0:
				explode()
			return dir * speed * 0.35
	return Vector3.ZERO


func explode() -> void:
	if dead:
		return
	var r := 3.2 * model_scale
	FX.ring(arena, global_position, r, Color("#ff7a3a"), 0.4)
	FX.burst(arena, global_position + Vector3(0, 0.6, 0), Color("#ffb040"), 22, 7.0, 0.16, 0.6)
	Sfx.play("boom", 1.0, -3.0)
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and not p.is_down() and p.global_position.distance_to(global_position) <= r + 0.4:
			p.take_damage(dmg, global_position)
	die(false, true)


func _ai_healer(delta: float, player: Node3D, dir: Vector3, dist: float, rng_a: float) -> Vector3:
	var mv := Vector3.ZERO
	if dist < 7.5:
		mv = -dir * speed
	elif dist > 12.0:
		mv = dir * speed
	_face(dir, delta)
	if cd <= 0.0 and state == "move":
		var target: Enemy = null
		var worst := 0.7
		for o in get_tree().get_nodes_in_group("enemies"):
			if o == self or not is_instance_valid(o) or o.dead:
				continue
			var ratio: float = o.hp / o.max_hp
			if ratio < worst and o.global_position.distance_to(global_position) <= rng_a + 2.0:
				worst = ratio
				target = o
		if target != null:
			target.heal(target.max_hp * (0.03 if target._is_boss() else 0.25))   # Bosse werden nur schwach geheilt
			FX.beam(arena, global_position + Vector3(0, 1.6, 0), target.global_position + Vector3(0, 1.0, 0), Color("#7dffb0"), 0.4, 0.05)
			FX.burst(arena, target.global_position + Vector3(0, 1, 0), Color("#7dffb0"), 8, 2.0, 0.08, 0.5)
			cd = float(data["cooldown"])
		elif dist <= rng_a and cd <= 0.0:
			var pr := Projectile.new()
			pr.from_player = false
			pr.damage = dmg
			pr.radius = 0.3
			var from := global_position + Vector3(0, 1.8, 0)
			pr.setup(arena, from, (player.global_position + Vector3(0, 0.9, 0) - from).normalized() * 9.0, Color("#9b6bff"), 0.16)
			cd = float(data["cooldown"]) * 0.8
	return mv


# ------------------------------------------------------------------ Schaden & Status

func heal(amount: float) -> void:
	hp = minf(hp + amount, max_hp)
	FX.float_text(arena, global_position, "+%d" % int(amount), Color("#7dffb0"), 36)


func take_damage(amount: float, crit: bool, from_pos: Vector3, knock: float = 0.0, silent: bool = false) -> float:
	if dead:
		return 0.0
	var a := amount * dmg_taken_mult * shield_mult
	if mark_t > 0.0:
		a *= 1.15
	if elite_mod == "armored":
		a *= 1.0 - float(GameData.elite_mods["armored"]["damage_reduction"])
	hp -= a
	if not silent and arena != null and arena.has_method("net_enemy_hit"):
		arena.net_enemy_hit(self)
	if not silent:
		_flash = 1.0
		_flash_all(1.0)
		FX.float_text(arena, global_position, str(int(roundf(a))), Color("#ffe066") if crit else Color.WHITE, 40, crit)
		FX.burst(arena, global_position + Vector3(0, 1.0 * model_scale, 0), Color("#fff2c0") if not crit else Color("#ffcf4a"), 5 if not crit else 10, 4.0, 0.08, 0.35)
		if knock > 0.0 and not is_mini and not _is_boss():
			var d := global_position - from_pos
			d.y = 0.0
			_knock += d.normalized() * knock / maxf(model_scale, 0.8)
	if hp <= 0.0:
		die(true)
	return a


func _is_boss() -> bool:
	return false


func apply_slow(duration: float, mult: float) -> void:
	slow_t = maxf(slow_t, duration)
	slow_mult = minf(slow_mult if slow_t > 0.0 else 1.0, mult)
	slow_mult = mult


func apply_freeze(duration: float) -> void:
	if not _is_boss() and not is_mini:
		freeze_t = maxf(freeze_t, duration)


func apply_stun(duration: float) -> void:
	if not _is_boss():
		stun_t = maxf(stun_t, duration)


func apply_burn(duration: float, dps: float) -> void:
	burn_t = maxf(burn_t, duration)
	burn_dps = maxf(burn_dps, dps)


func die(killed_by_player: bool, silent_explosion: bool = false) -> void:
	if dead:
		return
	dead = true
	_cancel_telegraph()
	remove_from_group("enemies")
	collision_layer = 0
	_bar_root.visible = false
	if not ghost:
		died.emit(self)
	if not ghost:   # auf Clients kommt der Effekt als Ereignis vom Host
		FX.burst(arena, global_position + Vector3(0, 0.8, 0), Color(data["color"]), 14, 5.0, 0.13, 0.6)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_visual, "scale", Vector3.ONE * model_scale * 0.05, 0.3).set_ease(Tween.EASE_IN)
	tw.tween_property(_visual, "position:y", -0.4, 0.3)
	tw.chain().tween_callback(queue_free)
