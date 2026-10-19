class_name ItemModels
extends RefCounted
## Echte 3D-Modelle (Quaternius, CC0) für Beute am Boden, Truhen und sichtbare Ausrüstung.

const DIR := "res://assets/items/"
static var _cache: Dictionary = {}

const ARMOR_BY_RARITY := {"common": "ArmorLeather", "uncommon": "ArmorMetal", "rare": "ArmorMetal2", "epic": "ArmorBlack", "legendary": "ArmorGolden", "mythic": "ArmorGolden"}
const SWORDS := {"common": "Sword", "uncommon": "Sword", "rare": "SwordBig", "epic": "SwordBig", "legendary": "SwordGolden", "mythic": "SwordGolden"}
const SHIELDS := ["ShieldRound", "ShieldHeater", "ShieldRound_2", "ShieldHeater_2", "ShieldCelticGolden"]
const ARTIFACTS := ["Crystal2", "Chalice", "Book3Closed", "Star", "Skull", "Crystal1", "Heart", "Crystal5"]


static func exists(n: String) -> bool:
	return ResourceLoader.exists(DIR + n + ".glb")


static func model_name(item: Dictionary) -> String:
	var slot := str(item.get("slot", ""))
	var rar := str(item.get("rarity", "common"))
	var h := absi(hash(str(item.get("uid", item.get("name", "")))))
	match slot:
		"weapon":
			match str(item.get("weapon_type", "sword")):
				"axe": return "AxeDouble" if rar in ["epic", "legendary", "mythic"] else "Axe"
				"hammer": return "HammerDouble"
				"dagger": return "Dagger"
				"bow": return "BowWooden"
				"staff": return "IceStaff" if rar in ["rare", "epic", "legendary", "mythic"] else "WoodenStaff"
				_: return str(SWORDS.get(rar, "Sword"))
		"head": return "Crown" if rar in ["legendary", "mythic"] else ("Crown2" if rar == "epic" else "KnightHelmet")
		"chest": return str(ARMOR_BY_RARITY.get(rar, "ArmorLeather"))
		"hands": return "Glove"
		"legs": return "Pouch"
		"feet": return "Bag"
		"amulet": return "Necklace%d" % (h % 3 + 1)
		"ring1", "ring2": return "Ring%d" % (h % 7 + 1)
		"artifact": return str(ARTIFACTS[h % ARTIFACTS.size()])
		"offhand": return str(SHIELDS[h % SHIELDS.size()])
	return "Gems"


## Instanz, größte Kantenlänge = size, Unterkante bei y=0, in x/z zentriert.
static func make(n: String, size: float) -> Node3D:
	if not exists(n):
		return null
	if not _cache.has(n):
		_cache[n] = load(DIR + n + ".glb")
	var inst: Node3D = (_cache[n] as PackedScene).instantiate()
	var box := AABB()
	var first := true
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (mi as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	var big: float = maxf(0.001, maxf(box.size.x, maxf(box.size.y, box.size.z)))
	var s := size / big
	var holder := Node3D.new()
	inst.scale = Vector3.ONE * s
	inst.position = Vector3(-(box.position.x + box.size.x * 0.5) * s, -box.position.y * s, -(box.position.z + box.size.z * 0.5) * s)
	holder.add_child(inst)
	return holder
