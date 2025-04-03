# Aufsetzen der Entwicklungsumgebung
1. Git installieren
   - Beim Schritt "Configuring the line ending vonversions" eine der beiden unteren Optionen auswählen (Wenn man sich unsicher ist, dann die Mittlere)  
2. Docker Desktop installieren
    - Default Settings verwenden
3. Reboot
4. WSL Updaten
    - WIN + R -> `cmd` -> `wsl --update`
5. Evtl muss die Virtualisierung im BIOS aktiviert werden. Sollte Docker desswegen meckern, dann den namen des eigenen Mainboards + "virtualisierung aktivieren" googlen und die Schritte befolgen
6. Dieses Repo Klonen
7. Terminal im Ordner öffnen (Unter Windows Shift + Rechtsklick -> "Terminal öffnen")
8. `docker compose up -d` ausführen
9. Die Moodle URL öffnen (localhost:8085) und warten, bis Moodle gestartet ist

## Anleitung zum Hochladen von mbz-Dateien mit Postman
Info: Die ATF (oder auch DSL) Datei befindet sich in der MBZ Datei. Dafür einfach die .mbz mit einem Zip Programm öffnen.

1. **Login durchführen**

    In Postman einen neuen HTTP Request erstellen:
    
    - Methode: `GET`
    - URL: `http://localhost:8086/api/Users/Login?UserName=manager&Password=Manager1234!1234`
    
    `Senden` klicken, um die Anfrage zu starten.

2. **Token speichern**

    Nach erfolgreichem Login erscheint ein Token in der Antwort. Diesen Token für den nächsten Schritt kopieren.

3. **Neuen POST Request erstellen**

    - Methode: `POST`
    - URL: `http://localhost:8086/api/Worlds`

4. **Headers einstellen**

    Den `Headers` Tab auswählen.
    Einen neuen Header hinzufügen:
        - Key: `token`
        - Value: [Hier den im vorherigen Schritt kopierten Token einfügen]

5. **Body Einstellungen vornehmen**

    Zum `Body` Tab wechseln.
    Den `form-data` Modus wählen.
    Zwei neue Schlüssel hinzufügen:
        1. Schlüssel: `backupFile`, Typ: `File`. `Datei auswählen` anklicken und die entsprechende `.mbz` Datei auswählen.
        2. Schlüssel: `atfFile`, Typ: `File`. `Datei auswählen` anklicken und die entsprechende `.dsl` Datei auswählen.

6. **Anfrage senden**

    `Senden` klicken, um die Dateien hochzuladen.

7. **Fertig**
    
        Die Antwort sollte `200 OK` sein. In Moodle sollte nun der neue Kurs erscheinen.
        