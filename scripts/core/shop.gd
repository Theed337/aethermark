class_name Shop
extends RefCounted
## Mini-Händler: Verkauf von Gegenständen gegen Gold und ein Angebot, das sich alle 20 Minuten (Echtzeit) erneuert.
## Das Angebot ist aus der Rotationsnummer + Charakter-ID abgeleitet (ohne Speichern der Gegenstände), gekaufte Plätze
## werden im Charakter vermerkt. Gold gibt es für Runs und Verkäufe, es ist reines Spielgeld (kein Echtgeld).

const ROTATION_SECONDS := 1200
const STOCK_SIZE := 8
const BASE_VALUE := {"common": 8, "uncommon": 22, "rare": 60, "epic": 150, "legendary": 420, "mythic": 950}


static func rotation_id(now: float = -1.0) -> int:
	if now < 0.0:
		now = Time.get_unix_time_from_system()
	return int(now / ROTATION_SECONDS)


static func seconds_left(now: float = -1.0) -> int:
	if now < 0.0:
		now = Time.get_unix_time_from_system()
	return ROTATION_SECONDS - int(fmod(now, ROTATION_SECONDS))


static func item_value(it: Dictionary) -> float:
	return float(BASE_VALUE.get(it.get("rarity", "common"), 8)) * (1.0 + 0.12 * float(it.get("level", 1)))


static func sell_price(it: Dictionary) -> int:
	return maxi(int(round(item_value(it) * 0.5)), 1)


static func buy_price(it: Dictionary) -> int:
	return maxi(int(round(item_value(it) * 2.4)), 5)


static func can_sell(c: Dictionary, it: Dictionary) -> bool:
	if it.is_empty() or it.get("locked", false):
		return false
	for s in c.get("equipment", {}):
		if c["equipment"][s] == it["uid"]:
			return false
	return true


static func sell(c: Dictionary, uid: String) -> int:
	var it := SaveSystem.find_item(c, uid)
	if not can_sell(c, it):
		return -1
	var p := sell_price(it)
	SaveSystem.remove_item(c, uid)
	c["gold"] = int(c.get("gold", 0)) + p
	return p


## Angebot der aktuellen Rotation: Array von {"item", "price", "idx", "sold"}.
static func stock(c: Dictionary, rot: int = -1) -> Array:
	if rot < 0:
		rot = rotation_id()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(c.get("id", "")) + "|" + str(rot))
	var lvl := maxi(int(c.get("meta_level", 1)) * 2 + 1, 2)
	var bought: Array = []
	var sh: Dictionary = c.get("shop", {})
	if int(sh.get("rot", -1)) == rot:
		bought = sh.get("bought", [])
	var out: Array = []
	for i in STOCK_SIZE:
		var it := Loot.roll_item(rng, lvl + rng.randi_range(-1, 3), 1.0)
		it["uid"] = "s%d_%d_%d" % [rot, i, rng.randi() % 100000]
		it["tradable"] = false   # Händlerware ist an den Kaufenden gebunden
		out.append({"item": it, "price": buy_price(it), "idx": i, "sold": i in bought})
	return out


## 0 = ok, sonst Fehlertext.
static func buy(c: Dictionary, idx: int, rot: int = -1) -> String:
	if rot < 0:
		rot = rotation_id()
	var st := stock(c, rot)
	if idx < 0 or idx >= st.size():
		return "Ungültiges Angebot."
	var e: Dictionary = st[idx]
	if e["sold"]:
		return "Schon verkauft."
	if int(c.get("gold", 0)) < int(e["price"]):
		return "Nicht genug Gold."
	if c["inventory"].size() >= SaveSystem.INVENTORY_CAP:
		return "Inventar voll."
	var it: Dictionary = e["item"]
	if not SaveSystem.add_item(c, it):
		return "Inventar voll."
	c["gold"] = int(c.get("gold", 0)) - int(e["price"])
	var sh: Dictionary = c.get("shop", {})
	if int(sh.get("rot", -1)) != rot:
		sh = {"rot": rot, "bought": []}
	sh["bought"].append(idx)
	c["shop"] = sh
	return ""
