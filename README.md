# FC Teugn Miniticker · Mac-Ausgabe in Vorbereitung

Native AppKit-/WebKit-App, macOS 13+, Universal-Binary für Intel und Apple Silicon.
Noch nicht auf macOS kompiliert oder bedient. Kein fertiger Download freigegeben.

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
und erzeugt die App-ZIP samt SHA-256. Das ist kein visueller Mac-Bedienungstest.

Das Originalwidget wird ausschließlich auf der registrierten Contabo-Demo geladen.
Eine eng begrenzte WebKit-Brücke übernimmt deren vorhandene Anmelde-/Ladestatusmeldungen.
Fremde Frames dürfen keine nativen Befehle auslösen; Uploads, Medienberechtigungen und
fremde Top-Level-Navigation sind gesperrt. HTTPS-Zertifikatsprüfung bleibt aktiv.

## Veröffentlichung

Nach einem erfolgreichen Mac-Build und Funktionstest kann die ZIP als ausdrücklich
gekennzeichnete Testversion auf der geschützten Vereinswebsite angeboten werden.
Eine Ad-hoc-Signatur bestätigt keinen Herausgeber. Für die reguläre Verteilung mit
Developer ID und Apple-Notarisierung wird ein entsprechendes Apple-Entwicklerkonto benötigt.
Das Build-Skript deaktiviert keine macOS-Sicherheitsfunktionen und entfernt keine Quarantäne.

Die App ist an `fc-teugn-demo.75.119.147.66.sslip.io` gebunden. Beim Domainumzug wird
eine neue App-Version benötigt. Angezeigt werden die letzten beim BFV verfügbaren
Tickerdaten, gegebenenfalls eines bereits beendeten Spiels.
