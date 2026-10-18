# Architektur

## Engine-Entscheidung: Godot 4.3 statt Unreal Engine
- Läuft auf Windows und Mobile (Godot-Export Android/iOS), kleine Auslieferung, GDScript = schnelle Iteration.
- In dieser Umgebung steht Godot headless zur Verfügung, sodass Logik und Netzwerk **automatisiert getestet** werden konnten;
  Unreal wäre hier weder installierbar noch testbar gewesen.
- Nachteil: weniger Hochglanz-Grafik/Tooling als Unreal. Der Stil ist daher bewusst stilisiert (Toon-Shading, Outlines, Glow).

## Schichten
- `scripts/core/` – reine Logik ohne Szene (Talente, Loot, Progression, ItemValidator, Spielregeln). Voll testbar (`tests/test_runner`).
- `scripts/autoload/` – GameData (JSON-Daten), SaveSystem (versioniert, Backup, Migration), RunState, Sfx (prozedural), InputSetup (Tastatur/Controller).
- `data/*.json` – Gebiete, Gegner, Elitemods, Boss, Items, Talente, Erfolge: Inhalte datengetrieben, ohne Codeänderung erweiterbar.
- `scripts/player`, `scripts/enemies`, `scripts/world` – Spiel im Run. `scripts/ui` – Menüs/HUD. `scripts/net` – Netzwerk.
- Eingabe ist von Spiellogik getrennt (`gather_input`, ACT_*-Aktionen) → Touch-Steuerung später ergänzbar, ohne Kampf neu zu schreiben.

## Netzwerk (Entscheidung: Listen-Server, host-autoritativ)
- ENet (UDP), Host = Spieler 1 = Server. Lobby-Code = Base32(IPv4+Port).
- Host simuliert Gegner, Schaden, Beute, Level-Up-Angebote, Wiederbelebung, Wipe. Clients senden nur Eingaben
  (Position/Blick/gehaltene Tasten 30 Hz, Aktionen zuverlässig, Anfragen). Host prüft Position (Tempolimit/Radius, Korrektur per `_correct`).
- Snapshots 15 Hz (unzuverlässig): Spieler, Gegner (6 floats), Geschosse; private Daten pro Client 20 Hz; Ereignisse zuverlässig;
  Effekte/Sounds gebündelt.
- Clients zeigen "Geister"-Gegner (nur Darstellung/Animation) und Puppen für Mitspieler; Client-Vorhersage nur für den eigenen Spieler.
- Cheat-Schutz (ehrlich): Der Host ist vertrauenswürdig. Bauten der Clients werden vom Host via ItemValidator/Talentprüfung validiert,
  Ergebnisse werden vor dem Speichern lokal gefiltert. Ein manipulierter **Host** kann alles – das ist bei Host-Server prinzipbedingt so.
- Wiederbeitritt: Token + Slot, 90 s Gnadenfrist; Version via PROTOCOL.
- Koop-Regeln: persönliche Beute, geteilte XP (0.45+0.55/n), Level-Up pro Spieler (25 s Auto-Wahl), Wiederbeleben 3 s per Halten (2,4 m), 30 s Verblutzeit, Wipe wenn alle 2 s am Boden.

## Tests
Siehe README. Mehrprozess-Netztest (`tests/run_net_test.py`) startet echte Prozesse und prüft Sync, Wiederbelebung, Abbruch/Wiederbeitritt, Ergebnisse.
