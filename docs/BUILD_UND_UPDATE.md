# Build, Installation, Updates

## Muss man das Spiel installieren?
Nein. Ein Godot-Export ist eine einzelne `.exe` (PCK eingebettet, siehe `export_presets.cfg`). Zip entpacken, starten.
Optional später: ein Installer (z. B. Inno Setup, kostenlos) für Startmenü-Eintrag und Deinstallation – technisch nicht notwendig.

## Windows-Build erzeugen
1. Godot 4.3 → Editor → *Projekt → Export → Export-Vorlagen verwalten → Herunterladen* (einmalig, ca. 1 GB; das ging in der
   Entwicklungsumgebung nicht, daher ist der Export hier **nicht** ausgeführt/getestet).
2. `godot --headless --path . --export-release "Windows Desktop" build/windows/Aethermark.exe`
3. `Aethermark.exe` + ggf. Zip zum Verteilen. Windows SmartScreen warnt bei unsignierten Programmen; Code-Signing ist optional.

## Updater / Launcher – Empfehlung
Für ein Koop-Spiel mit Host-als-Server ist ein **voller Launcher nicht sinnvoll** (viel Aufwand, Fehlerquelle, Wartung).
Stattdessen umgesetzt bzw. empfohlen:
1. **Versionsschutz im Spiel (fertig):** Beim Beitritt prüft der Host `PROTOCOL`; abweichende Versionen werden mit klarer Meldung abgelehnt.
2. **Update-Hinweis (fertig, standardmäßig aus):** `scripts/core/update_check.gd` lädt eine `version.json` von `UPDATE_URL`
   und zeigt im Hauptmenü „Update x.y.z verfügbar – Link“. URL eintragen (z. B. GitHub Releases), `config/version` in `project.godot` hochzählen.
3. **Verteilung:** GitHub Releases oder itch.io. itch.io bietet einen optionalen Auto-Update-Client (butler/itch app) ohne eigenen Launcher.
4. Erst wenn es viele Spieler und häufige Patches gibt: kleiner Launcher, der `version.json` liest und eine neue `.exe` ersetzt.

## Server-Modell (wie Diablo 3)
Der einladende Spieler ist Host und Server (ENet-Listen-Server, bis 5 Spieler). Kein Betrieb eigener Server nötig.
Nachteil: Host-Verbindung bestimmt die Qualität; Hostet jemand mit CGNAT, hilft nur VPN-Overlay oder später ein Relay-Dienst.
