class_name CharacterModel
extends RefCounted
## Baut das 3D-Modell eines Charakters aus dem gespeicherten Erscheinungsbild.
## Verwendet im Charaktereditor, im Hauptmenü und im Spiel -> was man erstellt, sieht man im Run.
## (Prozedurale Figur im Toon-Stil = Platzhalter-Kunst bis Phase 6, siehe docs/STATUS.md.)

const OUTFIT_COLORS := [Color("#3f6b8a"), Color("#7a4a3a"), Color("#5a3f8a"), Color("#3f7a4a")]


## Gibt ein Dictionary mit "root" und den animierbaren Teilen zurück.
static func build(appearance: Dictionary, weapon_type: String = "sword", gear: Dictionary = {}) -> Dictionary:
	if ResourceLoader.exists(KK_DIR + "Knight.glb"):
		return _build_kaykit(appearance, weapon_type, gear)
	if ResourceLoader.exists(RIG_PATH):
		return _build_rigged(appearance, weapon_type)
	return _build_procedural(appearance, weapon_type)


const RIG_PATH := "res://assets/characters/UAL1.glb"
const RIG_F_PATH := "res://assets/characters/Mannequin_F.glb"
static var _rig_f_scene: PackedScene
static var _rig_scene: PackedScene
static var _loops_set := false


## Skelett-Modell (Quaternius Universal Base Character, CC0) + Animationsbibliothek. Farben je Körperregion aus dem Editor.
static func _build_rigged(appearance: Dictionary, weapon_type: String) -> Dictionary:
	var a: Dictionary = SaveSystem.default_appearance()
	for k in appearance:
		a[k] = appearance[k]
	if _rig_scene == null:
		_rig_scene = load(RIG_PATH)
	var root := Node3D.new()
	var body_pivot := Node3D.new()
	root.add_child(body_pivot)
	var origin: Dictionary = GameData.origins.get(a["origin"], GameData.origins["human"])
	var sc_h: float = float(a["body_height"]) * float(origin.get("height", 1.0))
	var sc_b: float = float(a["body_build"]) * float(origin.get("build", 1.0))
	body_pivot.scale = Vector3(sc_b, sc_h, sc_b)
	var skin := Color(a["skin"])
	var accent := Color(a["accent"])
	var outfit_i: int = clampi(int(a["outfit"]), 0, 3)
	var cloth: Color = OUTFIT_COLORS[outfit_i]
	var cloth2: Color = cloth.lightened(0.18)
	var leather := Color("#4a3322")
	var inst: Node3D = _rig_scene.instantiate()
	if int(a.get("female", 0)) == 1 and ResourceLoader.exists(RIG_F_PATH):
		# weiblicher Körper: gleiche Skelett-Hierarchie, Armature tauschen, Animationen bleiben
		if _rig_f_scene == null:
			_rig_f_scene = load(RIG_F_PATH)
		var fi: Node3D = _rig_f_scene.instantiate()
		var f_arm: Node = fi.get_node("Armature")
		var old_arm: Node = inst.get_node("Armature")
		inst.remove_child(old_arm)
		old_arm.free()
		fi.remove_child(f_arm)
		inst.add_child(f_arm)
		inst.move_child(f_arm, 0)
		fi.free()
	body_pivot.add_child(inst)
	var sk: Skeleton3D = inst.find_child("Skeleton3D", true, false)
	var anim: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
	if not _loops_set:
		_loops_set = true
		for n in ["Idle", "Walk", "Jog_Fwd", "Sprint", "Sword_Idle", "Crouch_Idle", "Jog_Bwd", "Spell_Simple_Idle", "Jump"]:
			if anim.has_animation(n):
				anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	# Körperregionen einfärben (Vertexfarben aus dem dominanten Knochen)
	var mesh_i: MeshInstance3D = sk.get_child(0)
	var head_pts := PackedVector3Array()
	var new_mesh := ArrayMesh.new()
	var src: Mesh = mesh_i.mesh
	for sidx in src.get_surface_count():
		var arr := src.surface_get_arrays(sidx)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / maxi(verts.size(), 1)
		var cols := PackedColorArray()
		cols.resize(verts.size())
		for v in verts.size():
			var best := 0
			var bw := -1.0
			for k in per:
				if weights[v * per + k] > bw:
					bw = weights[v * per + k]
					best = bones[v * per + k]
			var bn := sk.get_bone_name(best)
			var c: Color = _region_color(bn, skin, cloth, cloth2, leather, outfit_i)
			cols[v] = c
			if bn == "Head" or bn == "neck_01" and false:
				head_pts.append(verts[v])
		arr[Mesh.ARRAY_COLOR] = cols
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh_i.mesh = new_mesh
	var mat := Toon.make_mat(Color.WHITE, 0.0, 0.3)
	mat.set_shader_parameter("detail", 0.0)
	mat.set_shader_parameter("roughness", 0.7)
	mesh_i.material_override = mat
	# Kopfmitte/Größe aus den Kopf-Vertices
	var hc := Vector3.ZERO
	var hmin := Vector3(1e9, 1e9, 1e9)
	var hmax := Vector3(-1e9, -1e9, -1e9)
	for pnt in head_pts:
		hc += pnt
		hmin = hmin.min(pnt)
		hmax = hmax.max(pnt)
	hc = (hmin + hmax) * 0.5
	var head_h := maxf(hmax.y - hmin.y, 0.1)
	var head_bone := sk.find_bone("Head")
	var ba := BoneAttachment3D.new()
	ba.bone_name = "Head"
	sk.add_child(ba)
	var head := Node3D.new()
	var rest := sk.get_bone_global_rest(head_bone)
	head.transform = rest.affine_inverse() * Transform3D(Basis.IDENTITY, hc)
	head.scale = Vector3((hmax.x - hmin.x) / 0.49, head_h / 0.49, (hmax.z - hmin.z) / 0.49 * 1.05)
	ba.add_child(head)
	_face(head, a, skin, accent)
	# Waffe in der rechten Hand
	var hand_bone := sk.find_bone("hand_r")
	var wa := BoneAttachment3D.new()
	wa.bone_name = "hand_r"
	sk.add_child(wa)
	var weapon := _weapon(weapon_type, accent)
	var wrap := Node3D.new()
	wrap.transform = Transform3D(sk.get_bone_global_rest(hand_bone).basis.inverse(), Vector3.ZERO)
	wa.add_child(wrap)
	wrap.add_child(weapon)
	weapon.position = Vector3(0.0, 0.0, 0.0)
	weapon.rotation_degrees = grip_rotation(weapon_type)
	anim.play(idle_clip(weapon_type))
	return {"root": root, "body": body_pivot, "legs": [Node3D.new(), Node3D.new()], "arms": [Node3D.new(), Node3D.new()],
			"head": head, "weapon": weapon, "torso": inst, "anim": anim, "skeleton": sk}


# ------------------------------------------------------------------ KayKit-Helden (Adventurers Pack, CC0)

const KK_DIR := "res://assets/kaykit/"
const KK_BODIES := ["Knight", "Barbarian", "Mage", "Rogue", "Rogue_Hooded"]
const KK_BODY_NAMES := ["Ritter", "Barbar", "Magier", "Waldläuferin", "Kapuzenmantel"]
const KK_SCALE := 0.65
const KK_WEAPONS := {"sword": "sword_1handed", "axe": "axe_1handed", "hammer": "axe_2handed", "dagger": "dagger",
		"bow": "crossbow_2handed", "staff": "staff"}
static var _kk_scenes: Dictionary = {}
static var _kk_loops_set := false


static func is_kaykit(ap: AnimationPlayer) -> bool:
	return ap != null and ap.has_animation("Running_A")


## Animationsname je Zweck für KayKit-Modelle ("kind": idle, walk, jog, sprint, attack, cast, dodge, down, block, air).
static func kk_clip(kind: String, weapon_type: String, combo: int = 1) -> String:
	match kind:
		"idle": return "Idle"
		"walk": return "Walking_A"
		"jog": return "Running_A"
		"sprint": return "Running_B"
		"cast": return "Spellcast_Shoot"
		"dodge": return "Dodge_Forward"
		"down": return "Death_A"
		"block": return "Blocking"
		"air": return "Jump_Idle"
		"attack":
			match weapon_type:
				"staff": return "Spellcast_Shoot"
				"bow": return "2H_Ranged_Shoot"
				"hammer": return "2H_Melee_Attack_Chop"
				"dagger": return "1H_Melee_Attack_Stab"
				_:
					return ["1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Chop", "1H_Melee_Attack_Slice_Horizontal"][clampi(combo - 1, 0, 2)]
	return "Idle"


static func _build_kaykit(appearance: Dictionary, weapon_type: String, gear: Dictionary = {}) -> Dictionary:
	var a: Dictionary = SaveSystem.default_appearance()
	for k in appearance:
		a[k] = appearance[k]
	var bi := clampi(int(a.get("body", 0)), 0, KK_BODIES.size() - 1)
	var bname: String = KK_BODIES[bi]
	if not _kk_scenes.has(bname):
		_kk_scenes[bname] = load(KK_DIR + bname + ".glb")
	var root := Node3D.new()
	var body_pivot := Node3D.new()
	root.add_child(body_pivot)
	var origin: Dictionary = GameData.origins.get(a["origin"], GameData.origins["human"])
	var sc_h: float = float(a["body_height"]) * float(origin.get("height", 1.0)) * KK_SCALE
	var sc_b: float = float(a["body_build"]) * float(origin.get("build", 1.0)) * KK_SCALE * (0.9 if int(a.get("female", 0)) == 1 else 1.0)
	if int(a.get("female", 0)) == 1:
		sc_h *= 0.97
	body_pivot.scale = Vector3(sc_b, sc_h, sc_b)
	var inst: Node3D = _kk_scenes[bname].instantiate()
	body_pivot.add_child(inst)
	var sk: Skeleton3D = inst.find_child("Skeleton3D", true, false)
	var anim: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
	if not _kk_loops_set:
		_kk_loops_set = true
		for n in ["Idle", "Walking_A", "Walking_B", "Walking_C", "Running_A", "Running_B", "Jump_Idle", "Blocking", "Spellcasting",
				"2H_Melee_Idle", "Unarmed_Idle", "1H_Ranged_Aiming", "2H_Ranged_Aiming"]:
			if anim.has_animation(n):
				anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	# eingebaute Waffen/Schilde ausblenden, nur Kopfbedeckung und Umhang behalten
	for c in sk.get_children():
		if c is BoneAttachment3D:
			var n := String(c.name)
			if not (n.contains("Hat") or n.contains("Cape") or n.contains("Helmet") or n.contains("Hood")):
				c.visible = false
	_apply_gear(sk, bname, gear, int(a.get("female", 0)) == 1, int(a.get("head_style", -1)))
	_apply_custom(sk, a, gear)
	# Waffe in der rechten Hand
	var wa := BoneAttachment3D.new()
	wa.bone_name = "handslot.r"
	sk.add_child(wa)
	var weapon := Node3D.new()
	var wpath := KK_DIR + "weapons/%s.gltf" % KK_WEAPONS.get(weapon_type, "sword_1handed")
	var wmesh: Node3D = null
	if ResourceLoader.exists(wpath):
		wmesh = (load(wpath) as PackedScene).instantiate()
		weapon.add_child(wmesh)
	wa.add_child(weapon)
	# gleiche Lage wie die eingebauten Waffenknochen des Modells (Y um 180° gedreht, minimal nach oben)
	weapon.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0.0333, 0))
	weapon.set_meta("mesh", wmesh)
	anim.play("Idle")
	return {"root": root, "body": body_pivot, "legs": [Node3D.new(), Node3D.new()], "arms": [Node3D.new(), Node3D.new()],
			"head": Node3D.new(), "weapon": weapon, "torso": inst, "anim": anim, "skeleton": sk}


## Aus der Ausrüstung des Charakters wird das Aussehen abgeleitet: je Rüstungsteil ein Figurensatz (0..4 = KK_BODIES),
## Schild als Name. Jedes Teil sieht je nach Gegenstand anders aus; wechselt man Teile, ändert sich die Figur sofort.
const KK_SHIELDS := ["Round_Shield", "Rectangle_Shield", "Spike_Shield", "Barbarian_Round_Shield"]
const UNIQUE_STYLE := {"stormcrown": 2, "sovereign_crown": 0, "wyrm_scale": 1}


static func _style_of(it: Dictionary) -> int:
	if UNIQUE_STYLE.has(it.get("base_id", "")):
		return UNIQUE_STYLE[it["base_id"]]
	return absi(hash(str(it.get("uid", it.get("name", ""))))) % KK_BODIES.size()


static func gear_looks(c: Dictionary) -> Dictionary:
	var out := {}
	if c.is_empty():
		return out
	var eq: Dictionary = c.get("equipment", {})
	var info := {}
	for slot in ["head", "chest", "hands", "legs", "feet", "amulet", "artifact", "offhand"]:
		if eq.has(slot):
			var it0 := SaveSystem.find_item(c, eq[slot])
			if not it0.is_empty():
				info[slot] = {"rarity": str(it0.get("rarity", "common")), "base": str(it0.get("base_id", ""))}
	out["info"] = info
	for slot in ["head", "chest", "legs"]:
		if eq.has(slot):
			var it := SaveSystem.find_item(c, eq[slot])
			if not it.is_empty():
				out[slot] = _style_of(it)
	if eq.has("offhand"):
		var it2 := SaveSystem.find_item(c, eq["offhand"])
		if not it2.is_empty():
			out["shield"] = KK_SHIELDS[_style_of(it2) % KK_SHIELDS.size()]
	return out


static func _kk_instance(n: String) -> Node3D:
	if not _kk_scenes.has(n):
		_kk_scenes[n] = load(KK_DIR + n + ".glb")
	return _kk_scenes[n].instantiate()


## Teil (Mesh) aus einer anderen Figur in das Skelett der Basisfigur übernehmen (gleiches Skelett, gleiche Bindepose).
static func _graft_mesh(sk: Skeleton3D, src_sk: Skeleton3D, part: String, remove_prefix: String) -> void:
	for c in sk.get_children():
		if c is MeshInstance3D and String(c.name).begins_with(remove_prefix):
			c.queue_free()
	var m := src_sk.get_node_or_null(part)
	if m == null:
		return
	m.get_parent().remove_child(m)
	sk.add_child(m)
	m.skeleton = NodePath("..")


## Anbauteil (Helm, Umhang, Schild) von einem Hilfsknochen der Quellfigur an den Elternknochen der Basisfigur hängen.
static func _graft_attachment(sk: Skeleton3D, src_sk: Skeleton3D, att_name: String) -> void:
	var att := src_sk.get_node_or_null(att_name)
	if att == null or not (att is BoneAttachment3D):
		return
	var idx := src_sk.find_bone(att.bone_name)
	if idx < 0:
		return
	var par := src_sk.get_bone_parent(idx)
	if par < 0:
		return
	var rel := src_sk.get_bone_global_rest(par).affine_inverse() * src_sk.get_bone_global_rest(idx)
	var na := BoneAttachment3D.new()
	na.bone_name = src_sk.get_bone_name(par)
	sk.add_child(na)
	for k in att.get_children():
		att.remove_child(k)
		na.add_child(k)
		if k is Node3D:
			k.transform = rel * k.transform


static func _hide_named(sk: Skeleton3D, tokens: Array) -> void:
	for c in sk.get_children():
		if c is BoneAttachment3D:
			for t in tokens:
				if String(c.name).contains(t):
					c.visible = false


static func _apply_gear(sk: Skeleton3D, base: String, gear: Dictionary, female: bool, head_override: int = -1) -> void:
	var base_short := base.split("_")[0]
	var head_style := base
	if gear.has("head"):
		head_style = KK_BODIES[int(gear["head"])]
		_hide_named(sk, ["Hat", "Helmet", "Hood"])
		var hs := _kk_instance(head_style)
		var hsk: Skeleton3D = hs.find_child("Skeleton3D", true, false)
		for tok in ["Helmet", "Hat"]:
			_graft_attachment(sk, hsk, "%s_%s" % [head_style.split("_")[0], tok])
		hs.free()
	if female and not gear.has("head") and base_short != "Rogue":
		_hide_named(sk, ["Hat", "Helmet", "Hood"])
	var head_src := head_style
	if female:
		head_src = "Rogue_Hooded" if head_style == "Rogue_Hooded" else "Rogue"
	if head_override >= 0 and not gear.has("head"):
		head_src = KK_BODIES[clampi(head_override, 0, KK_BODIES.size() - 1)]
	if head_src != base or gear.has("head"):
		var src := _kk_instance(head_src)
		var ssk: Skeleton3D = src.find_child("Skeleton3D", true, false)
		var hname := "%s_Head%s" % [head_src.split("_")[0], "_Hooded" if head_src == "Rogue_Hooded" else ""]
		_graft_mesh(sk, ssk, hname, "%s_Head" % base_short)
		src.free()
	if gear.has("chest"):
		var cs: String = KK_BODIES[int(gear["chest"])]
		var cshort := cs.split("_")[0]
		var src2 := _kk_instance(cs)
		var ssk2: Skeleton3D = src2.find_child("Skeleton3D", true, false)
		_hide_named(sk, ["Cape"])
		for part in ["Body", "ArmLeft", "ArmRight"]:
			_graft_mesh(sk, ssk2, "%s_%s" % [cshort, part], "%s_%s" % [base_short, part])
		_graft_attachment(sk, ssk2, "%s_Cape" % cshort)
		src2.free()
	if gear.has("legs"):
		var ls: String = KK_BODIES[int(gear["legs"])]
		var lshort := ls.split("_")[0]
		var src3 := _kk_instance(ls)
		var ssk3: Skeleton3D = src3.find_child("Skeleton3D", true, false)
		for part in ["LegLeft", "LegRight"]:
			_graft_mesh(sk, ssk3, "%s_%s" % [lshort, part], "%s_%s" % [base_short, part])
		src3.free()
	_apply_overlays(sk, gear.get("info", {}))
	if gear.has("shield"):
		var sname: String = gear["shield"]
		var ssrc := _kk_instance("Barbarian" if sname.begins_with("Barbarian") else "Knight")
		var ssk4: Skeleton3D = ssrc.find_child("Skeleton3D", true, false)
		_graft_attachment(sk, ssk4, sname)
		ssrc.free()


const RAR_RANK := {"common": 0, "uncommon": 1, "rare": 2, "epic": 3, "legendary": 4, "mythic": 5}
const RAR_COL := {"common": "#9a7b55", "uncommon": "#4fae5a", "rare": "#4a8fe0", "epic": "#a45ad8", "legendary": "#f0a030", "mythic": "#e0405a"}


static func _att(sk: Skeleton3D, bone: String) -> BoneAttachment3D:
	if sk.find_bone(bone) < 0:
		return null
	var a := BoneAttachment3D.new()
	a.bone_name = bone
	a.name = "GearAtt_" + bone
	sk.add_child(a)
	return a


static func _metal(rar: String) -> ShaderMaterial:
	var rk: int = int(RAR_RANK.get(rar, 0))
	var col := Color(RAR_COL.get(rar, "#9a7b55"))
	return Toon.mat(col.lerp(Color("#cfd6de"), 0.25 if rk >= 1 else 0.0), 0.0 if rk < 2 else 0.25 * rk, 0.4)


static func _trim(rar: String) -> ShaderMaterial:
	var rk: int = int(RAR_RANK.get(rar, 0))
	return Toon.glow_mat(Color(RAR_COL.get(rar, "#9a7b55")).lightened(0.2), 0.8 + 0.7 * rk)


## Sichtbare Ausrüstung am Charakter aus echten Modellen: Brustpanzer, Handschuhe, Halskette, Krone, Artefakt-Kristall.
## Sitzt auf den Knochen, bewegt sich also mit den Animationen. Seltenheit bestimmt das Modell (Leder/Metall/Schwarz/Gold).
static func _put(att: Node3D, model: String, size: float, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO, mirror: bool = false) -> Node3D:
	var m := ItemModels.make(model, size)
	if m == null:
		return null
	m.position = pos
	m.rotation_degrees = rot_deg
	if mirror:
		m.scale = Vector3(-1, 1, 1)
	att.add_child(m)
	return m


const RAR_TINT := {"common": Color("#ffffff"), "uncommon": Color("#8fe39a"), "rare": Color("#7fb2ff"), "epic": Color("#c48cff"), "legendary": Color("#ffc34d")}


static func _apply_overlays(sk: Skeleton3D, info: Dictionary) -> void:
	# Seltenheit färbt die Rüstungsteile des Körpers (sofort sichtbar, sitzt per Definition am Charakter)
	for slot_tokens in [["chest", ["_Body", "_Arm"]], ["legs", ["_Leg"]]]:
		if info.has(slot_tokens[0]):
			var rr: String = info[slot_tokens[0]]["rarity"]
			if rr != "common":
				_tint_meshes(sk, slot_tokens[1], RAR_TINT.get(rr, Color.WHITE), 0.45)
	if info.has("chest"):
		var r: String = info["chest"]["rarity"]
		var ch := _att(sk, "chest")
		if ch != null:
			_put(ch, str(ItemModels.ARMOR_BY_RARITY.get(r, "ArmorLeather")), 0.78, Vector3(0, -0.2, 0.02))
	if info.has("hands"):
		for side in ["l", "r"]:
			var h := _att(sk, "hand." + side)
			if h != null:
				_put(h, "Glove", 0.3, Vector3(0, -0.02, 0), Vector3(0, 0, 0), side == "l")
	if info.has("amulet"):
		var ch2 := _att(sk, "chest")
		if ch2 != null:
			_put(ch2, "Necklace%d" % (absi(hash(str(info["amulet"].get("base", "")))) % 3 + 1), 0.4, Vector3(0, 0.05, 0.19))
	if info.has("artifact"):
		var ch3 := _att(sk, "chest")
		if ch3 != null:
			var orb := _put(ch3, str(ItemModels.ARTIFACTS[absi(hash(str(info["artifact"].get("base", "")))) % ItemModels.ARTIFACTS.size()]), 0.34, Vector3(0.62, 0.62, -0.1))
			if orb != null:
				orb.name = "ArtifactOrb"
	if info.has("head"):
		var r5: String = info["head"]["rarity"]
		if int(RAR_RANK[r5]) >= 3:
			var hd := _att(sk, "head")
			if hd != null:
				_put(hd, "Crown" if int(RAR_RANK[r5]) >= 4 else "Crown2", 0.5, Vector3(0, 0.82, 0))


## Editor-Anpassungen auf dem KayKit-Körper: Hauttönung, Kleidungsfarbe, Umhang, Rock, Frisur, Bart, Ohren, Hörner.
const HEAD_S := 1.85

static func _tint_meshes(sk: Skeleton3D, tokens: Array, col: Color, amount: float) -> void:
	for c in sk.get_children():
		if c is MeshInstance3D:
			var nm := String(c.name)
			var hit := false
			for t in tokens:
				if nm.contains(t):
					hit = true
			if not hit:
				continue
			var mi := c as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				var base: Material = mi.get_active_material(i)
				if base is StandardMaterial3D:
					var dup := (base as StandardMaterial3D).duplicate() as StandardMaterial3D
					dup.albedo_color = Color.WHITE.lerp(col, amount)
					mi.set_surface_override_material(i, dup)


static func _apply_custom(sk: Skeleton3D, a: Dictionary, gear: Dictionary) -> void:
	var female := int(a.get("female", 0)) == 1
	var skin := Color(str(a.get("skin", "#e0b090")))
	if str(a.get("skin", "#e0b090")).to_lower() != "#e0b090":
		_tint_meshes(sk, ["_Head"], skin.lerp(Color.WHITE, 0.15), 0.9)
	var cloth := str(a.get("cloth", "#ffffff"))
	if cloth.to_lower() != "#ffffff":
		_tint_meshes(sk, ["_Body", "_Arm", "_Leg"], Color(cloth), 0.75)
	var cape := int(a.get("cape", 0))
	if cape > 0 and not gear.has("chest"):
		var cs: String = KK_BODIES[clampi(cape - 1, 0, KK_BODIES.size() - 1)]
		_hide_named(sk, ["Cape"])
		var src := _kk_instance(cs)
		var ssk: Skeleton3D = src.find_child("Skeleton3D", true, false)
		_graft_attachment(sk, ssk, "%s_Cape" % cs.split("_")[0])
		src.free()
	var skirt := int(a.get("skirt", -1))
	if skirt < 0:
		skirt = 1 if female else 0
	if skirt > 0:
		var hips := _att(sk, "hips")
		if hips != null:
			var col := Color(cloth) if cloth.to_lower() != "#ffffff" else Color(str(a.get("accent", "#4ecdc4"))).darkened(0.25)
			var sk_m := Toon.part(hips, "cone", Vector3(0.52 if skirt == 1 else 0.62, 0.6, 0), col, Vector3(0, -0.2, 0), Vector3(180, 0, 0), Toon.mat(col, 0.0, 0.3))
			Toon.outline(sk_m, 0.012)
	if int(a.get("hair_style", 1)) > 0 and not gear.has("head"):
		_hide_named(sk, ["Hat", "Helmet", "Hood"])
	var head := _att(sk, "head")
	if head == null:
		return
	var hc := Node3D.new()
	hc.position = Vector3(0, 0.3, 0)
	hc.scale = Vector3.ONE * HEAD_S
	head.add_child(hc)
	var hair_c := Color(str(a.get("hair_color", "#4a2f1b")))
	var hs := int(a.get("hair_style", 1))
	if hs == 99:
		Toon.part(hc, "sphere", Vector3(0.08, 0, 0), Color.RED, Vector3(0.4, 0, 0))
		Toon.part(hc, "sphere", Vector3(0.08, 0, 0), Color.GREEN, Vector3(0, 0.4, 0))
		Toon.part(hc, "sphere", Vector3(0.08, 0, 0), Color.BLUE, Vector3(0, 0, 0.4))
		Toon.part(hc, "sphere", Vector3(0.05, 0, 0), Color.WHITE, Vector3(0, 0, 0))
	elif hs > 0:
		_hair_kk(hc, hs, hair_c)
	_beard_kk(hc, int(a.get("beard", 0)), hair_c)
	if false:
		_beard(hc, int(a.get("beard", 0)), hair_c)
	var ears := int(a.get("ears", 0))
	if str(a.get("origin", "human")) in ["elf", "faun"]:
		ears = maxi(ears, 1)
	var skin_m := Toon.mat(skin.lerp(Color.WHITE, 0.15), 0.0, 0.3)
	for sx in [-1, 1]:
		if ears == 1:
			Toon.part(hc, "cone", Vector3(0.05, 0.3, 0), skin, Vector3(0.27 * sx, 0.06, 0), Vector3(0, 0, -80 * sx), skin_m, false)
		elif ears >= 2:
			Toon.part(hc, "cone", Vector3(0.07, 0.3, 0), skin, Vector3(0.18 * sx, 0.3, 0), Vector3(0, 0, -15 * sx), skin_m, false)
	_horns(hc, int(a.get("horns", 0)))



## Frisuren für den KayKit-Kopf (Kopfmitte im Ursprung, Halbbreite ~0.3, Oberkante y 0.33, Gesicht zeigt nach +Z).
static func _blob(parent: Node3D, r: float, pos: Vector3, sc: Vector3, c: Color) -> MeshInstance3D:
	var m := Toon.part(parent, "sphere", Vector3(r, 0, 0), c, pos, Vector3.ZERO, Toon.mat(c, 0.0, 0.3))
	m.scale = sc
	Toon.outline(m, 0.012)
	return m


static func _strand(parent: Node3D, r: float, h: float, pos: Vector3, rot: Vector3, c: Color) -> MeshInstance3D:
	var m := Toon.part(parent, "capsule", Vector3(r, h, 0), c, pos, rot, Toon.mat(c, 0.0, 0.3))
	Toon.outline(m, 0.012)
	return m


static func _hair_kk(h: Node3D, style: int, c: Color) -> void:
	_blob(h, 0.345, Vector3(0, 0.3, -0.1), Vector3(1.0, 0.85, 1.05), c)   # Kappe
	match style:
		2:
			_strand(h, 0.2, 0.9, Vector3(0, -0.15, -0.3), Vector3(0, 0, 0), c)
			_strand(h, 0.08, 0.55, Vector3(0.3, -0.05, -0.08), Vector3(0, 0, 0), c)
			_strand(h, 0.08, 0.55, Vector3(-0.3, -0.05, -0.08), Vector3(0, 0, 0), c)
		3:
			for i in 7:
				var cone := Toon.part(h, "cone", Vector3(0.09, 0.3, 0), c, Vector3(0, 0.4, 0.2 - i * 0.09), Vector3(-6, 0, 0), Toon.mat(c, 0.0, 0.3), false)
				Toon.outline(cone, 0.01)
		4:
			_strand(h, 0.08, 0.9, Vector3(0, -0.2, -0.36), Vector3(8, 0, 0), c)
			_blob(h, 0.07, Vector3(0, -0.66, -0.38), Vector3.ONE, c.darkened(0.3))
		5:
			for i in 9:
				var ang := i * TAU / 9.0
				var cone2 := Toon.part(h, "cone", Vector3(0.09, 0.32, 0), c, Vector3(cos(ang) * 0.2, 0.42, sin(ang) * 0.2 - 0.1), Vector3(sin(ang) * 25, 0, -cos(ang) * 25), Toon.mat(c, 0.0, 0.3), false)
				Toon.outline(cone2, 0.01)
		6:
			_blob(h, 0.34, Vector3(0, -0.02, -0.16), Vector3(1.0, 0.8, 0.9), c)
			_strand(h, 0.09, 0.4, Vector3(0.3, -0.06, 0.0), Vector3.ZERO, c)
			_strand(h, 0.09, 0.4, Vector3(-0.3, -0.06, 0.0), Vector3.ZERO, c)
		7:
			_blob(h, 0.14, Vector3(0, 0.55, -0.12), Vector3.ONE, c)
		8:
			for sx in [-1, 1]:
				_strand(h, 0.07, 0.6, Vector3(0.33 * sx, -0.18, 0.02), Vector3(0, 0, 4 * sx), c)
				_blob(h, 0.08, Vector3(0.34 * sx, -0.52, 0.02), Vector3.ONE, c.darkened(0.3))
		9:
			_strand(h, 0.24, 0.9, Vector3(0, -0.2, -0.33), Vector3.ZERO, c)
			for i in 5:
				var sp := Toon.part(h, "cone", Vector3(0.08, 0.28, 0), c, Vector3((i - 2) * 0.13, 0.42, -0.05), Vector3(-10, 0, (i - 2) * -14), Toon.mat(c, 0.0, 0.3), false)
				Toon.outline(sp, 0.01)
		10:
			_strand(h, 0.09, 0.7, Vector3(0, 0.25, -0.5), Vector3(-40, 0, 0), c)
			_blob(h, 0.09, Vector3(0, 0.2, -0.4), Vector3.ONE, c.darkened(0.3))
		11:
			for i in 10:
				var a2 := i * TAU / 10.0
				_blob(h, 0.1, Vector3(cos(a2) * 0.3, 0.22 - (i % 3) * 0.07, sin(a2) * 0.3 - 0.1), Vector3.ONE, c)


static func _beard_kk(h: Node3D, style: int, c: Color) -> void:
	match style:
		1:
			_blob(h, 0.22, Vector3(0, -0.2, 0.12), Vector3(1.0, 0.5, 0.8), c.darkened(0.2))
		2:
			_blob(h, 0.12, Vector3(0, -0.22, 0.2), Vector3(1.1, 1.0, 0.5), c)
		3:
			for i in 3:
				_strand(h, 0.035, 0.32, Vector3((i - 1) * 0.08, -0.36, 0.27), Vector3(8, 0, (i - 1) * -5), c)
		4:
			var m := Toon.part(h, "capsule", Vector3(0.03, 0.3, 0), c, Vector3(0, -0.13, 0.34), Vector3(0, 0, 90), Toon.mat(c, 0.0, 0.3), false)
			Toon.outline(m, 0.008)
		5:
			var g := Toon.part(h, "cone", Vector3(0.07, 0.24, 0), c, Vector3(0, -0.4, 0.28), Vector3(175, 0, 0), Toon.mat(c, 0.0, 0.3), false)
			Toon.outline(g, 0.01)


static func idle_clip(weapon_type: String) -> String:
	return "Idle"


## Griffwinkel pro Waffentyp (empirisch per Screenshot in der Idle-Pose bestimmt).
static func grip_rotation(weapon_type: String) -> Vector3:
	if weapon_type in ["bow", "staff"]:
		return Vector3(-25, 0, 0)
	return Vector3(-20, 0, 0)


static func _region_color(bn: String, skin: Color, cloth: Color, cloth2: Color, leather: Color, outfit_i: int) -> Color:
	if bn == "Head" or bn == "neck_01" or bn.begins_with("hand_") or bn.find("_0") >= 0 and not bn.begins_with("spine"):
		return skin
	if bn.begins_with("lowerarm"):
		return leather if outfit_i != 2 else cloth2
	if bn.begins_with("upperarm") or bn.begins_with("clavicle"):
		return cloth2
	if bn.begins_with("spine") or bn == "pelvis" or bn == "root":
		return cloth
	if bn.begins_with("thigh"):
		return cloth.darkened(0.15)
	return leather


## Gesicht, Haare, Bart, Ohren, Hörner, Narben (gemeinsam für beide Modellvarianten; Kopfmitte im Ursprung, Radius ~0.245).
static func _face(head: Node3D, a: Dictionary, skin: Color, accent: Color) -> void:
	var eye_c := Color(a["eye_color"])
	var hair_c := Color(a["hair_color"])
	for sx in [-1, 1]:
		Toon.part(head, "sphere", Vector3(0.048, 0, 0), Color("#f4f1ea"), Vector3(0.088 * sx, 0.035, 0.19), Vector3.ZERO, null, false)
		Toon.part(head, "sphere", Vector3(0.03, 0, 0), eye_c, Vector3(0.088 * sx, 0.035, 0.228), Vector3.ZERO, Toon.glow_mat(eye_c, 0.5), false)
		Toon.part(head, "sphere", Vector3(0.016, 0, 0), Color("#0b0b10"), Vector3(0.088 * sx, 0.035, 0.248), Vector3.ZERO, null, false)
		Toon.part(head, "box", Vector3(0.085, 0.017, 0.02), hair_c.darkened(0.25), Vector3(0.088 * sx, 0.1, 0.205), Vector3(0, 0, -8 * sx), null, false)
	Toon.part(head, "sphere", Vector3(0.035, 0, 0), skin.darkened(0.08), Vector3(0, -0.03, 0.235), Vector3.ZERO, null, false)
	Toon.part(head, "box", Vector3(0.07, 0.012, 0.012), Color("#7a3a3a"), Vector3(0, -0.105, 0.215), Vector3.ZERO, null, false)
	_hair(head, int(a["hair_style"]), hair_c)
	if int(a.get("female", 0)) == 0:
		_beard(head, int(a["beard"]), hair_c)
	var ears: int = int(a["ears"])
	if a["origin"] == "elf" or a["origin"] == "faun":
		ears = maxi(ears, 1)
	for sx in [-1, 1]:
		if ears == 0:
			Toon.part(head, "sphere", Vector3(0.06, 0, 0), skin, Vector3(0.24 * sx, 0, 0), Vector3.ZERO, null, false)
		elif ears == 1:
			Toon.part(head, "cone", Vector3(0.05, 0.28, 0), skin, Vector3(0.28 * sx, 0.06, 0), Vector3(0, 0, -80 * sx), null, false)
		else:
			Toon.part(head, "cone", Vector3(0.08, 0.3, 0), skin, Vector3(0.14 * sx, 0.3, 0), Vector3(0, 0, -18 * sx), null, false)
	var horns: int = int(a["horns"])
	if a["origin"] == "faun" and horns == 0:
		horns = 2
	_horns(head, horns)
	_face_marks(head, int(a["scar"]), int(a["tattoo"]), accent)


static func _build_procedural(appearance: Dictionary, weapon_type: String = "sword") -> Dictionary:
	var a: Dictionary = SaveSystem.default_appearance()
	for k in appearance:
		a[k] = appearance[k]
	var root := Node3D.new()
	var body_pivot := Node3D.new()
	root.add_child(body_pivot)
	var origin: Dictionary = GameData.origins.get(a["origin"], GameData.origins["human"])
	var sc_h: float = float(a["body_height"]) * float(origin.get("height", 1.0))
	var sc_b: float = float(a["body_build"]) * float(origin.get("build", 1.0))
	body_pivot.scale = Vector3(sc_b, sc_h, sc_b)

	var skin := Color(a["skin"])
	var accent := Color(a["accent"])
	var outfit_i: int = clampi(int(a["outfit"]), 0, 3)
	var cloth: Color = OUTFIT_COLORS[outfit_i]
	var cloth2: Color = cloth.lightened(0.18)

	var leather := Color("#4a3322")
	var trim := accent.darkened(0.15)
	# Beine: Oberschenkel, Stiefel mit Schaft und Sohle
	var legs: Array = []
	for sx in [-1, 1]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.14 * sx, 0.55, 0)
		body_pivot.add_child(pivot)
		var leg := Toon.part(pivot, "limb", Vector3(0.118, 0.3, 0.082), cloth.darkened(0.15), Vector3(0, -0.2, 0), Vector3.ZERO, Toon.tmat(cloth.darkened(0.15), "cloth", 4.0, 0.8, 0.35))
		Toon.outline(leg, 0.014)
		var boot := Toon.part(pivot, "cyl", Vector3(0.12, 0.26, 0.13), leather, Vector3(0, -0.4, 0), Vector3.ZERO, Toon.tmat(leather, "leather", 5.0, 0.9, 0.5))
		Toon.outline(boot, 0.014)
		Toon.part(pivot, "cyl", Vector3(0.14, 0.05, 0.14), leather.lightened(0.15), Vector3(0, -0.29, 0))    # Stiefelkrempe
		var toe := Toon.part(pivot, "box", Vector3(0.2, 0.1, 0.3), leather.darkened(0.2), Vector3(0, -0.51, 0.06))
		toe.scale = Vector3(1, 1, 1)
		if outfit_i != 2:
			Toon.part(pivot, "sphere", Vector3(0.07, 0, 0), trim, Vector3(0, -0.16, 0.09))                    # Knieschützer
		legs.append(pivot)
	# Torso: Brust und Taille getrennt, Gürtel mit Schnalle und Beutel
	var torso := Toon.part(body_pivot, "torso", Vector3(0.31, 0.78, 0), cloth, Vector3(0, 1.0, 0), Vector3.ZERO, Toon.tmat(cloth, "cloth", 4.0, 0.8, 0.35))
	Toon.outline(torso, 0.016)
	Toon.part(body_pivot, "box", Vector3(0.5, 0.09, 0.32), leather, Vector3(0, 0.74, 0), Vector3.ZERO, Toon.tmat(leather, "leather", 5.0, 0.9, 0.5))                   # Gürtel
	Toon.part(body_pivot, "box", Vector3(0.1, 0.1, 0.03), Color("#d8b25a"), Vector3(0, 0.74, 0.17), Vector3.ZERO, Toon.glow_mat(Color("#d8b25a"), 0.35), false)
	Toon.part(body_pivot, "box", Vector3(0.12, 0.14, 0.09), leather.lightened(0.1), Vector3(0.27, 0.72, 0.06))  # Beutel
	Toon.part(body_pivot, "cyl", Vector3(0.09, 0.09, 0.09), trim, Vector3(0, 1.36, 0))                      # Halsbund
	if outfit_i == 0:
		var scarf := Toon.part(body_pivot, "torus", Vector3(0.17, 0.11, 0), accent, Vector3(0, 1.37, 0.01), Vector3.ZERO, Toon.mat(accent))
		scarf.scale = Vector3(1, 1.2, 1)
		Toon.part(body_pivot, "box", Vector3(0.09, 0.3, 0.04), accent, Vector3(0.1, 1.2, 0.18), Vector3(0, 0, 8))
	elif outfit_i == 1:
		Toon.part(body_pivot, "box", Vector3(0.46, 0.38, 0.33), cloth2, Vector3(0, 1.03, 0.03))
		Toon.part(body_pivot, "box", Vector3(0.05, 0.4, 0.34), leather, Vector3(0, 1.03, 0.04))
	elif outfit_i == 2:
		Toon.part(body_pivot, "cone", Vector3(0.4, 0.75, 0), cloth2, Vector3(0, 0.42, 0))
		Toon.part(body_pivot, "torus", Vector3(0.3, 0.26, 0), accent, Vector3(0, 0.08, 0), Vector3.ZERO, Toon.glow_mat(accent, 0.5), false)
	elif outfit_i == 3:
		var cape := Toon.part(body_pivot, "prism", Vector3(0.74, 0.8, 0.07), cloth2, Vector3(0, 0.95, -0.2), Vector3(0, 0, 180))
		Toon.outline(cape, 0.012)
	# Schulterpanzer
	for sx in [-1, 1]:
		var pad := Toon.part(body_pivot, "sphere", Vector3(0.14, 0.7, 0), trim, Vector3(0.36 * sx, 1.32, 0), Vector3.ZERO, Toon.tmat(trim, "metal", 3.0, 1.0, 0.8, 0.0, 0.5))
		pad.scale = Vector3(1.15, 0.8, 1.0)
		Toon.outline(pad, 0.012)
	# Arme: Oberarm, Unterarmschiene, Hand
	var arms: Array = []
	for sx in [-1, 1]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.38 * sx, 1.2, 0)
		body_pivot.add_child(pivot)
		var arm := Toon.part(pivot, "limb", Vector3(0.098, 0.26, 0.07), cloth2, Vector3(0, -0.2, 0), Vector3.ZERO, Toon.tmat(cloth2, "cloth", 4.0, 0.8, 0.35))
		Toon.outline(arm, 0.012)
		var bracer := Toon.part(pivot, "cyl", Vector3(0.095, 0.2, 0.1), leather, Vector3(0, -0.36, 0), Vector3.ZERO, Toon.tmat(leather, "leather", 5.0, 0.9, 0.5))
		Toon.outline(bracer, 0.01)
		Toon.part(pivot, "sphere", Vector3(0.085, 0, 0), skin.darkened(0.04), Vector3(0, -0.5, 0.01))
		arms.append(pivot)
	# Hals und Kopf
	Toon.part(body_pivot, "cyl", Vector3(0.075, 0.14, 0.085), skin.darkened(0.06), Vector3(0, 1.44, 0))
	var head := Node3D.new()
	head.position = Vector3(0, 1.6, 0)
	body_pivot.add_child(head)
	var skull := Toon.part(head, "head", Vector3(0.245, 0, 0), skin, Vector3.ZERO, Vector3.ZERO, Toon.tmat(skin, "leather", 3.0, 0.4, 0.08, 0.0, 0.35))
	Toon.outline(skull, 0.014)
	var eye_c := Color(a["eye_color"])
	var hair_c := Color(a["hair_color"])
	for sx in [-1, 1]:
		Toon.part(head, "sphere", Vector3(0.048, 0, 0), Color("#f4f1ea"), Vector3(0.088 * sx, 0.035, 0.19), Vector3.ZERO, null, false)
		Toon.part(head, "sphere", Vector3(0.03, 0, 0), eye_c, Vector3(0.088 * sx, 0.035, 0.228), Vector3.ZERO, Toon.glow_mat(eye_c, 0.5), false)
		Toon.part(head, "sphere", Vector3(0.016, 0, 0), Color("#0b0b10"), Vector3(0.088 * sx, 0.035, 0.248), Vector3.ZERO, null, false)
		Toon.part(head, "box", Vector3(0.085, 0.017, 0.02), hair_c.darkened(0.25), Vector3(0.088 * sx, 0.1, 0.205), Vector3(0, 0, -8 * sx), null, false)  # Augenbraue
	Toon.part(head, "sphere", Vector3(0.035, 0, 0), skin.darkened(0.08), Vector3(0, -0.03, 0.235), Vector3.ZERO, null, false)   # Nase
	Toon.part(head, "box", Vector3(0.07, 0.012, 0.012), Color("#7a3a3a"), Vector3(0, -0.105, 0.215), Vector3.ZERO, null, false)   # Mund
	_hair(head, int(a["hair_style"]), Color(a["hair_color"]))
	_beard(head, int(a["beard"]), Color(a["hair_color"]))
	# Ohren: Herkunft oder Auswahl (0 rund, 1 spitz, 2 Tierohren); Elfen haben immer spitze Ohren
	var ears: int = int(a["ears"])
	if a["origin"] == "elf" or a["origin"] == "faun":
		ears = maxi(ears, 1)
	for sx in [-1, 1]:
		if ears == 0:
			Toon.part(head, "sphere", Vector3(0.06, 0, 0), skin, Vector3(0.24 * sx, 0, 0), Vector3.ZERO, null, false)
		elif ears == 1:
			Toon.part(head, "cone", Vector3(0.05, 0.28, 0), skin, Vector3(0.28 * sx, 0.06, 0), Vector3(0, 0, -80 * sx), null, false)
		else:
			Toon.part(head, "cone", Vector3(0.08, 0.3, 0), skin, Vector3(0.14 * sx, 0.3, 0), Vector3(0, 0, -18 * sx), null, false)
	# Hörner (Faun bekommt Standardhörner, wenn keine gewählt)
	var horns: int = int(a["horns"])
	if a["origin"] == "faun" and horns == 0:
		horns = 2
	_horns(head, horns)
	_face_marks(head, int(a["scar"]), int(a["tattoo"]), accent)
	# Waffe in der rechten Hand
	var weapon := _weapon(weapon_type, accent)
	arms[1].add_child(weapon)
	weapon.position = Vector3(0, -0.5, 0.05)
	root.add_child(Node3D.new())   # Reserve
	return {"root": root, "body": body_pivot, "legs": legs, "arms": arms, "head": head, "weapon": weapon, "torso": torso}


static func _hair(head: Node3D, style: int, c: Color) -> void:
	match style:
		1:
			_hair_cap(head, c)
		2:
			_hair_cap(head, c)
			Toon.part(head, "capsule", Vector3(0.24, 0.95, 0), c, Vector3(0, -0.3, -0.14))
		3:
			for i in 5:
				Toon.part(head, "cone", Vector3(0.06, 0.2, 0), c, Vector3(0, 0.27 - i * 0.02, 0.12 - i * 0.07), Vector3(-10, 0, 0))
		4:
			_hair_cap(head, c)
			var tail := Toon.part(head, "capsule", Vector3(0.07, 0.5, 0), c, Vector3(0, -0.15, -0.3), Vector3(20, 0, 0))
			Toon.outline(tail, 0.015)
		5:
			for i in 7:
				var ang := i * TAU / 7.0
				Toon.part(head, "cone", Vector3(0.05, 0.2, 0), c, Vector3(cos(ang) * 0.14, 0.24, sin(ang) * 0.14), Vector3(0, 0, 0))
		6:   # Bob
			_hair_cap(head, c)
			var bob := Toon.part(head, "sphere", Vector3(0.33, 0, 0), c, Vector3(0, -0.06, -0.06))
			bob.scale = Vector3(1.0, 0.8, 0.95)
		7:   # Dutt
			_hair_cap(head, c)
			Toon.part(head, "sphere", Vector3(0.13, 0, 0), c, Vector3(0, 0.34, -0.1))
		8:   # Zöpfe
			_hair_cap(head, c)
			for sx in [-1, 1]:
				var t := Toon.part(head, "capsule", Vector3(0.06, 0.55, 0), c, Vector3(0.2 * sx, -0.25, 0.0), Vector3(0, 0, 8 * sx))
				Toon.outline(t, 0.012)
		9:   # Wilde Mähne
			_hair_cap(head, c)
			Toon.part(head, "capsule", Vector3(0.34, 1.0, 0), c, Vector3(0, -0.35, -0.2))
			for i in 5:
				Toon.part(head, "cone", Vector3(0.07, 0.24, 0), c, Vector3((i - 2) * 0.1, 0.3, 0.02 * i), Vector3(-15, 0, (i - 2) * 12))
		10:  # hoher Pferdeschwanz
			_hair_cap(head, c)
			var pt := Toon.part(head, "capsule", Vector3(0.09, 0.7, 0), c, Vector3(0, 0.2, -0.32), Vector3(-35, 0, 0))
			Toon.outline(pt, 0.012)
		11:  # Locken
			_hair_cap(head, c)
			for i in 9:
				var ang2 := i * TAU / 9.0
				Toon.part(head, "sphere", Vector3(0.09, 0, 0), c, Vector3(cos(ang2) * 0.24, 0.06 - (i % 3) * 0.05, sin(ang2) * 0.24 - 0.03))


static func _hair_cap(head: Node3D, c: Color) -> void:
	var m := Toon.part(head, "sphere", Vector3(0.3, 0, 0), c, Vector3(0, 0.085, -0.075))
	m.scale = Vector3(1.0, 0.88, 1.0)
	Toon.outline(m, 0.01)


static func _beard(head: Node3D, style: int, c: Color) -> void:
	match style:
		1:
			var m := Toon.part(head, "sphere", Vector3(0.2, 0.5, 0), c.darkened(0.2), Vector3(0, -0.1, 0.06))
			m.scale = Vector3(1, 0.5, 1)
		2:
			Toon.part(head, "capsule", Vector3(0.17, 0.5, 0), c, Vector3(0, -0.18, 0.1))
		3:
			for i in 3:
				Toon.part(head, "capsule", Vector3(0.04, 0.4, 0), c, Vector3((i - 1) * 0.07, -0.28, 0.17), Vector3(10, 0, 0))
		4:
			Toon.part(head, "box", Vector3(0.2, 0.035, 0.04), c, Vector3(0, -0.07, 0.24), Vector3(0, 0, 0))
		5:
			Toon.part(head, "cone", Vector3(0.05, 0.28, 0), c, Vector3(0, -0.28, 0.2), Vector3(170, 0, 0))


static func _horns(head: Node3D, style: int) -> void:
	var bone := Color("#e8dcc0")
	for sx in [-1, 1]:
		match style:
			1:
				Toon.part(head, "cone", Vector3(0.04, 0.16, 0), bone, Vector3(0.11 * sx, 0.26, 0.02), Vector3(0, 0, -15 * sx))
			2:
				Toon.part(head, "cone", Vector3(0.05, 0.3, 0), bone, Vector3(0.14 * sx, 0.3, 0), Vector3(0, 0, -35 * sx))
				Toon.part(head, "cone", Vector3(0.035, 0.16, 0), bone, Vector3(0.28 * sx, 0.46, 0), Vector3(0, 0, -75 * sx))
			3:
				Toon.part(head, "torus", Vector3(0.12, 0.05, 0), bone, Vector3(0.2 * sx, 0.1, 0), Vector3(90, 0, 0))


static func _face_marks(head: Node3D, scar: int, tattoo: int, accent: Color) -> void:
	var dark := Color("#6b2a2a")
	match scar:
		1: Toon.part(head, "box", Vector3(0.02, 0.16, 0.01), dark, Vector3(-0.09, 0.03, 0.235), Vector3(0, 0, 15), null, false)
		2: Toon.part(head, "box", Vector3(0.1, 0.02, 0.01), dark, Vector3(0.12, -0.06, 0.2), Vector3(0, 30, -10), null, false)
		3: Toon.part(head, "box", Vector3(0.12, 0.02, 0.01), dark, Vector3(0, 0.16, 0.225), Vector3(0, 0, 8), null, false)
	match tattoo:
		1:
			for i in 2:
				Toon.part(head, "box", Vector3(0.1, 0.018, 0.01), accent, Vector3(0.13, -0.02 - i * 0.05, 0.19), Vector3(0, 40, 0), Toon.glow_mat(accent, 0.8), false)
		2:
			for i in 3:
				Toon.part(head, "sphere", Vector3(0.015, 0, 0), accent, Vector3(-0.12 + i * 0.03, -0.08, 0.21), Vector3.ZERO, Toon.glow_mat(accent, 0.8), false)
		3:
			Toon.part(head, "box", Vector3(0.05, 0.05, 0.01), accent, Vector3(0, 0.2, 0.225), Vector3(0, 0, 45), Toon.glow_mat(accent, 1.0), false)


static func _weapon(wt: String, accent: Color) -> Node3D:
	var w := Node3D.new()
	var steel := Color("#c9d3dc")
	var wood := Color("#6b4a2a")
	match wt:
		"axe":
			Toon.part(w, "cyl", Vector3(0.025, 0.9, 0), wood, Vector3(0, 0, 0.45), Vector3(90, 0, 0))
			Toon.part(w, "box", Vector3(0.05, 0.3, 0.24), steel, Vector3(0, 0.1, 0.8))
		"hammer":
			Toon.part(w, "cyl", Vector3(0.03, 1.0, 0), wood, Vector3(0, 0, 0.5), Vector3(90, 0, 0))
			Toon.part(w, "box", Vector3(0.22, 0.22, 0.4), steel.darkened(0.15), Vector3(0, 0, 1.0))
		"dagger":
			Toon.part(w, "box", Vector3(0.03, 0.06, 0.4), steel, Vector3(0, 0, 0.3))
			Toon.part(w, "box", Vector3(0.12, 0.04, 0.04), accent, Vector3(0, 0, 0.08))
		"bow":
			# Gebogener Bogen: Wirbelsäule entlang Z, Wölbung nach -Y, Sehne gerade
			var n := 8
			var prev := Vector3(0, 0, -0.6)
			for i in range(1, n + 1):
				var t := -1.0 + 2.0 * float(i) / n
				var cur := Vector3(0, -0.16 * (1.0 - t * t), t * 0.6)
				var d := cur - prev
				Toon.part(w, "box", Vector3(0.035, 0.035, d.length() + 0.01), wood, (prev + cur) * 0.5,
					Vector3(rad_to_deg(atan2(-d.y, d.z)), 0, 0))
				prev = cur
			Toon.part(w, "box", Vector3(0.008, 0.008, 1.2), Color("#e8e0c8"), Vector3(0, 0, 0))
		"staff":
			Toon.part(w, "cyl", Vector3(0.03, 1.4, 0), wood, Vector3(0, 0.2, 0.2), Vector3(70, 0, 0))
			Toon.part(w, "sphere", Vector3(0.1, 0, 0), accent, Vector3(0, 0.66, 0.67), Vector3.ZERO, Toon.glow_mat(accent, 1.8))
		_:
			Toon.part(w, "box", Vector3(0.05, 0.1, 0.8), steel, Vector3(0, 0, 0.55))
			Toon.part(w, "box", Vector3(0.28, 0.05, 0.06), accent, Vector3(0, 0, 0.12))
			Toon.part(w, "cyl", Vector3(0.03, 0.2, 0), wood, Vector3(0, 0, 0.02), Vector3(90, 0, 0))
	return w
