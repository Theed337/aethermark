#!/usr/bin/env python3
"""Erzeugt data/talents.json aus einer kompakten Beschreibung der Aeste.

Der Talentbaum ist datengetrieben: neue Aeste/Knoten koennen hier (oder direkt in
der JSON-Datei) ergaenzt werden, ohne Spiellogik zu aendern.
Ausfuehren:  python3 tools/gen_data.py
"""
import json, math, os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

# (id, Name, Beschreibung des Astes, Hauptfarbe, [(Knotenname, Typ, Effekte)])
BRANCHES = [
    ("melee", "Nahkampf & schwere Waffen", "#d9694a", [
        ("Kraftvoll", "small", {"melee_dmg_pct": 0.06}),
        ("Eisenhaut", "small", {"max_hp_pct": 0.05, "defense": 2}),
        ("Schlachtrausch", "large", {"melee_dmg_pct": 0.15, "attack_speed_pct": 0.05}),
        ("Wucht", "transform", {"melee_dmg_pct": 0.10, "flags": ["heavy_light_attacks"]}),
    ]),
    ("swift", "Schnelle Waffen & Kritische Treffer", "#e8c547", [
        ("Scharfes Auge", "small", {"crit_chance": 0.03}),
        ("Flinke Hand", "small", {"attack_speed_pct": 0.06}),
        ("Klingentanz", "large", {"crit_chance": 0.06, "crit_mult": 0.20}),
        ("Meister der Klinge", "specialization", {"crit_mult": 0.35, "attack_speed_pct": 0.08}),
    ]),
    ("ranged", "Bögen & Fernkampf", "#7fc46b", [
        ("Ruhige Hand", "small", {"ranged_dmg_pct": 0.06}),
        ("Weitsicht", "small", {"area_pct": 0.05, "crit_chance": 0.02}),
        ("Scharfschütze", "large", {"ranged_dmg_pct": 0.16, "crit_chance": 0.04}),
        ("Schnellfeuer", "specialization", {"ranged_dmg_pct": 0.12, "attack_speed_pct": 0.10}),
    ]),
    ("elemental", "Elementarmagie", "#ff8a3d", [
        ("Funkenschlag", "small", {"elem_dmg_pct": 0.06}),
        ("Glutherz", "small", {"mana_max": 10, "elem_dmg_pct": 0.03}),
        ("Elementarsturm", "large", {"elem_dmg_pct": 0.16, "area_pct": 0.06}),
        ("Meteor-Wandlung", "transform", {"elem_dmg_pct": 0.10, "flags": ["fireball_meteor"]}),
    ]),
    ("dark", "Dunkle Magie & Fluch", "#9b5de5", [
        ("Schattenfaden", "small", {"dot_dmg_pct": 0.08}),
        ("Seelenhunger", "small", {"lifesteal": 0.01}),
        ("Verderben", "large", {"dot_dmg_pct": 0.18, "elem_dmg_pct": 0.05}),
        ("Blutpakt", "specialization", {"lifesteal": 0.03, "melee_dmg_pct": 0.08}),
    ]),
    ("summon", "Beschwörungen & Begleiter", "#4ecdc4", [
        ("Rufer", "small", {"summon_dmg_pct": 0.08}),
        ("Band der Geister", "small", {"summon_dmg_pct": 0.05, "hp_regen": 0.5}),
        ("Herr der Geister", "large", {"summon_dmg_pct": 0.18, "summon_count": 1}),
        ("Schwarmgeist", "specialization", {"summon_dmg_pct": 0.12, "summon_count": 1}),
    ]),
    ("defense", "Verteidigung & Überleben", "#5aa9e6", [
        ("Zäh", "small", {"max_hp_pct": 0.06}),
        ("Plattenpanzer", "small", {"defense": 4}),
        ("Bollwerk", "large", {"max_hp_pct": 0.14, "defense": 6}),
        ("Unerschütterlich", "specialization", {"defense": 8, "hp_regen": 1.0}),
    ]),
    ("support", "Heilung & Unterstützung", "#f4a6c0", [
        ("Linderung", "small", {"heal_power_pct": 0.08}),
        ("Lebensquell", "small", {"hp_regen": 0.8}),
        ("Segenbringer", "large", {"heal_power_pct": 0.20, "hp_regen": 0.8}),
        ("Schutzengel", "specialization", {"heal_power_pct": 0.25, "max_hp_pct": 0.05}),
    ]),
    ("tactics", "Fallen, Gadgets & Taktik", "#c9a227", [
        ("Späher", "small", {"pickup_radius_pct": 0.15}),
        ("Pionier", "small", {"area_pct": 0.06}),
        ("Taktiker", "large", {"area_pct": 0.14, "elem_dmg_pct": 0.05}),
        ("Sprengmeister", "specialization", {"area_pct": 0.12, "damage_pct": 0.05}),
    ]),
    ("agility", "Beweglichkeit & Ausweichen", "#6ee7b7", [
        ("Leichtfüßig", "small", {"move_speed_pct": 0.04}),
        ("Gewandt", "small", {"dodge_iframes": 0.03}),
        ("Schattenschritt", "large", {"move_speed_pct": 0.08, "dodge_iframes": 0.05}),
        ("Windtänzer", "specialization", {"move_speed_pct": 0.08, "attack_speed_pct": 0.05}),
    ]),
    ("resource", "Ressourcen & Abklingzeiten", "#8ecae6", [
        ("Konzentration", "small", {"mana_regen_pct": 0.10}),
        ("Tiefer Brunnen", "small", {"mana_max": 15}),
        ("Zeitfluss", "large", {"cooldown_reduction": 0.08, "mana_regen_pct": 0.10}),
        ("Meister der Zeit", "specialization", {"cooldown_reduction": 0.10, "mana_max": 20}),
    ]),
]

# Synergien verbinden benachbarte Aeste (benoetigen BEIDE Nachbarn)
SYNERGIES = [
    ("swift", "elemental", "Frostkritiker", {"crit_chance": 0.04, "elem_dmg_pct": 0.08}),
    ("summon", "dark", "Seelenmeute", {"summon_dmg_pct": 0.10, "dot_dmg_pct": 0.10}),
    ("melee", "defense", "Eiserner Wall", {"melee_dmg_pct": 0.08, "defense": 4}),
    ("support", "summon", "Geistheiler", {"heal_power_pct": 0.10, "summon_dmg_pct": 0.06}),
    ("agility", "swift", "Klingenwind", {"move_speed_pct": 0.05, "crit_chance": 0.03}),
    ("resource", "elemental", "Arkaner Fluss", {"cooldown_reduction": 0.06, "elem_dmg_pct": 0.06}),
]

CENTER = (600, 420)
START_RADIUS = 95
STEP = 78


def main():
    nodes = {}
    n = len(BRANCHES)
    pos_of = {}
    for i, (bid, bname, color, entries) in enumerate(BRANCHES):
        ang = -math.pi / 2 + i * (2 * math.pi / n)
        prev = None
        for k, (nm, typ, eff) in enumerate(entries):
            r = START_RADIUS + k * STEP
            x = CENTER[0] + math.cos(ang) * r * 1.35
            y = CENTER[1] + math.sin(ang) * r
            nid = f"{bid}_{k+1}"
            cost = {"small": 1, "large": 2, "specialization": 3, "transform": 3, "synergy": 2}[typ]
            nodes[nid] = {
                "id": nid, "name": nm, "branch": bid, "type": typ, "cost": cost,
                "pos": [round(x), round(y)], "color": color,
                "requires": [prev] if prev else [], "requires_mode": "any",
                "effects": eff,
            }
            pos_of[nid] = (x, y)
            prev = nid
    for a, b, nm, eff in SYNERGIES:
        ida, idb = f"{a}_3", f"{b}_3"
        mx = (pos_of[ida][0] + pos_of[idb][0]) / 2
        my = (pos_of[ida][1] + pos_of[idb][1]) / 2
        # etwas nach aussen schieben, damit der Knoten zwischen den Aesten liegt
        dx, dy = mx - CENTER[0], my - CENTER[1]
        d = math.hypot(dx, dy) or 1
        mx += dx / d * 28
        my += dy / d * 28
        nid = f"syn_{a}_{b}"
        nodes[nid] = {
            "id": nid, "name": nm, "branch": "synergy", "type": "synergy", "cost": 2,
            "pos": [round(mx), round(my)], "color": "#ffffff",
            "requires": [ida, idb], "requires_mode": "all", "effects": eff,
        }
    out = {
        "center": list(CENTER),
        "branches": [{"id": b[0], "name": b[1], "color": b[2]} for b in BRANCHES],
        "nodes": nodes,
    }
    path = os.path.join(ROOT, "data", "talents.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    print(f"{len(nodes)} Talente -> {path}")


if __name__ == "__main__":
    main()
