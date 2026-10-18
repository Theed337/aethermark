# Aethermark (Arbeitstitel)

3D-Fantasy-Action-Roguelite für 1–5 Spieler (Solo oder Online-Koop), gebaut mit **Godot 4.3** (GDScript).
Zuerst für Windows-PC, Architektur ist für Mobile vorbereitet (siehe docs/ARCHITEKTUR.md).

## Starten (Entwicklung)
1. Godot 4.3 (Standard-Version, nicht .NET) installieren: https://godotengine.org/download
2. Projektordner öffnen (`project.godot`) und F5 drücken – oder: `godot --path . `
3. Hauptmenü → Charakter erstellen → „Run starten“ (Wald) oder „Gruppe“ für Koop.

## Spielen als Endnutzer
Nach dem Export (siehe docs/BUILD_UND_UPDATE.md) ist das Spiel eine einzelne `Aethermark.exe`. **Keine Installation nötig**,
einfach entpacken und starten. Spielstände liegen im Benutzerordner (`%APPDATA%\Godot\app_userdata\Aethermark`).

## Koop (wie bei Diablo 3: der Einladende hostet)
- Spieler A: Menü „Gruppe“ → „Gruppe eröffnen“. Es erscheint ein **Lobby-Code** (kodiert öffentliche IP + Port; zusätzlich ein LAN-Code).
- Spieler B–E: „Gruppe“ → Code eingeben → beitreten. Bereit drücken, Host startet.
- Der Host ist der Server (autoritativ). Es gibt keinen Dedizierten Server und keine Cloud.
- Port-Freigabe: das Spiel versucht automatisch UPnP (UDP 24565). Klappt das nicht (CGNAT/Router ohne UPnP): Port manuell freigeben
  oder ein VPN-Overlay (z. B. Radmin/ZeroTier/Tailscale) nutzen und die VPN-Adresse als Code-Quelle verwenden.
- Verbindungsabbruch: 90 s Wiederbeitritt mit demselben Charakter (Token), der Spieler bleibt in der Zeit am Platz (Bot-Schutz).

## Steuerung
WASD bewegen · Maus Kamera · LMB Angriff · RMB Fertigkeit · Shift Ausweichrolle · F Interagieren/Wiederbeleben (halten) ·
Tab Inventar/Talente im Menü · Esc Pause. Controller wird unterstützt (InputSetup).

## Tests
```
godot --headless --path . res://tests/load_all.tscn      # alle Skripte kompilieren
godot --headless --path . res://tests/test_runner.tscn   # Logik: Loot, Talente, Validator, Save, Progression
godot --headless --path . res://tests/menu_test.tscn     # Menüs/Seiten/Lobby-Logik
godot --headless --path . res://tests/smoke_run.tscn     # kompletter Solo-Run mit Bot, inkl. Speichern
python3 tests/run_net_test.py --players 5 --down-at 25   # echte Mehrprozess-Koop-Tests (localhost)
python3 tests/run_net_test.py --players 3 --rejoin       # inkl. Verbindungsabbruch + Wiederbeitritt
```
(Umgebungsvariable `GODOT` auf die Godot-Binärdatei setzen.) Headless erscheinen harmlose Meldungen
`mesh_get_surface_count … "m" is null` – das ist der Dummy-Renderer.

Ehrlicher Stand: **docs/STATUS.md**.
