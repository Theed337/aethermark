# Ehrlicher Statusbericht (Stand dieser Version 0.9.4)

## Fertig und getestet
- Kernlogik: Loot/Seltenheiten, Item-Validierung, Talentbaum (ohne Klassen), Progression, Speichern mit Backup – 65 000+ automatisierte Prüfungen.
- Solo-Run im Wald: Bewegung, Kampf (mehrere Waffentypen), Fertigkeiten, Ausweichen, Gegner-KI (5 Typen, 3 Elite-Mods), Mini-Bosse, Boss „Wurzelwächter“ (3 Phasen), XP/Level-Up mit zufälligen Auswahlen, Truhen, Schreine, Beute, Ergebnisbildschirm, Speichern.
- Hauptmenü mit Bereichen, Charaktereditor, Talentbaum-UI, Inventar/Ausrüstung.
- Koop 2–5 Spieler (Host-Server): Lobby, Lobby-Code, UPnP-Versuch, Run-Synchronisierung, Wiederbelebung, Wipe, Verbindungsabbruch + Wiederbeitritt, persönliche Beute, Ergebnis je Spieler.
  **Getestet mit echten Prozessen über localhost** (2, 3, 5 Spieler, mit erzwungenem Niederschlag und Wiederbeitritt).

- Zufallsereignisse im Run (Blutmond, Hinterhalt mit Elitegegnern, Zeitjagd) mit Belohnung; Koop-Elementkombos (5 Paare aus Feuer/Frost/Blitz/Erde, nur bei zwei verschiedenen Spielern); Flüche ab Albtraum/Inferno (härter, bessere Beute). Logik per Unit-Test und Bot-/Netztest abgedeckt; **Spielgefühl/Balance dieser Systeme ungetestet** (kein Mensch hat sie gespielt).

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
- Weitere Ereignisse (Verteidigung, Händler), interaktive Umgebung (explosive Fässer etc.), Wahl der Flüche durch den Spieler (aktuell zufällig), Heimatbasis, eigene Kartenlayouts je Gebiet.
- Subjektive Spielbarkeit/Balance auf echter Hardware mit Grafikkarte: hier nur per Bot-Läufe headless geprüft.


## Änderungen 0.9.2 (Feedback-Runde nach Test von 0.9.1)
- Charaktereditor: Figur sichtbar und zentriert, Panels passen sich der Fensterbreite an (UI-Basis 1920x1080, skalierbar).
- Welt: Flackern behoben (Transparenz-Pipeline nur noch für wirklich durchsichtige Materialien), neuer Boden-Shader, Gras, Wind, Schatten, Tonemapping.
- HUD im Diablo-3-Stil: Lebens-/Ressourcenkugel, Skillleiste mit Icons, Minimap, Gruppenanzeige, Fähigkeiten-Übersicht (Taste K).
- Talentbaum: Ansicht passt sich dem Baum an, erlernte Talente werden als Liste mit Effekten angezeigt.
- Charaktermodell: Gesicht, Stiefel, Schulterpanzer, Gürtel, Unterarmschienen.
## Ehrlich: nicht verifiziert
- Die Forward+-Effekte (SSAO, Volumetrik, Helligkeit nach Tonemapping) konnte ich hier nicht rendern (nur Compatibility-Renderer). Wie es auf deinem PC aussieht, ist ungeprüft.
- "Triple-A"-Grafik ist mit prozeduralen Primitiven nicht erreichbar; das ist eine deutlich verbesserte Stilisierung, kein AAA-Niveau. Dafür bräuchte es echte Modelle/Texturen.
- GitHub-Push weiterhin nicht erfolgt (Token ungültig).


## Änderungen 0.9.3
- Balance: Level-Kurve ca. 2x flacher (weniger Fähigkeiten-Angebote), normale Gegner droppen selten (2,5 %), Elite ca. 45 %, Boss 3 statt 4 Raredrops.
  Testlauf-Bot (Einzelspieler) schlägt den Boss meist bei Stufe ~10 nach ~7,5 Min; ein Lauf von drei scheiterte (Bot-Zufall). Echte Spielbarkeit ungeprüft.
- Eigene Grafik: tools/gen_textures.py erzeugt 9 nahtlose Texturen (Gras, Erde, Fels, Rinde, Laub, Stoff, Leder, Metall, Mauerwerk) mit Höhenkarten; triplanar im Shader samt Relief.
- Eigener Mesh-Generator (scripts/fx/mesh_kit.gd): Torso/Gliedmaßen/Kopf, kantige Felsen, weiche Laubkronen, Stämme mit Wurzelanlauf.
- Ungeprüft: Aussehen im Forward+-Renderer (hier nur Compatibility-Renderer testbar). Gegner und Bosse nutzen noch die alten Primitive.
- GitHub: Sitzung ist an andere Repos gebunden, Push von Aethermark nicht möglich (siehe Antwort).


## Änderungen 0.9.4 (echte Assets)
- Held: Skelett-Modell (Quaternius Mannequin, CC0) mit Animationen (Idle/Sword_Idle, Walk, Jog, Sprint, Schwertangriff, Zauber, Rolle, Tod). Farben je Körperregion aus dem Editor, Gesicht/Haare/Ohren/Hörner/Waffe als angehängte Teile.
  Das Modell hat KEINE Kleidungsgeometrie (nackte Puppe, nur eingefärbt); Rüstungsoptik ist offen. Waffenausrichtung nur für das Schwert per Screenshot abgestimmt, andere Waffen ungeprüft.
- Welt: echte Bäume (Common/Pine/GiantPine/Cherry/Dead/Twisted), Büsche, Farne, Pflanzen, Blumen, Pilze und Felsen (Quaternius Stylized Nature MegaKit, CC0), je Gebiet gewählt; Rückfall auf prozedurale Formen, falls Dateien fehlen.
- Gegner, Bosse, Ruinen-Säulen und Gras sind weiter prozedural (keine passenden CC0-Pakete hier verfügbar).
- Ungeprüft: Leistung auf echter Hardware (ca. 95 Bäume + Schatten), Aussehen im Forward+-Renderer, Animationen aller Waffentypen.
- Balance-Test (Einzelspieler-Bot) schlägt den Boss nur noch in etwa jedem zweiten Lauf (Bot spielt schwach, echte Spieler ausweichen). Level-Tempo ggf. nachjustieren.
