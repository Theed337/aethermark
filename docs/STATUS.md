# Ehrlicher Statusbericht (Stand dieser Version 0.9.0)

## Fertig und getestet
- Kernlogik: Loot/Seltenheiten, Item-Validierung, Talentbaum (ohne Klassen), Progression, Speichern mit Backup – 65 000+ automatisierte Prüfungen.
- Solo-Run im Wald: Bewegung, Kampf (mehrere Waffentypen), Fertigkeiten, Ausweichen, Gegner-KI (5 Typen, 3 Elite-Mods), Mini-Bosse, Boss „Wurzelwächter“ (3 Phasen), XP/Level-Up mit zufälligen Auswahlen, Truhen, Schreine, Beute, Ergebnisbildschirm, Speichern.
- Hauptmenü mit Bereichen, Charaktereditor, Talentbaum-UI, Inventar/Ausrüstung.
- Koop 2–5 Spieler (Host-Server): Lobby, Lobby-Code, UPnP-Versuch, Run-Synchronisierung, Wiederbelebung, Wipe, Verbindungsabbruch + Wiederbeitritt, persönliche Beute, Ergebnis je Spieler.
  **Getestet mit echten Prozessen über localhost** (2, 3, 5 Spieler, mit erzwungenem Niederschlag und Wiederbeitritt).

## Teilweise / eingeschränkt
- Nur **ein** Gebiet (Smaragdwald) spielbar; Gebiete 2–6 sind in den Daten angelegt, aber noch nicht umgesetzt (Arena ist noch fest an die Waldkarte gebunden).
- Nur ein Boss, 5 Gegnertypen: weniger Vielfalt als im Lastenheft.
- Handel zwischen Spielern: Grundlogik vorhanden (NetTrade), nicht mit Mehrprozess-Test abgedeckt.
- Grafik/Audio: stilisiert und prozedural (keine Künstler-Assets); Sounds synthetisch.
- Netzwerk nur auf localhost getestet – nicht über echtes Internet/NAT. UPnP-Funktion ist implementiert, aber hier nicht realtestbar.
- Update-Hinweis vorhanden, aber ohne konfigurierte URL inaktiv; kein Launcher (bewusst, siehe BUILD_UND_UPDATE.md).

## Fehlt
- Windows-Export wurde **nicht** gebaut (Export-Vorlagen nicht verfügbar); `export_presets.cfg` ist vorbereitet, ungetestet.
- Mobile-Touch-Steuerung und Mobile-Export (nur Architektur vorbereitet).
- Gebiete 2–6, weitere Bosse/Gegnerfamilien, Zufallsereignisse, Artefakte mit Nachteilen, interaktive Umgebung, Koop-Kombos, Endgame-Modifikatoren, Heimatbasis.
- Subjektive Spielbarkeit/Balance auf echter Hardware mit Grafikkarte: hier nur per Bot-Läufe headless geprüft.
