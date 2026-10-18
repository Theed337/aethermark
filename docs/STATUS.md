# Ehrlicher Statusbericht (Stand dieser Version 0.9.0)

## Fertig und getestet
- Kernlogik: Loot/Seltenheiten, Item-Validierung, Talentbaum (ohne Klassen), Progression, Speichern mit Backup – 65 000+ automatisierte Prüfungen.
- Solo-Run im Wald: Bewegung, Kampf (mehrere Waffentypen), Fertigkeiten, Ausweichen, Gegner-KI (5 Typen, 3 Elite-Mods), Mini-Bosse, Boss „Wurzelwächter“ (3 Phasen), XP/Level-Up mit zufälligen Auswahlen, Truhen, Schreine, Beute, Ergebnisbildschirm, Speichern.
- Hauptmenü mit Bereichen, Charaktereditor, Talentbaum-UI, Inventar/Ausrüstung.
- Koop 2–5 Spieler (Host-Server): Lobby, Lobby-Code, UPnP-Versuch, Run-Synchronisierung, Wiederbelebung, Wipe, Verbindungsabbruch + Wiederbeitritt, persönliche Beute, Ergebnis je Spieler.
  **Getestet mit echten Prozessen über localhost** (2, 3, 5 Spieler, mit erzwungenem Niederschlag und Wiederbeitritt).

## Teilweise / eingeschränkt
- Alle 6 Gebiete spielbar, aber **gleiches Kartenlayout** (Startlichtung, Gefahrenzone, Ruinen, Bossarena); Unterschiede: Farbwelt/Himmel, Baumstil, Gefahrenzone (Lava/Gift/Eis/Leere = Schaden über Zeit), Gegner-Skins, zusätzliche Gegner (Kriecher, Wächterschütze, Teiler der zerfällt, Kultist), eigene Bedrohungsstufen. Getestet per Bot: Wald, Ruinen, Aschelande (Solo) und Aschelande im 3er-Koop; Frost/Schatten/Himmel starten und laufen, ein frischer Test-Charakter ohne Ausrüstung schafft sie aber nicht – **Balance der späten Gebiete ungeprüft**.
- 6 Bosse (Wurzelwächter, Uhrwerkwächter, Lavatitan, Frostwyrm, Spiegelhexe, Himmelsherrscher): gemeinsames 3-Phasen-Gerüst mit je eigener Gestalt, Werten, Begleitern, Mehrfach-Schlägen/Wellen und Ansturm-Linie. **Keine völlig eigenständigen Mechaniken** pro Boss.
- 5 Boss-Artefakte mit Nachteil (je Boss eines) neben den 4 bisherigen Artefakten.
- Gegnervielfalt: 9 Typen statt der geplanten ~15; keine fliegenden Gegner.
- Handel zwischen Spielern: Grundlogik vorhanden (NetTrade), nicht mit Mehrprozess-Test abgedeckt.
- Grafik/Audio: stilisiert und prozedural (keine Künstler-Assets); Sounds synthetisch.
- Netzwerk nur auf localhost getestet – nicht über echtes Internet/NAT. UPnP-Funktion ist implementiert, aber hier nicht realtestbar.
- Update-Hinweis vorhanden, aber ohne konfigurierte URL inaktiv; kein Launcher (bewusst, siehe BUILD_UND_UPDATE.md).

## Fehlt
- Windows-Export wurde **nicht** gebaut (Export-Vorlagen nicht verfügbar); `export_presets.cfg` ist vorbereitet, ungetestet.
- Mobile-Touch-Steuerung und Mobile-Export (nur Architektur vorbereitet).
- Zufallsereignisse (Verteidigung, Händler, Zeit-Herausforderung), interaktive Umgebung (Fässer etc.), Koop-Elementkombos, Endgame-Modifikatoren/Flüche, Heimatbasis, eigene Kartenlayouts je Gebiet.
- Subjektive Spielbarkeit/Balance auf echter Hardware mit Grafikkarte: hier nur per Bot-Läufe headless geprüft.
