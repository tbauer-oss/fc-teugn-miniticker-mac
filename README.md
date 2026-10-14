# FC Teugn Miniticker · Mac-Testversion 0.1.0

Native AppKit-/WebKit-App, macOS 13+, Universal-Binary für Intel und Apple Silicon.
Am 14.10.2026 auf einem macOS-Cloudrechner für beide Architekturen kompiliert.
Die fertige ZIP wird als Testversion auf der geschützten Vereins-Demoseite angeboten.

Implementiert: Ergebnis/Wappen oder vollständiger originaler BFV-Ticker, verschiebbares
Fenster, optional im Vordergrund, Weiterlaufen über ein Symbol in der Mac-Menüleiste,
geschützte Demo-Anmeldung, Wiederverbindung und erneutes Laden alle fünf Minuten.
Kein Autostart, keine Passwörter im Paket, keine automatischen Torbenachrichtigungen.
Mac und App müssen laufen. Eine schlafende oder ausgeschaltete Maschine aktualisiert nicht.

## Cloud-Build

Dieses Verzeichnis ist bewusst ein eigenständiges Build-Paket. Nur diese Dateien
gehören in ein separates öffentliches Miniticker-Repository; keine Vereinsdaten, CMS-Inhalte,
Zugangscodes, Serverzugänge oder das übrige FC-Teugn-Projekt werden übertragen.

`.github/workflows/mac-test.yml` läuft ausschließlich nach manuellem Start, auf einem
normalen GitHub-Mac-Runner, maximal 10 Minuten. Aufbewahrung der kleinen App-ZIP: ein Tag.
Der Standard-Mac-Runner ist für öffentliche Repositories kostenlos. Dieser Build
verwendet keine kostenpflichtigen größeren Runner und keinen eigenen Mac.

`bash build.sh` kompiliert beide Prozessorvarianten, führt URL-/Bridge-Regeltests auf
der Runner-Architektur aus, prüft das Universal-Binary und die lokale Ad-hoc-Signatur
und erzeugt die App-ZIP samt SHA-256. Ein separater Testprozess startet das native
Fenster, prüft Menü, Vordergrund-Option, Ansichtsauswahl und WebKit. Zusätzlich wird
die echte geschützte Demo-Anmeldung einschließlich der begrenzten Nachrichtenbrücke
ohne Eingabe von Zugangsdaten geprüft. Diese Prüfungen bestanden auf dem Intel-Runner.
Die Apple-Silicon-Ausgabe wurde kompiliert, aber nicht auf Apple Silicon ausgeführt.
Ein visueller Mac-Bedienungstest und die angemeldete BFV-Anzeige am Mac stehen noch aus.

Das Originalwidget wird ausschließlich auf der registrierten Contabo-Demo geladen.
Eine eng begrenzte WebKit-Brücke übernimmt deren vorhandene Anmelde-/Ladestatusmeldungen.
Fremde Frames dürfen keine nativen Befehle auslösen; Uploads, Medienberechtigungen und
fremde Top-Level-Navigation sind gesperrt. HTTPS-Zertifikatsprüfung bleibt aktiv.

## Veröffentlichung

Erfolgreicher Build: https://github.com/tbauer-oss/fc-teugn-miniticker-mac/actions/runs/38532193147

Download: https://fc-teugn-demo.75.119.147.66.sslip.io/#/ticker-pc

Eine Ad-hoc-Signatur bestätigt keinen Herausgeber. Für die reguläre Verteilung mit
Developer ID und Apple-Notarisierung wird ein entsprechendes Apple-Entwicklerkonto benötigt.
Das Build-Skript deaktiviert keine macOS-Sicherheitsfunktionen und entfernt keine Quarantäne.

Die App ist an `fc-teugn-demo.75.119.147.66.sslip.io` gebunden. Beim Domainumzug wird
eine neue App-Version benötigt. Angezeigt werden die letzten beim BFV verfügbaren
Tickerdaten, gegebenenfalls eines bereits beendeten Spiels.
