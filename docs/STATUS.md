# Ehrlicher Statusbericht (Stand dieser Version 0.9.6)

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

## Änderungen 0.9.5 (Waffen, weibliche Figur, Spiegel, Inventar, Sound, Effekte)
- Waffen: Haltung per Screenshot in der Idle-Pose und im Schwertangriff abgestimmt (Schwert/Axt/Hammer/Dolch vorwärts-oben, Stab/Bogen schräg). Bogen ist jetzt ein gebogener Bogen mit Sehne. Stab/Bogen-Haltung nur grob (leicht schräg), Zauber-/Schussanimation nur als Standbild geprüft.
- Weibliche Figur: neue Option "Geschlecht" im Charaktereditor (Quaternius Female Mannequin, gleiche Animationen). Es ist weiterhin ein einfarbig eingefärbtes Mannequin ohne Kleidung; Bart wird bei weiblich ausgeblendet. Haare größer, Langhaar länger.
- Menü: die weißen Säulen mit Dreiecken sind weg; stattdessen 4 echte Spiegel (SubViewport mit gespiegelter Kamera, Rahmen). Kostet 4 zusätzliche Szenen-Renderings im Menü (Leistung auf echter Hardware ungeprüft).
- Inventar: Kachel-Raster mit Seltenheitsrahmen, grünem "ANGELEGT"-Streifen, Platz-Kacheln links (leere Plätze sichtbar), Doppelklick zum Anlegen/Ablegen, Tooltips.
- Sound: echte CC0-Aufnahmen statt Sinus-Piepsern (je Klang 3–4 Varianten). Ich kann sie nicht hören; Auswahl nach Dateinamen/Länge, Lautstärkeabgleich per loudnorm. Fehlt eine Datei, greift der alte prozedurale Klang. Weiterhin KEINE Musik.
- Effekte: Texturen (Glow, Funken, Ringe, Flamme) statt Kugeln/Torus: Treffer-Funken mit Blitz, Schockwellenringe, Flammenflächen mit Glut, Strahlen mit Endblitzen. Aussehen nur im Compatibility-Renderer geprüft.

## Änderungen 0.9.6 (neue Helden, Bewegung, Fähigkeiten-Effekte)
- Helden: KayKit Adventurers (CC0) ersetzen das nackte Mannequin: 5 Figuren (Ritter, Barbar, Magier, Waldläuferin, Kapuzenmantel) mit Kleidung, Waffenmodellen in der Hand und echten Animationen (Laufen, Angriffe je Waffentyp, Ausweichen, Zauber, Springen, Blocken, Tod). Im Editor wählt man die "Figur"; Haut-/Haar-/Bart-/Ohren-/Hörner-/Narben-Optionen und die Farbwahl der Figur entfallen (Modell hat feste Farben), Größe/Statur und Akzentfarbe bleiben. Das UAL1/Mannequin-Modell bleibt nur als Rückfall im Projekt.
- Waffen: KayKit-Waffen (Schwert, Axt, Hammer = große Axt, Dolch, Stab, "Bogen" = Armbrust) sitzen am Handknochen wie im Original. Es gibt weder Hammer- noch Bogenmodell im Pack.
- Bewegung: Sprung- und Zauber-Animation hingen nach einem Durchlauf fest (einmalige Clips wurden nicht neu gestartet). Jetzt eigene Luft-Animation (auch beim Fallen) und Zauber-Animation beim Wirken (nur wenn man langsam ist, sonst läuft man weiter).
- Fähigkeiten-Effekte: Geschosse mit Glow-Kern, Lichthof und Partikelschweif; Frost-Nova mit Eissplittern und Nebel; Kettenblitz als zackiger Blitz mit Einschlagfunken; Erdbeben mit Steinsplittern und Staubwolke; Geisterlichter mit Glow und Schweif.
- Leistung: Schatten nur bis 55 m, ferne Bäume/Pflanzen ab 95 m ausgeblendet, im Menü nur noch 2 Spiegel (pausieren bei breiten Seiten). Ob die Ruckler damit weg sind, kann ich ohne deine Hardware nicht messen.
- Ungeprüft: Gegner/Bosse haben weiter die alten Figuren (passen stilistisch nicht zu den neuen Helden). Optik nur im Compatibility-Renderer gesehen.
