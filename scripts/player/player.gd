class_name Player
extends CharacterBody3D
## Spielercharakter: Third-Person-Steuerung, Nahkampf-Kombos, Ausweichrolle, Blocken/Parieren,
## Fernkampfwaffen und die Rundenfähigkeiten. Die Eingabe wird in ein Dictionary gesammelt
## (gather_input) – dadurch können später Touch-Steuerung, Gamepad und Tests dieselbe Logik nutzen.

signal leveled_up(new_level: int)
signal died_signal
signal skill_unlocked(id: String)
signal evolution_unlocked(evo_id: String)

const GRAVITY := 26.0
const WEAPONS := {
	"sword":  {"range": 2.9, "arc": 130.0, "mult": 1.0, "speed": 1.0, "dur": 0.42, "ranged": false},
	"axe":    {"range": 2.7, "arc": 160.0, "mult": 1.25, "speed": 0.85, "dur": 0.5, "ranged": false},
	"hammer": {"range": 3.2, "arc": 200.0, "mult": 1.7, "speed": 0.6, "dur": 0.62, "ranged": false},
	"dagger": {"range": 2.2, "arc": 110.0, "mult": 0.65, "speed": 1.6, "dur": 0.28, "ranged": false},
	"bow":    {"range": 30.0, "arc": 0.0, "mult": 1.0, "speed": 0.9, "dur": 0.5, "ranged": true},
	"staff":  {"range": 30.0, "arc": 0.0, "mult": 0.9, "speed": 0.95, "dur": 0.48, "ranged": true},
}

var arena: Node = null
var character: Dictionary = {}
var stats: Dictionary = {}
var levels: Dictionary = {}            # Rundenfähigkeiten: id -> Stufe
var skill_slots: Array = []            # aktive Fähigkeiten in Reihenfolge des Erwerbs
var cooldowns: Dictionary = {}
var hp := 100.0
var mana := 100.0
var shield := 0.0
var level := 1
var xp := 0
var rerolls_left := 2
var recent_offers: Array = []
var weapon_type := "sword"
var rng := RandomNumberGenerator.new()
var active_evolutions: Array = []

# Zustand
var state := "idle"          # idle | attack | dodge | down
var attack_t := 0.0
var attack_dur := 0.4
var attack_kind := "light"
var attack_hit_done := false
var combo := 0
var combo_timer := 0.0
var dodge_t := 0.0
var dodge_cd := 0.0
var dodge_dir := Vector3.ZERO
var iframes := 0.0
var blocking := false
var block_t := 0.0
var empowered := false
var frost_shield_t := 0.0
var shake := 0.0
var lock_target: Node3D = null
var _regen_acc := 0.0
var _walk_phase := 0.0
var _aim_yaw := 0.0
var _bot_t := 0.0

# Autoplay (für automatisierte Tests): spielt selbstständig, nimmt aber nur reduzierten Schaden
var bot := false
var bot_damage_scale := 1.0

var cam_yaw := 0.0
var cam_pitch := -0.32
var _yaw_pivot: Node3D
var _pitch_pivot: Node3D
var _arm: SpringArm3D
var camera: Camera3D
var model: Dictionary = {}
var _body_tilt := 0.0
var wisps: Array = []
var _just := {}

# ---- Multiplayer -------------------------------------------------------------------------------------------
# Rollen:  none         Solo oder der lokale Spieler des Hosts (volle Simulation, eigene Kamera)
#          local_client Der eigene Spieler auf einem Client: bewegt sich lokal (Vorhersage), Kampf läuft auf dem Host
#          remote_sim   Host-seitige Simulation eines Remote-Spielers: Kampf, Schaden, Fähigkeiten, Beute (ohne Kamera)
#          puppet       Darstellung eines anderen Spielers auf einem Client
const ACT_DODGE := 0
const ACT_HEAVY := 1
const ACT_SKILL1 := 2   # 2..5
const ACT_INTERACT := 6
const ACT_LOCK := 7
const ACT_BLOCK := 8
const HOLD_LIGHT := 1
const HOLD_BLOCK := 2
const HOLD_INTERACT := 4
const BLEED_TIME := 30.0          # so lange kann ein kampfunfähiger Spieler wiederbelebt werden
const REVIVE_TIME := 3.0          # so lange muss ein Mitspieler die Interaktionstaste halten
const STATE_CODES := ["idle", "attack", "dodge", "down"]

var net_role := "none"
var net_away := false             # Verbindung verloren: unverwundbar, wird von Gegnern ignoriert
var net_peer := 0                 # remote_sim: Peer-ID des Besitzers
var net_slot := 0
var display_name := ""
var run_stats: Dictionary = {}
var interact_held := false
var bleed_t := 0.0
var revive_progress := 0.0
var permadown := false
var _shield_idle := 0.0
var offer_resend := 0.0
var aura_dmg_mult := 1.0          # Bonus durch "Heilende Aura" eines Verbündeten (Stufe 4)
var level_pending := 0            # Host: noch nicht vergebene Levelaufstiege
var net_offers: Array = []        # Host: aktuell angebotene Verbesserungen
var offer_deadline := 0.0
var remote_target := Vector3.ZERO
var remote_yaw := 0.0
var remote_cam_yaw := 0.0
var remote_holds := 0
var remote_acts: Array = []
var puppet_target := Vector3.ZERO
var puppet_yaw := 0.0
var wisp_visuals := 0
var _cwisps: Array = []
var _nameplate: Node3D
var _plate_label: Label3D
var _plate_fill: MeshInstance3D
var _down_pose := 0.0


static func new_run_stats() -> Dictionary:
	return {"kills": 0, "elites": 0, "minibosses": 0, "damage_dealt": 0.0, "damage_taken": 0.0, "downs": 0,
			"chests": 0, "shrines": 0, "items": [], "boss_defeated": false, "healing": 0.0, "revives": 0}


## Öffentliches Paket für die Darstellung auf anderen Clients.
func net_pack() -> Array:
	var flags := 0
	if blocking:
		flags |= 1
	if attack_kind == "heavy":
		flags |= 2
	if net_away:
		flags |= 4
	if permadown:
		flags |= 8
	return [net_slot, snappedf(global_position.x, 0.01), snappedf(global_position.y, 0.01), snappedf(global_position.z, 0.01),
			snappedf(rotation.y, 0.01), maxi(STATE_CODES.find(state), 0), snappedf(hp, 0.1), snappedf(stats["max_hp"], 0.1),
			combo, snappedf(attack_t, 0.01), snappedf(attack_dur, 0.01), flags, wisps.size(), level,
			snappedf(revive_progress, 0.01), snappedf(bleed_t, 0.1)]


func is_local_view() -> bool:
	return net_role == "none" or net_role == "local_client"


func setup(arena_node: Node, c: Dictionary) -> void:
	arena = arena_node
	character = c
	rng.randomize()
	var eq: Dictionary = c.get("equipment", {})
	if eq.has("weapon"):
		var it := SaveSystem.find_item(c, eq["weapon"])
		weapon_type = it.get("weapon_type", "sword")
	recalc(true)
	if net_role == "none" or net_role == "remote_sim":
		_grant_start_skills()
	hp = stats["max_hp"]
	mana = stats["mana_max"]


## Startfähigkeiten hängen von der Waffe in der Hand ab (eine aktive + eine passive Stufe 1).
const START_SKILLS := {
	"sword": ["chain_lightning", "vampiric"], "axe": ["frost_nova", "wide_strikes"], "hammer": ["earthquake", "iron_will"],
	"dagger": ["spirit_wisps", "crit_mastery"], "bow": ["fireball", "swift"], "staff": ["fireball", "arcane_focus"],
}


func _grant_start_skills() -> void:
	if not levels.is_empty():
		return
	for id in START_SKILLS.get(weapon_type, START_SKILLS["sword"]):
		if GameData.skills.has(id):
			add_skill_level(id)


func _ready() -> void:
	if run_stats.is_empty():
		run_stats = Player.new_run_stats()
	if net_role == "puppet":
		add_to_group("puppets")
		collision_layer = 0
		collision_mask = 0
	else:
		add_to_group("player")
		collision_layer = 2
		collision_mask = 1
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = 0.4
	sh.height = 1.8
	cs.shape = sh
	cs.position.y = 0.9
	add_child(cs)
	model = CharacterModel.build(character.get("appearance", {}), weapon_type, CharacterModel.gear_looks(character))
	add_child(model["root"])
	if not is_local_view():
		if net_role == "puppet" or net_role == "remote_sim":
			_build_nameplate()
		return
	# Kamera: Yaw -> Pitch -> SpringArm -> Kamera
	_yaw_pivot = Node3D.new()
	_yaw_pivot.top_level = true
	add_child(_yaw_pivot)
	_pitch_pivot = Node3D.new()
	_yaw_pivot.add_child(_pitch_pivot)
	_arm = SpringArm3D.new()
	_arm.spring_length = float(SaveSystem.data["settings"].get("camera_distance", 6.5))
	_arm.collision_mask = 1
	_arm.margin = 0.3
	_arm.shape = SphereShape3D.new()
	(_arm.shape as SphereShape3D).radius = 0.25
	_pitch_pivot.add_child(_arm)
	camera = Camera3D.new()
	camera.fov = float(SaveSystem.data["settings"].get("fov", 70.0))
	camera.far = 220.0
	camera.near = 0.12
	camera.current = true
	_arm.add_child(camera)
	_yaw_pivot.global_position = global_position + Vector3(0, 1.7, 0)


func is_down() -> bool:
	return state == "down"


# ------------------------------------------------------------------ Werte

func recalc(initial: bool = false) -> void:
	var ratio := hp / maxf(float(stats.get("max_hp", hp)), 1.0)
	stats = Stats.compute(character, RunMods.build(levels))
	if not initial:
		hp = minf(hp, stats["max_hp"])
	if ratio < 0.0:
		pass
	active_evolutions = LevelUp.active_evolutions(levels)


func skill_lv(id: String) -> int:
	return int(levels.get(id, 0))


func has_flag(f: String) -> bool:
	return f in stats.get("flags", [])


func weapon_def() -> Dictionary:
	return WEAPONS.get(weapon_type, WEAPONS["sword"])


# ------------------------------------------------------------------ Fähigkeiten & XP

func add_skill_level(id: String) -> void:
	var before := active_evolutions.duplicate()
	levels[id] = skill_lv(id) + 1
	var def: Dictionary = GameData.skills[id]
	if def["kind"] == "active" and not (id in skill_slots):
		skill_slots.append(id)
		cooldowns[id] = 0.0
		skill_unlocked.emit(id)
	recalc()
	if id == "vitality":
		hp = minf(stats["max_hp"], hp + 25.0)
	if id == "spirit_wisps":
		_refresh_wisps()
	for e in active_evolutions:
		if not (e in before):
			evolution_unlocked.emit(e)


func add_xp(amount: int) -> int:
	xp += amount
	var gained := 0
	while xp >= GameData.xp_needed(level):
		xp -= GameData.xp_needed(level)
		level += 1
		gained += 1
		leveled_up.emit(level)
	return gained


# ------------------------------------------------------------------ Eingabe

func gather_input() -> Dictionary:
	if bot:
		return _bot_input()
	var inp := {
		"move": Input.get_vector("move_left", "move_right", "move_forward", "move_back"),
		"jump": Input.is_action_just_pressed("jump"),
		"sprint": Input.is_action_pressed("sprint"),
		"dodge": Input.is_action_just_pressed("dodge"),
		"light": Input.is_action_pressed("attack_light"),
		"heavy": Input.is_action_just_pressed("attack_heavy"),
		"block": Input.is_action_pressed("block"),
		"block_press": Input.is_action_just_pressed("block"),
		"skills": [Input.is_action_just_pressed("skill_1"), Input.is_action_just_pressed("skill_2"),
				Input.is_action_just_pressed("skill_3"), Input.is_action_just_pressed("skill_4")],
		"interact": Input.is_action_just_pressed("interact"),
		"interact_held": Input.is_action_pressed("interact"),
		"lock": Input.is_action_just_pressed("lock_on"),
	}
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		inp["light"] = false
		inp["heavy"] = false
	return inp


func _unhandled_input(event: InputEvent) -> void:
	if bot or get_tree().paused or not is_local_view():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = float(SaveSystem.data["settings"].get("mouse_sensitivity", 0.0025))
		cam_yaw -= event.relative.x * sens
		cam_pitch = clampf(cam_pitch - event.relative.y * sens, -1.1, 0.5)


func _bot_input() -> Dictionary:
	var inp := {"move": Vector2.ZERO, "jump": false, "sprint": false, "dodge": false, "light": false, "heavy": false,
			"block": false, "block_press": false, "skills": [false, false, false, false], "interact": false, "interact_held": false, "lock": false}
	# Koop: erst Verbündete wiederbeleben, wenn gerade kein Gegner nah ist
	var ally := _nearest_downed_ally()
	if ally != null and _nearest_enemy(7.0) == null:
		var to_a: Vector3 = ally.global_position - global_position
		to_a.y = 0.0
		cam_yaw = lerp_angle(cam_yaw, atan2(-to_a.x, -to_a.z), 0.3)
		if to_a.length() > 1.6:
			inp["move"] = Vector2(0, -1)
			inp["sprint"] = true
		else:
			inp["interact_held"] = true
		return inp
	var target: Node3D = _nearest_enemy(40.0)
	if target == null:
		var t_o: Node3D = arena.get("boss") if arena != null else null
		target = t_o if t_o != null and is_instance_valid(t_o) and not t_o.dead else null
	if target == null:
		return inp
	var to_t: Vector3 = target.global_position - global_position
	to_t.y = 0.0
	var dist := to_t.length()
	cam_yaw = lerp_angle(cam_yaw, atan2(-to_t.x, -to_t.z), 0.25)
	var want: float = float(weapon_def()["range"]) * 0.75 if not weapon_def()["ranged"] else 9.0
	# Bewegungsrichtung relativ zur Kamera (Kamera blickt zum Ziel -> vorwärts = Richtung Ziel)
	if dist > want:
		inp["move"] = Vector2(0, -1)
	elif dist < want - 2.0 and weapon_def()["ranged"]:
		inp["move"] = Vector2(0, 1)
	inp["light"] = dist < weapon_def()["range"] + 1.0 or weapon_def()["ranged"]
	for i in skill_slots.size():
		if i < 4 and cooldowns.get(skill_slots[i], 0.0) <= 0.0 and mana >= float(GameData.skills[skill_slots[i]].get("mana", 10)) and dist < 14.0:
			inp["skills"][i] = true
	_bot_t -= get_physics_process_delta_time()
	if _bot_t <= 0.0 and dodge_cd <= 0.0 and hp < stats["max_hp"] * 0.5:
		inp["dodge"] = true
		inp["move"] = Vector2(1, 0)
		_bot_t = 1.2
	return inp


# ------------------------------------------------------------------ Update

func _physics_process(delta: float) -> void:
	match net_role:
		"puppet":
			_puppet_step(delta)
			return
		"remote_sim":
			_remote_step(delta)
			return
	if state == "down":
		_down_pose = move_toward(_down_pose, 1.0, delta * 3.0)
		_apply_down_pose()
		if net_role == "local_client":
			_update_cosmetic_wisps(delta)
		if is_local_view() and _yaw_pivot != null:
			_spectate(delta)
		return
	if _down_pose > 0.0:
		_down_pose = move_toward(_down_pose, 0.0, delta * 3.0)
		_apply_down_pose()
	var inp := gather_input()
	interact_held = inp.get("interact_held", false)
	_tick_timers(delta)
	_camera_update(delta, inp)
	_movement(delta, inp)
	if net_role == "local_client":
		_client_combat(delta, inp)
		_update_cosmetic_wisps(delta)
	else:
		_combat(delta, inp)
	_animate(delta, inp)
	if arena != null and inp.get("interact", false):
		arena.call("player_interact", self)
	if net_role == "local_client" and arena != null:
		arena.call("net_send_state", self, inp)


func _tick_timers(delta: float) -> void:
	for id in cooldowns:
		cooldowns[id] = maxf(cooldowns[id] - delta, 0.0)
	dodge_cd = maxf(dodge_cd - delta, 0.0)
	iframes = maxf(iframes - delta, 0.0)
	combo_timer = maxf(combo_timer - delta, 0.0)
	if combo_timer <= 0.0:
		combo = 0
	frost_shield_t = maxf(frost_shield_t - delta, 0.0)
	block_t += delta if blocking else 0.0
	shake = maxf(shake - delta * 2.5, 0.0)
	if net_role == "local_client":
		return   # Leben und Mana kommen vom Host
	mana = minf(mana + stats["mana_regen"] * delta, stats["mana_max"])
	var asl := skill_lv("arcane_shield")
	if asl > 0 and state != "down":
		_shield_idle += delta
		if _shield_idle > 4.0 and shield < stats["max_hp"] * 0.1 * asl:
			shield = minf(shield + stats["max_hp"] * 0.03 * delta * asl, stats["max_hp"] * 0.1 * asl)
	_regen_acc += stats["hp_regen"] * delta * stats["heal_power"]
	if _regen_acc >= 1.0 and hp < stats["max_hp"]:
		hp = minf(hp + _regen_acc, stats["max_hp"])
		_regen_acc = 0.0
	elif hp >= stats["max_hp"]:
		_regen_acc = 0.0


var _spec: Node3D = null
var spec_name := ""


func _spec_candidates() -> Array:
	var out: Array = []
	for grp in ["player", "puppets"]:
		for a in get_tree().get_nodes_in_group(grp):
			if a != self and is_instance_valid(a) and not a.is_down() and a.get("net_away") != true:
				out.append(a)
	return out


## Kampfunfähig: Kamera folgt einem Mitspieler. Linksklick wechselt zum nächsten.
func _spectate(delta: float) -> void:
	var c := _spec_candidates()
	spec_name = ""
	if c.is_empty():
		return
	if _spec == null or not is_instance_valid(_spec) or not (_spec in c):
		_spec = c[0]
	elif Input.is_action_just_pressed("attack_light") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_spec = c[(c.find(_spec) + 1) % c.size()]
	spec_name = str(_spec.get("display_name") if _spec.get("display_name") != null else "Mitspieler")
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look.length() > 0.1:
		cam_yaw -= look.x * 2.8 * delta
		cam_pitch = clampf(cam_pitch - look.y * 2.0 * delta, -1.1, 0.5)
	_yaw_pivot.global_position = _yaw_pivot.global_position.lerp(_spec.global_position + Vector3(0, 1.7, 0), clampf(delta * 8.0, 0.0, 1.0))
	_yaw_pivot.rotation.y = cam_yaw
	_pitch_pivot.rotation.x = cam_pitch


func _camera_update(delta: float, inp: Dictionary) -> void:
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look.length() > 0.1 and not bot:
		cam_yaw -= look.x * 2.8 * delta
		cam_pitch = clampf(cam_pitch - look.y * 2.0 * delta, -1.1, 0.5)
	if inp.get("lock", false):
		if lock_target != null and is_instance_valid(lock_target):
			lock_target = null
		else:
			lock_target = _nearest_enemy(25.0)
		if net_role == "local_client" and arena != null:
			arena.call("net_act", ACT_LOCK, Vector2.ZERO)
	if lock_target != null:
		if not is_instance_valid(lock_target) or lock_target.dead:
			lock_target = null
		else:
			var d: Vector3 = lock_target.global_position - global_position
			cam_yaw = lerp_angle(cam_yaw, atan2(-d.x, -d.z), clampf(delta * 6.0, 0.0, 1.0))
	_yaw_pivot.global_position = _yaw_pivot.global_position.lerp(global_position + Vector3(0, 1.7, 0), clampf(delta * 14.0, 0.0, 1.0))
	_yaw_pivot.rotation.y = cam_yaw
	_pitch_pivot.rotation.x = cam_pitch
	var s := shake * 0.12
	camera.h_offset = randf_range(-s, s)
	camera.v_offset = randf_range(-s, s)


func _cam_basis() -> Basis:
	return Basis(Vector3.UP, cam_yaw)


func _movement(delta: float, inp: Dictionary) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif inp.get("jump", false) and state != "dodge":
		velocity.y = 8.8
	var mv: Vector2 = inp["move"]
	var dir := (_cam_basis() * Vector3(mv.x, 0, mv.y))
	var spd: float = stats["move_speed"]
	if inp.get("sprint", false) and mv.length() > 0.1:
		spd *= 1.45
	if state == "attack":
		spd *= 0.45
	if blocking:
		spd *= 0.5
	match state:
		"dodge":
			dodge_t -= delta
			var k := clampf(dodge_t / 0.42, 0.0, 1.0)
			velocity.x = dodge_dir.x * 15.0 * (0.4 + 0.6 * k)
			velocity.z = dodge_dir.z * 15.0 * (0.4 + 0.6 * k)
			if dodge_t <= 0.0:
				state = "idle"
		_:
			velocity.x = move_toward(velocity.x, dir.x * spd, 60.0 * delta)
			velocity.z = move_toward(velocity.z, dir.z * spd, 60.0 * delta)
	move_and_slide()
	# Ausrichtung
	if state != "dodge":
		var face_dir := dir
		if state == "attack" or lock_target != null or inp.get("light", false):
			face_dir = Vector3(-sin(_aim_yaw_target()), 0, -cos(_aim_yaw_target()))
		if face_dir.length() > 0.1:
			var target_yaw := atan2(face_dir.x, face_dir.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * 14.0, 0.0, 1.0))
	_walk_phase += Vector2(velocity.x, velocity.z).length() * delta * 1.7


func _aim_yaw_target() -> float:
	var t := _aim_target()
	if t != null:
		var d := t.global_position - global_position
		return atan2(-d.x, -d.z)
	return cam_yaw


## Zielhilfe: nächster Gegner im Blickkegel (±40°) – sonst Kamerarichtung.
func _aim_target() -> Node3D:
	if lock_target != null and is_instance_valid(lock_target) and not lock_target.dead:
		return lock_target
	var best: Node3D = null
	var best_d := 14.0
	var fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead:
			continue
		var d: Vector3 = e.global_position - global_position
		d.y = 0.0
		var dist := d.length()
		if dist < best_d and dist > 0.1 and rad_to_deg(fwd.angle_to(d)) < 40.0:
			best_d = dist
			best = e
	return best


func _nearest_downed_ally() -> Node3D:
	var best: Node3D = null
	var best_d := 60.0
	for grp in ["player", "puppets"]:
		for a in get_tree().get_nodes_in_group(grp):
			if a == self or not is_instance_valid(a) or not a.is_down() or a.permadown:
				continue
			var d: float = a.global_position.distance_to(global_position)
			if d < best_d:
				best_d = d
				best = a
	return best


func _nearest_enemy(max_dist: float) -> Node3D:
	var best: Node3D = null
	var best_d := max_dist
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


# ------------------------------------------------------------------ Kampf

func _combat(delta: float, inp: Dictionary) -> void:
	# Blocken / Parieren
	var want_block: bool = inp.get("block", false) and state != "dodge" and state != "attack"
	if want_block and not blocking:
		block_t = 0.0
	blocking = want_block
	# Ausweichen
	if inp.get("dodge", false) and dodge_cd <= 0.0 and state != "dodge":
		_start_dodge(inp)
	# Fähigkeiten
	for i in 4:
		if inp["skills"][i] and i < skill_slots.size() and state != "dodge":
			cast_skill(skill_slots[i])
	# Angriffe
	if state == "attack":
		attack_t -= delta
		var progress := 1.0 - attack_t / attack_dur
		if not attack_hit_done and progress >= 0.38:
			attack_hit_done = true
			_do_attack_hit()
		if attack_t <= 0.0:
			state = "idle"
	elif state == "idle" and not blocking:
		if inp.get("heavy", false):
			_start_attack("heavy")
		elif inp.get("light", false):
			_start_attack("light")


func _start_attack(kind: String) -> void:
	state = "attack"
	attack_kind = kind
	attack_hit_done = false
	var w := weapon_def()
	var dur: float = float(w["dur"]) / (float(w["speed"]) * stats["attack_speed"])
	if kind == "heavy":
		dur *= 1.9
	elif has_flag("heavy_light_attacks"):
		dur *= 1.5
	attack_dur = dur
	attack_t = dur
	combo = (combo + 1) if combo_timer > 0.0 else 1
	if combo > 3:
		combo = 1
	combo_timer = dur + 0.5
	var t := _aim_yaw_target()
	_aim_yaw = t
	rotation.y = atan2(-sin(t), -cos(t))
	Sfx.play("swing", 1.0 + 0.08 * combo, -6.0)


func _do_attack_hit() -> void:
	var w := weapon_def()
	var heavy := attack_kind == "heavy"
	var mult: float = float(w["mult"])
	if heavy:
		mult *= 2.2
	elif has_flag("heavy_light_attacks"):
		mult *= 1.6
	elif combo == 3:
		mult *= 1.35
	if empowered:
		mult *= 1.6
		empowered = false
	var fwd := Vector3(-sin(_aim_yaw), 0, -cos(_aim_yaw))
	if w["ranged"]:
		_fire_weapon(fwd, mult, heavy)
		return
	var reach: float = float(w["range"]) * stats["area"] * (1.2 if heavy else 1.0)
	var arc: float = float(w["arc"]) * (1.15 if skill_lv("wide_strikes") >= 4 else 1.0)
	if has_flag("heavy_light_attacks") and not heavy:
		arc = 360.0
	if heavy:
		arc = maxf(arc, 200.0)
	var hits := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead:
			continue
		var d: Vector3 = e.global_position - global_position
		d.y = 0.0
		var dist: float = d.length() - 0.4 * e.model_scale
		if dist > reach:
			continue
		if arc < 359.0 and rad_to_deg(fwd.angle_to(d)) > arc * 0.5 and d.length() > 0.8:
			continue
		var dealt := deal_damage(e, stats["damage"] * mult, "melee", ["melee"], global_position, 7.0 if heavy else 4.0)
		hits += 1
		if dealt > 0.0 and stats["lifesteal"] > 0.0:
			_heal(dealt * stats["lifesteal"], skill_lv("vampiric") >= 4)
	# Wuchtiger Effekt
	var fx_pos := global_position + fwd * reach * 0.55 + Vector3(0, 1.0, 0)
	FX.ring(arena, global_position + fwd * reach * 0.4, reach * 0.8, Color(character.get("appearance", {}).get("accent", "#4ecdc4")), 0.25, 0.1, 0.4)
	if heavy or has_flag("heavy_light_attacks"):
		FX.ring(arena, global_position, reach, Color("#fff2c0"), 0.3, 0.08, 0.3)
	if hits > 0:
		shake = maxf(shake, 0.35 if heavy else 0.2)
		Sfx.play("hit", 1.0, -4.0)
	else:
		FX.burst(arena, fx_pos, Color("#ffffff"), 3, 2.0, 0.05, 0.2)


func _fire_weapon(fwd: Vector3, mult: float, heavy: bool) -> void:
	var from := global_position + Vector3(0, 1.3, 0) + fwd * 0.7
	var target := _aim_target()
	var dir := fwd
	if target != null:
		dir = (target.global_position + Vector3(0, 1.0, 0) - from).normalized()
	var pr := Projectile.new()
	pr.owner_player = self
	if weapon_type == "bow":
		pr.damage = stats["damage"] * mult * (1.6 if heavy else 1.0)
		pr.category = "ranged"
		pr.tags = ["ranged"]
		pr.pierce = 2 if heavy else 0
		pr.setup(arena, from, dir * 32.0, Color("#e8e0b0"), 0.12)
		pr.radius = 0.3
	else:
		pr.damage = stats["damage"] * mult * (1.5 if heavy else 1.0)
		pr.category = "elem"
		pr.tags = ["elem"]
		pr.homing_to = target
		pr.explode_radius = 1.6 if heavy else 0.0
		pr.setup(arena, from, dir * 22.0, Color(character.get("appearance", {}).get("accent", "#4ecdc4")), 0.2)
		pr.radius = 0.35
	pr.life = 1.6
	Sfx.play("cast", 1.2, -9.0)


## Zentrale Schadensberechnung für alle Spielerangriffe (Server-Autorität später: dieser Code läuft dann nur dort).
func deal_damage(e: Node, base: float, category: String, tags: Array, from_pos: Vector3, knock: float = 0.0) -> float:
	if e == null or not is_instance_valid(e) or e.dead:
		return 0.0
	var amount := base * float(stats["cat_mult"].get(category, 1.0)) * aura_dmg_mult
	var hp_ratio: float = e.hp / e.max_hp
	amount *= RunMods.executioner_mult(levels, hp_ratio)
	if skill_lv("frost_nova") >= 3 and e.slow_t > 0.0 and "frost" in tags:
		amount *= 1.2
	if "fire" in tags and "steam_burst" in active_evolutions and e.slow_t > 0.0:
		amount *= 1.6
		FX.burst(arena, e.global_position + Vector3(0, 1, 0), Color("#e0f0ff"), 8, 3.0, 0.2, 0.6)
	var force := RunMods.executioner_forces_crit(levels, hp_ratio)
	var bz := skill_lv("berserker")
	if bz > 0:
		amount *= 1.0 + (1.0 - clampf(hp / maxf(stats["max_hp"], 1.0), 0.0, 1.0)) * 0.3 * bz
	var r := Stats.roll_damage(amount, stats["crit_chance"], stats["crit_mult"], rng, force)
	e.last_hit_by = self
	var dealt: float = e.take_damage(r["amount"], r["crit"], from_pos, knock)
	run_stats["damage_dealt"] += dealt
	if r["crit"]:
		Sfx.play("crit", 1.0, -6.0)
	if arena != null and arena.get("net_on") == true:
		CoopCombos.on_hit(self, e, tags, dealt)
	return dealt


func _heal(amount: float, to_shield: bool = false) -> void:
	var a: float = amount * float(stats["heal_power"])
	if hp >= stats["max_hp"] and to_shield:
		shield = minf(shield + a, stats["max_hp"] * 0.2)
		return
	hp = minf(hp + a, stats["max_hp"])


func heal(amount: float) -> void:
	run_stats["healing"] += amount * float(stats["heal_power"])
	_heal(amount)
	FX.float_text(arena, global_position, "+%d" % int(amount), Color("#7dffb0"), 40)


func _start_dodge(inp: Dictionary) -> void:
	var mv: Vector2 = inp["move"]
	var dir := _cam_basis() * Vector3(mv.x, 0, mv.y)
	if dir.length() < 0.1:
		dir = Vector3(sin(rotation.y), 0, cos(rotation.y))
	dodge_dir = dir.normalized()
	state = "dodge"
	dodge_t = 0.42
	iframes = stats["dodge_iframes"]
	dodge_cd = 0.75 * (0.8 if skill_lv("swift") >= 3 else 1.0)
	rotation.y = atan2(dodge_dir.x, dodge_dir.z)
	if net_role == "local_client":
		return   # Bewegung ist vorhergesagt; Effekte (Frost, Ton, Partikel) entstehen auf dem Host und kommen als Ereignis
	Sfx.play("roll", 1.0, -6.0)
	FX.burst(arena, global_position + Vector3(0, 0.2, 0), Color("#e8e8d0"), 6, 2.5, 0.1, 0.4)
	if has_flag("dodge_empower"):
		empowered = true
	var fl := skill_lv("frost_dodge")
	if fl > 0:
		FX.ring(arena, global_position, 4.5, Color("#9fe0ff"), 0.4)
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and not e.dead and e.global_position.distance_to(global_position) <= 4.5:
				e.apply_slow(2.5, 0.5)
				if fl >= 2:
					deal_damage(e, stats["damage"] * 1.0, "elem", ["frost"], global_position)
		if fl >= 3:
			frost_shield_t = 2.5
	if "storm_aegis" in active_evolutions:
		cast_skill("chain_lightning", true)


func take_damage(amount: float, from_pos: Vector3) -> void:
	if state == "down" or iframes > 0.0 or net_away:
		return
	var a := amount * bot_damage_scale
	if blocking:
		var window := 0.22 * (1.5 if skill_lv("iron_will") >= 2 else 1.0)
		if block_t <= window:
			_parry(from_pos)
			return
		a *= 0.25
		Sfx.play("hit", 0.6, -6.0)
	if frost_shield_t > 0.0:
		a *= 0.4
	a = Stats.mitigate(a, stats["defense"])
	if shield > 0.0:
		var absorbed := minf(shield, a)
		shield -= absorbed
		a -= absorbed
	hp -= a
	run_stats["damage_taken"] += a
	_shield_idle = 0.0
	var th := skill_lv("thorns")
	if th > 0:
		FX.ring(arena, global_position, 3.2, Color("#c8a0ff"), 0.25)
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and not e.dead and e.global_position.distance_to(global_position) <= 3.2 + 0.4 * e.model_scale:
				deal_damage(e, a * (0.6 + 0.4 * th) + stats["damage"] * 0.5, "elem", ["thorns", "area"], global_position, 3.0)
	shake = maxf(shake, 0.6)
	FX.float_text(arena, global_position, str(int(roundf(a))), Color("#ff6a6a"), 44)
	Sfx.play("hurt", 1.0, -3.0)
	FX.burst(arena, global_position + Vector3(0, 1.1, 0), Color("#ff5a5a"), 8, 4.0)
	arena.call("on_player_hurt", self)
	if hp <= 0.0:
		hp = 0.0
		state = "down"
		blocking = false
		bleed_t = BLEED_TIME
		revive_progress = 0.0
		run_stats["downs"] += 1
		died_signal.emit()


func _parry(from_pos: Vector3) -> void:
	Sfx.play("crit", 0.7, -3.0)
	FX.ring(arena, global_position, 4.0, Color("#fff2a0"), 0.35)
	shake = 0.3
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead and e.global_position.distance_to(global_position) <= 4.0:
			e.apply_stun(1.2)
			if skill_lv("iron_will") >= 3:
				deal_damage(e, stats["damage"] * 1.5, "melee", ["melee"], global_position, 8.0)
	if skill_lv("iron_will") >= 3:
		heal(stats["max_hp"] * 0.08)


# ------------------------------------------------------------------ Aktive Fähigkeiten

func skill_cooldown(id: String) -> float:
	var base: float = float(GameData.skills[id].get("cooldown", 5.0))
	if id == "frost_nova" and skill_lv(id) >= 5:
		base *= 0.7
	return Stats.level_cooldown(base, stats["cooldown_reduction"])


func cast_skill(id: String, free: bool = false) -> bool:
	if not free:
		if cooldowns.get(id, 0.0) > 0.0:
			return false
		var cost: float = float(GameData.skills[id].get("mana", 10))
		if mana < cost:
			if arena != null:
				arena.call("notify_low_mana")
			return false
		mana -= cost
		cooldowns[id] = skill_cooldown(id)
	cast_anim_t = 0.45
	_cast_once(id, 1.0)
	if skill_lv("twin_cast") > 0 and id != "spirit_wisps":
		var m := 0.35 if skill_lv("twin_cast") == 1 else 0.6
		get_tree().create_timer(0.3, false).timeout.connect(func(): if state != "down" and is_inside_tree(): _cast_once(id, m))
	Sfx.play("cast", 1.0, -4.0)
	return true


func _skill_base() -> float:
	return stats["damage"] * 2.4


func _cast_once(id: String, dmg_mult: float) -> void:
	var lv := skill_lv(id)
	if lv <= 0:
		lv = 1
	var fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var tgt := _aim_target()
	if tgt != null:
		fwd = (tgt.global_position - global_position)
		fwd.y = 0.0
		fwd = fwd.normalized()
	match id:
		"fireball": _cast_fireball(lv, fwd, tgt, dmg_mult)
		"frost_nova": _cast_frost_nova(lv, dmg_mult)
		"chain_lightning": _cast_chain(lv, dmg_mult)
		"earthquake": _cast_earthquake(lv, dmg_mult)
		"spirit_wisps": _refresh_wisps(true)
		"blade_storm": _cast_blade_storm(lv, dmg_mult)
		"poison_cloud": _cast_poison_cloud(lv, fwd, tgt, dmg_mult)
		"ice_lance": _cast_ice_lance(lv, fwd, tgt, dmg_mult)
		"thunder_strike": _cast_thunder(lv, dmg_mult)
		"meteor_rain": _cast_meteor_rain(lv, fwd, tgt, dmg_mult)
		"void_singularity": _cast_void(lv, fwd, tgt, dmg_mult)
		"holy_nova": _cast_holy_nova(lv, dmg_mult)


func _cast_fireball(lv: int, fwd: Vector3, tgt: Node3D, mult: float) -> void:
	var from := global_position + Vector3(0, 1.3, 0) + fwd * 0.8
	var dmg := _skill_base() * mult
	if has_flag("fireball_meteor"):
		var spot := global_position + fwd * 8.0
		if tgt != null:
			spot = tgt.global_position
		var r := 3.0 + 0.4 * lv
		var tele := FX.telegraph(arena, spot, r, 0.7, Color("#ff9a3a"))
		get_tree().create_timer(0.7, false).timeout.connect(func():
			if is_instance_valid(tele):
				tele.queue_free()
			_area_hit(spot, r, dmg * 1.4, "elem", ["fire"], 6.0, 3.0 if lv >= 4 else 0.0)
			FX.ring(arena, spot, r, Color("#ff7a2a"), 0.5)
			FX.burst(arena, spot + Vector3(0, 0.5, 0), Color("#ffb040"), 26, 9.0, 0.2, 0.7)
			shake = 0.5
			Sfx.play("boom", 0.7, -2.0))
		return
	var pr := Projectile.new()
	pr.owner_player = self
	pr.damage = dmg
	pr.category = "elem"
	pr.tags = ["fire", "projectile"]
	pr.explode_radius = 2.2 if lv < 2 else 3.0
	pr.pierce = 2 if lv >= 3 else 0
	pr.life = 2.0
	pr.radius = 0.4 if lv < 2 else 0.55
	var size := 0.28 if lv < 2 else 0.4
	pr.setup(arena, from, fwd * 19.0, Color("#ff8a2a"), size)
	pr.homing_to = tgt
	if lv >= 4:
		pr.on_impact = func(pos: Vector3): _fire_zone(pos, lv)
	if lv >= 5:
		var split_dmg := dmg * 0.45
		var prev: Callable = pr.on_impact
		pr.on_impact = func(pos: Vector3):
			if prev.is_valid():
				prev.call(pos)
			for i in 3:
				var a := i * TAU / 3.0 + randf() * 0.5
				var s := Projectile.new()
				s.owner_player = self
				s.damage = split_dmg
				s.category = "elem"
				s.tags = ["fire", "projectile"]
				s.explode_radius = 1.6
				s.life = 0.6
				s.radius = 0.3
				s.setup(arena, pos + Vector3(0, 0.6, 0), Vector3(cos(a), 0.1, sin(a)) * 11.0, Color("#ffb040"), 0.18)


func _fire_zone(pos: Vector3, lv: int) -> void:
	var radius := 2.6
	var ticks := 6
	var zone := FX.zone(arena, pos, radius, Color("#ff6a1a"), 0.5 * ticks + 0.1)
	for i in ticks:
		get_tree().create_timer(0.5 * (i + 1), false).timeout.connect(func():
			if not is_instance_valid(zone):
				return
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e) and not e.dead and e.global_position.distance_to(zone.global_position) <= radius + 0.4 * e.model_scale:
					deal_damage(e, stats["damage"] * 0.55, "elem", ["fire", "dot"], zone.global_position)
					e.apply_burn(2.0, stats["damage"] * 0.3)
			FX.burst(arena, zone.global_position + Vector3(0, 0.3, 0), Color("#ff8a2a"), 4, 2.0, 0.1, 0.4))


func _area_hit(center: Vector3, radius: float, dmg: float, category: String, tags: Array, knock: float = 0.0, burn: float = 0.0) -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead and e.global_position.distance_to(center) <= radius + 0.5 * e.model_scale:
			deal_damage(e, dmg, category, tags, center, knock)
			if burn > 0.0:
				e.apply_burn(burn, stats["damage"] * 0.3)
			n += 1
	return n


func _cast_frost_nova(lv: int, mult: float) -> void:
	var r: float = (6.0 if lv < 2 else 7.5) * stats["area"]
	var slow_m := 0.25 if lv >= 5 else 0.4
	FX.ring(arena, global_position, r, Color("#9fe0ff"), 0.5, 0.15)
	FX.ring(arena, global_position, r * 0.6, Color("#e8faff"), 0.35, 0.15)
	FX.burst(arena, global_position + Vector3(0, 0.4, 0), Color("#c8f0ff"), 24, 8.0, 0.15, 0.7)
	FX.shards(arena, global_position, r * 0.85, Color("#bfe8ff"), 22, 1.6)
	FX.dust(arena, global_position, r * 0.5, Color("#d8f4ff"))
	shake = 0.3
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead and e.global_position.distance_to(global_position) <= r + 0.5 * e.model_scale:
			deal_damage(e, _skill_base() * 0.8 * mult, "elem", ["frost", "area"], global_position, 3.0)
			e.apply_slow(4.0, slow_m)
			if lv >= 4 and e.global_position.distance_to(global_position) <= r * 0.4:
				e.apply_freeze(1.3)


func _cast_chain(lv: int, mult: float) -> void:
	var jumps := 3 if lv == 1 else 5
	var jump_range: float = (7.0 if lv < 3 else 9.5) * float(stats["area"])
	var dmg_mult := 1.0 if lv < 3 else 1.3
	var from := global_position + Vector3(0, 1.4, 0)
	var hit_list: Array = []
	var cur: Node3D = _nearest_enemy(jump_range + 4.0)
	var n := 0
	while cur != null and n < jumps:
		var to := cur.global_position + Vector3(0, 1.0, 0)
		FX.bolt(arena, from, to, Color("#a8c8ff"), 0.28, 0.06)
		FX.burst(arena, to, Color("#cfe2ff"), 6, 4.0, 0.08, 0.3)
		deal_damage(cur, _skill_base() * 0.9 * dmg_mult * mult, "elem", ["lightning", "chain"], global_position)
		if lv >= 4:
			cur.mark_t = 5.0
		hit_list.append(cur)
		from = to
		n += 1
		var nxt: Node3D = null
		var bd: float = jump_range
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e) or e.dead or e == cur:
				continue
			if e in hit_list and not (lv >= 5 and hit_list.count(e) < 2):
				continue
			var d: float = e.global_position.distance_to(cur.global_position)
			if d < bd:
				bd = d
				nxt = e
		cur = nxt
	if n == 0:
		FX.beam(arena, from, from + Vector3(-sin(cam_yaw), 0, -cos(cam_yaw)) * 6.0, Color("#d8e8ff"), 0.15, 0.04)


func _cast_earthquake(lv: int, mult: float) -> void:
	var r: float = (7.5 if lv < 2 else 10.0) * stats["area"]
	var d := _skill_base() * (1.7 if lv < 2 else 2.2) * mult
	_quake(global_position, r, d, lv >= 3)
	if lv >= 4:
		var pos := global_position
		get_tree().create_timer(1.2, false).timeout.connect(func(): if is_inside_tree(): _quake(pos, r * 0.8, d * 0.6, false))


func _quake(center: Vector3, r: float, d: float, stun: bool) -> void:
	FX.ring(arena, center, r, Color("#c8a070"), 0.6, 0.2)
	FX.ring(arena, center, r * 0.55, Color("#e0c090"), 0.45, 0.2)
	FX.burst(arena, center + Vector3(0, 0.3, 0), Color("#8a6a3a"), 30, 9.0, 0.22, 0.8)
	FX.shards(arena, center, r * 0.9, Color("#6e5638"), 18, 1.3)
	FX.dust(arena, center, r, Color("#a08462"))
	Sfx.play("boom", 0.6, -1.0)
	shake = 0.8
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead and e.global_position.distance_to(center) <= r + 0.5 * e.model_scale:
			deal_damage(e, d, "elem", ["earth", "area", "heavy"], center, 9.0)
			if stun:
				e.apply_stun(2.0)


# ------------------------------------------------------------------ Neue Fähigkeiten

func _poison_zone_at(pos: Vector3) -> bool:
	for z in get_tree().get_nodes_in_group("poison_zones"):
		if is_instance_valid(z) and z.global_position.distance_to(pos) < 4.0:
			return true
	return false


func _cast_blade_storm(lv: int, mult: float) -> void:
	var r: float = (3.6 + 0.3 * lv) * stats["area"]
	var ticks := 6 + lv
	var dur := 0.14
	var d := _skill_base() * (0.45 + 0.06 * lv) * mult
	for i in ticks:
		get_tree().create_timer(dur * i, false).timeout.connect(func():
			if state == "down" or not is_inside_tree():
				return
			var a := i * 1.9
			FX.ring(arena, global_position, r, Color("#d8e4f0"), 0.22, 0.1)
			FX.beam(arena, global_position + Vector3(0, 1.0, 0), global_position + Vector3(cos(a), 1.0, sin(a)) * r, Color("#eef4ff"), 0.14, 0.09)
			FX.beam(arena, global_position + Vector3(0, 1.0, 0), global_position - Vector3(cos(a), -1.0, sin(a)) * r, Color("#eef4ff"), 0.14, 0.09)
			Sfx.play("swing", 1.1 + i * 0.03, -9.0)
			_area_hit(global_position, r, d, "melee", ["melee", "area"], 3.0))


func _cast_poison_cloud(lv: int, fwd: Vector3, tgt: Node3D, mult: float) -> void:
	var spot := global_position + fwd * 6.0
	if tgt != null:
		spot = tgt.global_position
	var r: float = (3.2 + 0.3 * lv) * stats["area"]
	var life := 5.0 + lv
	var dps: float = stats["damage"] * (0.9 + 0.2 * lv) * mult
	var zone := FX.zone(arena, spot, r, Color("#6bd84a"), life)
	if zone != null:
		zone.add_to_group("poison_zones")
	var n := int(life / 0.5)
	for i in n:
		get_tree().create_timer(0.5 * (i + 1), false).timeout.connect(func():
			if not is_instance_valid(zone) or not is_inside_tree():
				return
			FX.dust(arena, spot, r * 0.7, Color("#8aff6a"))
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e) and not e.dead and e.global_position.distance_to(spot) <= r + 0.4 * e.model_scale:
					deal_damage(e, dps * 0.5, "elem", ["poison", "dot"], spot)
					e.apply_poison(3.0, dps * (0.6 if lv < 4 else 0.9))
					if lv >= 3:
						e.apply_slow(1.0, 0.75))


func _cast_ice_lance(lv: int, fwd: Vector3, tgt: Node3D, mult: float) -> void:
	var count := 1 if lv < 3 else (2 if lv < 5 else 3)
	var spread := 0.0 if count == 1 else 0.14
	var from := global_position + Vector3(0, 1.3, 0)
	for i in count:
		var ang := (i - (count - 1) * 0.5) * spread
		var dir := fwd.rotated(Vector3.UP, ang)
		var pr := Projectile.new()
		pr.owner_player = self
		pr.damage = _skill_base() * (1.15 + 0.12 * lv) * mult
		pr.category = "elem"
		pr.tags = ["frost", "projectile"]
		pr.pierce = 2 + (1 if lv >= 4 else 0)
		pr.life = 1.4
		pr.radius = 0.4
		pr.setup(arena, from + dir * 0.8, dir * 32.0, Color("#bfeaff"), 0.22)
		pr.homing_to = tgt if count == 1 else null
		pr.on_impact = func(pos: Vector3):
			FX.burst(arena, pos + Vector3(0, 0.6, 0), Color("#d8f4ff"), 8, 4.0, 0.1, 0.4)
			FX.shards(arena, pos, 1.6, Color("#bfe8ff"), 6, 0.8)
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e) and not e.dead and e.global_position.distance_to(pos) <= 1.6:
					e.apply_slow(2.5, 0.55)


func _cast_thunder(lv: int, mult: float) -> void:
	var strikes := 2 + lv
	var r := 2.3 * float(stats["area"])
	var d := _skill_base() * (1.5 + 0.2 * lv) * mult
	var targets: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead and e.global_position.distance_to(global_position) < 22.0:
			targets.append(e)
	targets.sort_custom(func(a, b): return a.global_position.distance_to(global_position) < b.global_position.distance_to(global_position))
	for i in strikes:
		var spot: Vector3
		if i < targets.size():
			spot = targets[i].global_position
		else:
			var a := randf() * TAU
			spot = global_position + Vector3(cos(a), 0, sin(a)) * randf_range(4.0, 9.0)
		var tele := FX.telegraph(arena, spot, r, 0.55, Color("#bcd0ff"))
		get_tree().create_timer(0.55 + 0.12 * i, false).timeout.connect(func():
			if is_instance_valid(tele):
				tele.queue_free()
			if not is_inside_tree():
				return
			FX.pillar(arena, spot, Color("#d8e4ff"), 14.0, 0.8, 0.35)
			FX.ring(arena, spot, r, Color("#a8c8ff"), 0.35, 0.15)
			FX.burst(arena, spot + Vector3(0, 0.5, 0), Color("#e8f0ff"), 16, 7.0, 0.12, 0.5)
			FX.scorch(arena, spot, r * 0.8, Color("#334466"), 2.5)
			Sfx.play("boom", 1.3, -4.0)
			shake = maxf(shake, 0.4)
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e) and not e.dead and e.global_position.distance_to(spot) <= r + 0.5 * e.model_scale:
					var boost := 1.0
					var stun := 0.8 if lv < 4 else 1.4
					if "storm_front" in active_evolutions and e.slow_t > 0.0:
						boost = 1.5
						stun += 0.8
					deal_damage(e, d * boost, "elem", ["lightning", "area"], spot, 4.0)
					e.apply_stun(stun))


func _cast_meteor_rain(lv: int, fwd: Vector3, tgt: Node3D, mult: float) -> void:
	var center := global_position + fwd * 7.0
	if tgt != null:
		center = tgt.global_position
	var count := 4 + lv
	var r := 2.4 * float(stats["area"])
	var d := _skill_base() * (1.8 + 0.25 * lv) * mult
	for i in count:
		var spot := center + Vector3(randf_range(-5.0, 5.0), 0, randf_range(-5.0, 5.0))
		var delay := 0.5 + 0.28 * i
		var tele := FX.telegraph(arena, spot, r, delay, Color("#ff7a2a"))
		get_tree().create_timer(delay, false).timeout.connect(func():
			if is_instance_valid(tele):
				tele.queue_free()
			if not is_inside_tree():
				return
			FX.pillar(arena, spot, Color("#ff9a3a"), 12.0, 0.9, 0.3)
			FX.ring(arena, spot, r, Color("#ff7a2a"), 0.45, 0.2)
			FX.burst(arena, spot + Vector3(0, 0.5, 0), Color("#ffb040"), 24, 8.0, 0.2, 0.7)
			FX.cracks(arena, spot, r * 1.1, Color("#ff6a1a"), 7, 1.2)
			FX.scorch(arena, spot, r * 0.8, Color("#2a1a12"), 3.0)
			Sfx.play("boom", 0.8, -3.0)
			shake = maxf(shake, 0.5)
			var boost := 1.0
			if "toxic_inferno" in active_evolutions and _poison_zone_at(spot):
				boost = 1.5
				FX.ring(arena, spot, r * 1.6, Color("#9aff4a"), 0.6, 0.2)
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e) and not e.dead and e.global_position.distance_to(spot) <= r + 0.5 * e.model_scale:
					deal_damage(e, d * boost, "elem", ["fire", "area"], spot, 6.0)
					e.apply_burn(3.0, stats["damage"] * 0.4))


func _cast_void(lv: int, fwd: Vector3, tgt: Node3D, mult: float) -> void:
	var spot := global_position + fwd * 6.0
	if tgt != null:
		spot = tgt.global_position
	var r: float = (6.0 + 0.5 * lv) * stats["area"]
	var life := 2.6 + 0.3 * lv
	var tick_d := _skill_base() * (0.25 + 0.04 * lv) * mult
	var zone := FX.zone(arena, spot, r * 0.5, Color("#9a4aff"), life)
	FX.pillar(arena, spot, Color("#7a2aff"), 8.0, 0.6, life)
	var n := int(life / 0.25)
	for i in n:
		get_tree().create_timer(0.25 * i, false).timeout.connect(func():
			if not is_inside_tree():
				return
			FX.burst(arena, spot + Vector3(0, 0.6, 0), Color("#b07aff"), 3, 3.0, 0.1, 0.4)
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e) and not e.dead:
					var dv: Vector3 = spot - e.global_position
					dv.y = 0.0
					if dv.length() <= r and not e.is_mini and not e._is_boss():
						e._knock += dv.normalized() * minf(dv.length(), 2.5) * 1.6
					if dv.length() <= r * 0.5:
						deal_damage(e, tick_d, "elem", ["void", "area", "dot"], spot))
	get_tree().create_timer(life, false).timeout.connect(func():
		if not is_inside_tree():
			return
		FX.ring(arena, spot, r, Color("#c09aff"), 0.5, 0.2)
		FX.burst(arena, spot + Vector3(0, 0.6, 0), Color("#d8baff"), 30, 10.0, 0.2, 0.8)
		Sfx.play("boom", 0.5, -1.0)
		shake = maxf(shake, 0.7)
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and not e.dead and e.global_position.distance_to(spot) <= r:
				deal_damage(e, _skill_base() * (2.2 + 0.4 * lv) * mult, "elem", ["void", "area"], spot, 5.0))
	if zone == null:
		return


func _cast_holy_nova(lv: int, mult: float) -> void:
	var r: float = (6.0 + 0.5 * lv) * stats["area"]
	FX.ring(arena, global_position, r, Color("#fff0a0"), 0.55, 0.2)
	FX.ring(arena, global_position, r * 0.55, Color("#ffffff"), 0.4, 0.2)
	FX.pillar(arena, global_position, Color("#fff2b0"), 9.0, 1.0, 0.4)
	FX.burst(arena, global_position + Vector3(0, 0.6, 0), Color("#fff2b0"), 26, 7.0, 0.15, 0.7)
	Sfx.play("crit", 0.9, -4.0)
	var hit := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead and e.global_position.distance_to(global_position) <= r + 0.5 * e.model_scale:
			deal_damage(e, _skill_base() * (0.7 + 0.1 * lv) * mult, "elem", ["holy", "area"], global_position, 4.0)
			hit += 1
	var amount: float = stats["max_hp"] * (0.10 + 0.03 * lv) * mult + float(mini(hit, 6)) * 2.0
	for grp in ["player", "puppets"]:
		for a in get_tree().get_nodes_in_group(grp):
			if is_instance_valid(a) and not a.is_down() and a.global_position.distance_to(global_position) <= r + 2.0:
				if a == self:
					heal(amount)
				else:
					if a.has_method("heal"):
						a.call("heal", amount)


# ------------------------------------------------------------------ Geisterlichter

func _wisp_count() -> int:
	var lv := skill_lv("spirit_wisps")
	if lv <= 0:
		return 0
	return [2, 3, 3, 3, 4][mini(lv, 5) - 1] + int(stats["summon_count"])


func _refresh_wisps(recast: bool = false) -> void:
	var lv := skill_lv("spirit_wisps")
	if lv <= 0:
		return
	var duration := 15.0 if lv < 3 else 22.0
	for w in wisps:
		if is_instance_valid(w):
			w.queue_free()
	wisps.clear()
	var n := _wisp_count()
	for i in n:
		var w := Wisp.new()
		w.owner_player = self
		w.index = i
		w.count = n
		w.life = duration
		w.top_level = true
		w.global_position = global_position + Vector3(0, 1.5, 0)
		arena.add_child(w)
		wisps.append(w)


# ------------------------------------------------------------------ Tod von Gegnern

func on_enemy_killed(e: Enemy) -> void:
	var sh := skill_lv("soul_harvest")
	if sh > 0:
		mana = minf(mana + 2.0 + 1.5 * sh, stats["mana_max"])
		if sh >= 3 and rng.randf() < 0.25:
			_heal(stats["max_hp"] * 0.02 * sh)
		FX.burst(arena, e.global_position + Vector3(0, 1, 0), Color("#9affd0"), 4, 3.0, 0.08, 0.5)
	var vc := skill_lv("volatile_corpses")
	if vc > 0:
		var r := 2.8 if vc < 2 else 4.0
		var d: float = stats["damage"] * (1.2 if vc < 2 else 1.9)
		FX.ring(arena, e.global_position, r, Color("#ff7a2a"), 0.3)
		FX.burst(arena, e.global_position + Vector3(0, 0.6, 0), Color("#ffb040"), 10, 5.0)
		for o in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(o) and not o.dead and o != e and o.global_position.distance_to(e.global_position) <= r:
				deal_damage(o, d, "elem", ["fire", "area"], e.global_position)
				if vc >= 3:
					o.apply_burn(3.0, stats["damage"] * 0.3)


# ------------------------------------------------------------------ Animation

func _animate(delta: float, inp: Dictionary) -> void:
	if model.is_empty():
		return
	if model.has("anim"):
		_animate_rigged(delta)
		return
	var legs: Array = model["legs"]
	var arms: Array = model["arms"]
	var body: Node3D = model["body"]
	var speed_f := clampf(Vector2(velocity.x, velocity.z).length() / 6.0, 0.0, 1.6)
	var swing := sin(_walk_phase * 2.0) * 0.8 * minf(speed_f, 1.0)
	legs[0].rotation.x = swing
	legs[1].rotation.x = -swing
	var weapon: Node3D = model["weapon"]
	if state == "attack":
		var p := clampf(1.0 - attack_t / attack_dur, 0.0, 1.0)
		var e := ease(p, -2.0)
		match combo:
			2: arms[1].rotation = Vector3(lerpf(-1.2, -1.9, e), lerpf(1.2, -0.9, e), lerpf(-0.7, 0.9, e))
			3: arms[1].rotation = Vector3(lerpf(-2.8, 0.3, e), 0.0, 0.0)
			_: arms[1].rotation = Vector3(lerpf(-1.5, -1.5, e), lerpf(-1.1, 1.1, e), lerpf(0.5, -0.5, e))
		arms[0].rotation.x = -0.4
		weapon.rotation.x = 0.0
		body.rotation.y = lerpf(-0.35, 0.35, e) if combo != 3 else 0.0
		body.rotation.x = 0.0
	elif state == "dodge":
		var k := 1.0 - clampf(dodge_t / 0.42, 0.0, 1.0)
		body.rotation.x = k * TAU
		body.position.y = -0.25 * sin(k * PI)
		arms[1].rotation = Vector3(-0.5, 0, 0)
		arms[0].rotation = Vector3(-0.5, 0, 0)
	else:
		body.rotation.x = lerpf(body.rotation.x, 0.0, 0.3)
		body.rotation.y = lerpf(body.rotation.y, 0.0, 0.3)
		body.position.y = lerpf(body.position.y, 0.0, 0.3)
		arms[0].rotation = Vector3(-swing * 0.8, 0, 0.1)
		arms[1].rotation = Vector3(swing * 0.8 if not blocking else -1.3, 0, -0.1)
		if blocking:
			arms[0].rotation = Vector3(-1.4, 0.3, 0.2)
	var glow_c := Color(0.5, 0.8, 1.0)
	_body_tilt = lerpf(_body_tilt, 0.0, 0.2)


## Skelett-Animation (Quaternius Universal Animation Library): Clip nach Zustand wählen, Tempo an Spiel anpassen.
var _air_t := 0.0
var cast_anim_t := 0.0


func _animate_rigged(delta: float) -> void:
	var ap: AnimationPlayer = model["anim"]
	var kk := CharacterModel.is_kaykit(ap)
	var horiz := Vector2(velocity.x, velocity.z).length()
	var melee := weapon_type not in ["staff", "bow"]
	var clip := "Idle"
	var spd := 1.0
	var blend := 0.15
	var one_shot := false
	_air_t = _air_t + delta if (not is_on_floor() and net_role != "puppet") else 0.0
	cast_anim_t = maxf(cast_anim_t - delta, 0.0)
	if state == "down":
		clip = "Death_A" if kk else "Death01"
		blend = 0.2
	elif state == "dodge":
		clip = "Dodge_Forward" if kk else "Roll"
		spd = clampf(ap.get_animation(clip).length / 0.42, 1.0, 4.0)
		blend = 0.05
		one_shot = true
	elif state == "attack":
		if kk:
			clip = CharacterModel.kk_clip("attack", weapon_type, combo)
		else:
			clip = "Sword_Attack" if melee else "Spell_Simple_Shoot"
		var len_c := ap.get_animation(clip).length
		spd = clampf(len_c / maxf(attack_dur, 0.1), 0.8, 3.5)
		blend = 0.06
		one_shot = true
	elif blocking:
		clip = "Blocking" if kk else "Crouch_Idle"
	elif _air_t > 0.1:
		clip = "Jump_Idle" if kk else "Jump"
		blend = 0.1
	elif cast_anim_t > 0.0 and horiz < 2.5:
		clip = "Spellcast_Shoot" if kk else "Spell_Simple_Shoot"
		spd = 1.5
		blend = 0.06
		one_shot = true
	elif horiz > 0.4:
		if horiz < 3.2:
			clip = "Walking_A" if kk else "Walk"
			spd = clampf(horiz / 2.2, 0.6, 1.6)
		elif horiz < 7.5:
			clip = "Running_A" if kk else "Jog_Fwd"
			spd = clampf(horiz / 5.5, 0.7, 1.5)
		else:
			clip = "Running_B" if kk else "Sprint"
			spd = clampf(horiz / 9.0, 0.8, 1.4)
	elif not kk:
		clip = CharacterModel.idle_clip(weapon_type)
	var dead_hold: bool = state == "down" and ap.current_animation == clip
	var changed: bool = ap.current_animation != clip
	if not dead_hold and (changed or (not ap.is_playing() and not one_shot)):
		ap.play(clip, blend)
		if changed:
			ap.seek(0.0, true)
	ap.speed_scale = spd
	if state == "down" and ap.current_animation == clip and ap.current_animation_position > ap.current_animation_length - 0.05:
		ap.pause()


# ------------------------------------------------------------------ Multiplayer: Client-Spieler

## Der Client bewegt sich lokal (Vorhersage). Angriffe und Fähigkeiten löst der Host aus; hier laufen nur Blocken,
## Ausweichen (Bewegung) und das Senden der Aktionen.
func _client_combat(delta: float, inp: Dictionary) -> void:
	var want_block: bool = inp.get("block", false) and state != "dodge" and state != "attack"
	if want_block and not blocking:
		block_t = 0.0
		arena.call("net_act", ACT_BLOCK, Vector2.ZERO)
	blocking = want_block
	if inp.get("dodge", false) and dodge_cd <= 0.0 and state != "dodge" and state != "down":
		_start_dodge(inp)
		arena.call("net_act", ACT_DODGE, inp["move"])
	if inp.get("heavy", false):
		arena.call("net_act", ACT_HEAVY, Vector2.ZERO)
	for i in 4:
		if inp["skills"][i] and i < skill_slots.size():
			arena.call("net_act", ACT_SKILL1 + i, Vector2.ZERO)
	if state == "dodge":
		pass
	elif state == "attack":
		attack_t = maxf(attack_t - delta, 0.0)


## Private Zustandsdaten des eigenen Spielers (vom Host, ca. 20x pro Sekunde).
func net_me_pack() -> Dictionary:
	var cds := {}
	for id in cooldowns:
		cds[id] = snappedf(cooldowns[id], 0.05)
	return {"hp": hp, "mana": mana, "shield": shield, "xp": xp, "level": level, "rerolls": rerolls_left, "cd": cds,
			"slots": skill_slots, "levels": levels, "st": STATE_CODES.find(state), "combo": combo, "at": attack_t,
			"ad": attack_dur, "kind": attack_kind, "bleed": bleed_t, "revive": revive_progress, "perma": permadown,
			"away": net_away, "wisps": wisps.size()}


func apply_net_state(d: Dictionary) -> void:
	hp = d["hp"]
	mana = d["mana"]
	shield = d["shield"]
	xp = d["xp"]
	level = d["level"]
	rerolls_left = d["rerolls"]
	for id in d["cd"]:
		cooldowns[id] = d["cd"][id]
	skill_slots = d["slots"]
	if d["levels"].hash() != levels.hash():
		levels = d["levels"].duplicate()
		recalc(true)
	bleed_t = d["bleed"]
	revive_progress = d["revive"]
	permadown = d["perma"]
	net_away = d["away"]
	wisp_visuals = d["wisps"]
	var host_state: String = STATE_CODES[clampi(d["st"], 0, 3)]
	match host_state:
		"attack":
			if state != "dodge":
				state = "attack"
			attack_t = d["at"]
			attack_dur = maxf(d["ad"], 0.05)
			combo = d["combo"]
			attack_kind = d["kind"]
		"down":
			state = "down"
			blocking = false
		_:
			if state == "attack" or state == "down":
				state = "idle"


# ------------------------------------------------------------------ Multiplayer: Host-Simulation eines Remote-Spielers

func _remote_input() -> Dictionary:
	var inp := {"move": Vector2.ZERO, "jump": false, "sprint": false, "dodge": false, "light": (remote_holds & HOLD_LIGHT) != 0,
			"heavy": false, "block": (remote_holds & HOLD_BLOCK) != 0, "block_press": false,
			"skills": [false, false, false, false], "interact": false, "interact_held": (remote_holds & HOLD_INTERACT) != 0, "lock": false}
	for a in remote_acts:
		var id: int = a[0]
		match id:
			ACT_DODGE:
				inp["dodge"] = true
				inp["move"] = a[1]
			ACT_HEAVY: inp["heavy"] = true
			ACT_INTERACT: inp["interact"] = true
			ACT_LOCK: inp["lock"] = true
			ACT_BLOCK: inp["block_press"] = true
			_:
				if id >= ACT_SKILL1 and id < ACT_SKILL1 + 4:
					inp["skills"][id - ACT_SKILL1] = true
	remote_acts.clear()
	return inp


const REMOTE_SPEED_SLACK := 1.35
const REMOTE_TELEPORT_LIMIT := 14.0


func _remote_step(delta: float) -> void:
	var inp := _remote_input()
	interact_held = inp["interact_held"]
	var down := state == "down"
	var prev := global_position
	if net_away:
		iframes = maxf(iframes, 0.5)
	if not down:
		var to := remote_target - global_position
		var limit: float = stats["move_speed"] * 1.45 * REMOTE_SPEED_SLACK
		if state == "dodge":
			limit = maxf(limit, 20.0)
		var step := to.limit_length(limit * delta)
		global_position += step
		rotation.y = lerp_angle(rotation.y, remote_yaw, clampf(delta * 14.0, 0.0, 1.0))
	cam_yaw = remote_cam_yaw
	_tick_timers(delta)
	if inp["interact"] and arena != null:
		arena.call("player_interact", self)
	if inp["lock"]:
		if lock_target != null and is_instance_valid(lock_target):
			lock_target = null
		else:
			lock_target = _nearest_enemy(25.0)
	if lock_target != null and (not is_instance_valid(lock_target) or lock_target.dead):
		lock_target = null
	if state == "dodge":
		dodge_t -= delta
		if dodge_t <= 0.0:
			state = "idle"
	if down:
		_down_pose = move_toward(_down_pose, 1.0, delta * 3.0)
		_apply_down_pose()
	else:
		if _down_pose > 0.0:
			_down_pose = move_toward(_down_pose, 0.0, delta * 3.0)
			_apply_down_pose()
		_combat(delta, inp)
	var flat := Vector3(global_position.x - prev.x, 0.0, global_position.z - prev.z)
	velocity = flat / maxf(delta, 0.0001)
	_walk_phase += flat.length() * 1.7
	_animate(delta, inp)


## Neue Position vom Client; der Host akzeptiert nur plausible Bewegung (Tempolimit in _remote_step, Teleport-Sperre hier).
## Gibt false zurück, wenn der Client zurückgesetzt werden muss.
func accept_remote_position(pos: Vector3, yaw: float, cam: float, holds: int) -> bool:
	remote_yaw = yaw
	remote_cam_yaw = cam
	remote_holds = holds
	pos.y = clampf(pos.y, -1.0, 14.0)
	if net_away or state == "down":
		return true
	if pos.distance_to(global_position) > REMOTE_TELEPORT_LIMIT:
		remote_target = global_position
		return false
	var flat := Vector2(pos.x, pos.z)
	var maxr: float = ForestMap.RADIUS - 1.0
	if flat.length() > maxr:
		flat = flat.normalized() * maxr
		pos.x = flat.x
		pos.z = flat.y
	remote_target = pos
	return true


# ------------------------------------------------------------------ Kampfunfähigkeit & Wiederbelebung

func revive(hp_fraction: float = 0.4) -> void:
	if state != "down":
		return
	state = "idle"
	hp = maxf(stats["max_hp"] * hp_fraction, 1.0)
	iframes = 2.5
	bleed_t = 0.0
	revive_progress = 0.0
	permadown = false
	attack_t = 0.0
	dodge_t = 0.0
	if arena != null:
		FX.ring(arena, global_position, 3.5, Color("#7dffb0"), 0.5)
		FX.burst(arena, global_position + Vector3(0, 1, 0), Color("#7dffb0"), 18, 5.0, 0.12, 0.6)
		Sfx.play("levelup", 1.3, -4.0)


func _apply_down_pose() -> void:
	if model.is_empty():
		return
	if model.has("anim"):
		return
	var root: Node3D = model["root"]
	root.rotation.x = lerpf(0.0, -1.45, _down_pose)
	root.position.y = lerpf(0.0, 0.25, _down_pose)


# ------------------------------------------------------------------ Multiplayer: Darstellung anderer Spieler (Client)

func _build_nameplate() -> void:
	_nameplate = Node3D.new()
	_nameplate.position = Vector3(0, 2.35, 0)
	add_child(_nameplate)
	_plate_label = Label3D.new()
	_plate_label.text = display_name
	_plate_label.font_size = 40
	_plate_label.pixel_size = 0.0075
	_plate_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_plate_label.outline_size = 10
	_plate_label.no_depth_test = true
	_plate_label.modulate = Color(character.get("appearance", {}).get("accent", "#4ecdc4"))
	_plate_label.position.y = 0.22
	_nameplate.add_child(_plate_label)
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
		m.albedo_color = Color(0.05, 0.08, 0.1, 0.85) if i == 0 else Color("#6adf7a")
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_nameplate.add_child(mi)
		if i == 1:
			_plate_fill = mi


func apply_puppet_pack(a: Array) -> void:
	# [slot, x, y, z, yaw, state, hp, max_hp, combo, attack_t, attack_dur, flags, wisps, level, revive, bleed]
	puppet_target = Vector3(a[1], a[2], a[3])
	puppet_yaw = a[4]
	var st: String = STATE_CODES[clampi(int(a[5]), 0, 3)]
	state = st
	hp = a[6]
	stats["max_hp"] = maxf(a[7], 1.0)
	combo = int(a[8])
	attack_t = a[9]
	attack_dur = maxf(a[10], 0.05)
	var flags := int(a[11])
	blocking = (flags & 1) != 0
	attack_kind = "heavy" if (flags & 2) != 0 else "light"
	net_away = (flags & 4) != 0
	permadown = (flags & 8) != 0
	wisp_visuals = int(a[12])
	level = int(a[13])
	revive_progress = a[14]
	bleed_t = a[15]
	update_plate()


## Aktualisiert Lebensbalken und Statustext über dem Kopf (Puppet auf Clients, Remote-Spieler auf dem Host).
func update_plate() -> void:
	if _plate_fill != null:
		var f := clampf(hp / maxf(stats.get("max_hp", 100.0), 1.0), 0.001, 1.0)
		_plate_fill.scale.x = f
		_plate_fill.position.x = -0.5 * (1.0 - f)
	if _plate_label != null:
		var extra := ""
		if state == "down":
			extra = "\n%s  [E halten]" % ("verloren" if permadown else "%d s" % int(ceil(bleed_t)))
		elif net_away:
			extra = "\ngetrennt"
		_plate_label.text = display_name + extra


func _puppet_step(delta: float) -> void:
	var prev := global_position
	global_position = global_position.lerp(puppet_target, clampf(delta * 14.0, 0.0, 1.0))
	rotation.y = lerp_angle(rotation.y, puppet_yaw, clampf(delta * 12.0, 0.0, 1.0))
	var flat := Vector3(global_position.x - prev.x, 0.0, global_position.z - prev.z)
	velocity = flat / maxf(delta, 0.0001)
	_walk_phase += flat.length() * 1.7
	if state == "attack":
		attack_t = maxf(attack_t - delta, 0.0)
	_down_pose = move_toward(_down_pose, 1.0 if state == "down" else 0.0, delta * 3.0)
	_apply_down_pose()
	_animate(delta, {})
	_update_cosmetic_wisps(delta)


## Geisterlichter anderer Spieler (und des eigenen auf dem Client) sind rein kosmetisch; der Host rechnet den Schaden.
func _update_cosmetic_wisps(delta: float) -> void:
	if net_role == "none" or net_role == "remote_sim":
		return
	while _cwisps.size() > wisp_visuals:
		var w: Node3D = _cwisps.pop_back()
		if is_instance_valid(w):
			w.queue_free()
	while _cwisps.size() < wisp_visuals:
		var w := Node3D.new()
		Toon.part(w, "sphere", Vector3(0.2, 0, 0), Color("#8affea"), Vector3.ZERO, Vector3.ZERO, Toon.glow_mat(Color("#8affea"), 3.0), false)
		add_child(w)
		_cwisps.append(w)
	var t := Time.get_ticks_msec() * 0.001
	for i in _cwisps.size():
		var ang := t * 1.8 + i * TAU / float(maxi(_cwisps.size(), 1))
		_cwisps[i].position = Vector3(cos(ang) * 2.2, 1.6 + sin(t * 3.0 + i) * 0.25, sin(ang) * 2.2)


# ------------------------------------------------------------------ Geisterlicht-Begleiter

class Wisp extends Node3D:
	var owner_player: Player
	var index := 0
	var count := 1
	var life := 15.0
	var _t := randf() * 5.0
	var _atk := randf_range(0.2, 0.9)
	var _core: MeshInstance3D

	func _ready() -> void:
		_core = Toon.part(self, "sphere", Vector3(0.12, 0, 0), Color("#d8fff6"), Vector3.ZERO, Vector3.ZERO, Toon.glow_mat(Color("#8affea"), 4.0), false)
		FX.glow_sprite(self, Color(0.55, 1.0, 0.92, 0.9), 1.1)
		FX.trail(self, Color("#8affea"), 0.18, 16, 0.5)
		var l := OmniLight3D.new()
		l.light_color = Color("#8affea")
		l.omni_range = 4.0
		l.light_energy = 1.0
		add_child(l)

	func _physics_process(delta: float) -> void:
		if owner_player == null or not is_instance_valid(owner_player) or owner_player.is_down():
			queue_free()
			return
		life -= delta
		if life <= 0.0:
			if owner_player.skill_lv("spirit_wisps") >= 5:
				owner_player._area_hit(global_position, 3.0, owner_player.stats["damage"] * 1.5, "summon", ["summon"], 4.0)
				FX.ring(owner_player.arena, global_position, 3.0, Color("#8affea"), 0.3)
			queue_free()
			return
		_t += delta
		var ang := _t * 1.8 + index * TAU / float(maxi(count, 1))
		var target := owner_player.global_position + Vector3(cos(ang) * 2.2, 1.6 + sin(_t * 3.0 + index) * 0.25, sin(ang) * 2.2)
		global_position = global_position.lerp(target, clampf(delta * 6.0, 0.0, 1.0))
		_atk -= delta
		if _atk <= 0.0:
			var tgt: Node3D = null
			var bd := 10.0
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e) and not e.dead:
					var d: float = e.global_position.distance_to(global_position)
					if d < bd:
						bd = d
						tgt = e
			if tgt != null:
				var lv := owner_player.skill_lv("spirit_wisps")
				var dm: float = owner_player.stats["damage"] * (1.0 if lv < 3 else 1.5)
				FX.bolt(owner_player.arena, global_position, tgt.global_position + Vector3(0, 1, 0), Color("#8affea"), 0.18, 0.035)
				var dealt: float = owner_player.deal_damage(tgt, dm, "summon", ["summon"], global_position)
				if lv >= 4 and dealt > 0.0:
					owner_player._heal(dealt * 0.04)
				_atk = 0.9
			else:
				_atk = 0.3
