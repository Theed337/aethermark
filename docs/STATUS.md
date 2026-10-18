# Ehrlicher Statusbericht (Stand dieser Version 0.9.9)

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

## Änderungen 0.9.7 (Feedback-Runde 4)
- Menü-Figur dreht sich nicht mehr von selbst (nur noch per Maus ziehen).
- Talentbaum neu angeordnet: 11 Zweige gleichmäßig im Kreis, kurze Verbindungen, Synergie-Knoten zwischen Nachbarzweigen, Zweigname am Zweigende.
- Charaktereditor: Auswahl „Geschlecht". Weiblich = Kopf der Waldläuferin (einzige weibliche KayKit-Figur) – ehrlich: nur ein weiblicher Kopf/Frisur, kein eigener weiblicher Körper.
- Ausrüstung ändert das Aussehen: Kopf-, Brust-, Beinteil, Schild und Waffe wechseln das Modell (Teile verschiedener KayKit-Figuren werden auf dasselbe Skelett gesetzt). Aktualisiert sich sofort im Inventar-Vorschaubild und im Spiel. Welches Aussehen ein Teil bekommt, hängt von seiner ID ab (Zufall, aber stabil) – keine Rüstungsstufen-Logik.
- Fadenkreuz im Spiel (nur bei erfasster Maus).
- Koop: Beim Erscheinen der Fähigkeiten-Auswahl pausiert die Welt 4 s (Gegner/Geschosse stehen), damit alle reagieren können.
- Balance: Monster in der Gruppe deutlich schwächer skaliert (LP +30 % statt +55 % je Mitspieler, Schaden +4 % statt +10 %, kleinere Spawn-Obergrenze, Boss-LP +50 %), weniger Beute (Elite 30 %, normale Gegner 1,2 %, Truhen seltener 2. Gegenstand), Fähigkeiten-Stufen brauchen ~40 % mehr EP, Talentpunkte pro Run ca. halbiert (Charakterstufe 170·Stufe EP).
- Launcher/Update: lädt version.json aus dem Repo-Ordner dist/ (raw.githubusercontent.com/…/main/dist), unterstützt mehrteilige Downloads (GitHub-Dateilimit 100 MB).
- Nicht verifiziert: Mehrspieler-Fähigkeiten – im Code keine Ursache gefunden (siehe unten), reale Netzwerk-/GPU-Tests stehen aus.

## Änderungen 0.9.8 (Feedback-Runde 5)
- **Wiederbeleben** ging bei menschlichen Spielern nie: Das Halten der Interaktionstaste wurde nur für Bots erfasst (Host und Clients). Behoben.
- **„Schwer" nach dem Sterben freigeschaltet**: Der Run zählte als Sieg, sobald der Boss fiel – auch wenn man selbst tot/kampfunfähig war. Jetzt zählt der Sieg nur für Spieler, die am Ende kampffähig sind.
- **Rückkehr nach dem Endboss**: Nach dem Sieg bleiben 25 s zum Einsammeln der Beute (Hinweis mit Countdown, Enter beendet sofort im Solo-Spiel); Gegner spawnen nicht mehr nach.
- **Lautstärke** wird auch im Pausemenü gespeichert (vorher nur in den Einstellungen).
- **Minimap**: größer, undurchsichtiger Hintergrund, größerer Sichtbereich (55 m).
- **Startfähigkeiten je Waffe** (eine aktive + eine passive Stufe 1): Schwert Kettenblitz+Blutdurst, Axt Frostnova+Weite Hiebe, Hammer Erdbeben+Eiserner Wille, Dolch Geisterlichter+Kritmeisterschaft, Bogen Feuerball+Schnelligkeit, Stab Feuerball+Arkanfokus.
- **Gegner pro Gebiet**: Smaragdwald = Schleim-/Pflanzenwesen; Ruinen, Aschelande, Frostklippen, Schattenwald, Himmelsfestung = animierte Skelette (KayKit Skeletons, CC0) mit je anderer Mischung, Waffen und Farbe/Leuchten. Neue Formen für Kriecher (Spinne), Wächterschütze (Steinwächter), Teiler (Gallert), Kultist. Ehrlich: Es sind nur 4 Skelett-Modelle, Unterschiede kommen aus Tönung/Waffen/Mischung; Sprengwesen und Schützen im Wald sind weiter einfache Primitiv-Figuren.
- **Talentbaum**: 6 Hauptpfade (Klassen: Nahkampf, Schnelle Waffen, Fernkampf, Elementar, Dunkel, Beschwörung) mit langen Wegen; 5 Nebenpfade (Verteidigung, Heilung, Fallen, Beweglichkeit, Ressourcen) zweigen von einem Hauptpfad ab; Synergie-Knoten verbinden Haupt- und Nebenpfade. Die Boni selbst sind unverändert, nur Aufbau/Voraussetzungen.
- **Inventar neu**: Charakteransicht mit Plätzen (Kopf/Brust/Hände/Beine/Füße links, Amulett/Ringe/Artefakt/Zweitwaffe rechts, Waffe unten), Gegenstände per Drag & Drop anlegen/ablegen, Doppelklick, Vergleichswerte. Tabs „Händler" und „Sammlung & Kosmetik" im selben Fenster.
- **Gold & Händler**: Gold gibt es für Runs und Verkäufe (Standard-Startgold 60). Verkaufen per Button, Ziehen auf den Händler oder „alle gewöhnlichen verkaufen". Der Händler bietet 8 Gegenstände, die sich alle 20 Minuten (Echtzeit, auch wenn das Spiel zu war) erneuern; gekaufte Ware ist nicht handelbar.
- **Handel**: Angebotsfläche und Inventar als Kachelraster mit Drag & Drop, Angebot des Partners als Kacheln + volle Werte. Ehrlich: Eine konkrete Fehlerursache im Handel habe ich nicht gefunden (Ablauf und Tests sind grün); die Oberfläche wurde neu aufgebaut. Echter Online-Handel ist ungetestet.


## Änderungen 0.9.9 (Feedback-Runde 6)
- Monster: 51 neue Monster-/Boss-Modelle (Quaternius, CC0) statt Primitiv-Figuren; Hüpf-/Schwebe-/Angriffsanimation per Code (die Modelle haben keine Skelettanimationen).
- Hauptmenü: neue Szene (Ruinenlager im Abendlicht mit Fackeln), Held bleibt; Multiplayer-Menü jetzt mittig.
- Arenen: jedes der 6 Gebiete hat eigene Kulisse (Wald-Bogen/Pilzringe, versunkene Tempel mit Wasser, Lavarisse/Obsidian, Eiskristalle/Schnee, Friedhöfe/Spiegelsplitter, Festung mit Inseln im Wolkenmeer).
- Talentpunkte gibt es nur noch durch Level-Ups im Hauptmenü (60 Stufen, wachsende XP-Kurve, max. 60 Punkte); alte Spielstände werden begrenzt (Migration).
- Neue Fähigkeiten (31 statt 18): Klingensturm, Giftwolke, Eislanze, Donnerschlag, Meteorregen, Leere-Singularität, Heilige Nova; Passive Schwung, Dornen, Überladung, Seelenernte, Berserker, Arkanschild; Evolutionen Sturmfront und Giftbrand. Neue Effekte (Lichtsäulen, Bodenrisse, Brandflecken).
- Balancing: Gegner werden mit der Laufzeit stärker (+4,5 % Leben, +2,5 % Schaden pro Minute), Gift als eigener Schadensüberzeit.
- Tests: 65 000+ Prüfungen bestanden; neuer Fähigkeiten-Test wirft alle aktiven Fähigkeiten ohne Fehler.
## Ehrlich: nicht verifiziert (0.9.9)
- Aussehen/Performance auf echter Grafikkarte (hier nur Software-Renderer), Balance der neuen Fähigkeiten und der Zeitkurve (kein Mensch hat gespielt), Netzwerk-Sync der neuen Effekte nur per Netztest, Launcher-Download von echtem GitHub.
