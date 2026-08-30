# 📋 DAX Control Plane (v6.3) — TODO & Umsetzungs-Tracker

Dieses Dokument erfasst den aktuellen Fortschritt aller Arbeitsschritte und wird nach jedem erledigten Schritt aktualisiert.

---

## 🎯 Phase 1: Projektstruktur, Konsolidierung auf v6.3 & Git
- [x] **1.1** Ordnerinhalte von `dax-control-plane/` (`agents/`, `templates/`, `.dax/`) vollständig ins Root-Verzeichnis synchronisieren
- [x] **1.2** `dax.sh` als Hauptausführungsdatei im Root bereitstellen und `start.sh` als Einstiegspunkt konfigurieren
- [x] **1.3** Dokumentationsdateien (`README.md`, `DOKUMENTATION.md`, `CHANGELOG.md`) im Root auf v6.3 aktualisieren
- [x] **1.4** `.gitignore` anlegen (Ausschluss von VENVs, temporären Logs, PIDs, temporären Env-Dateien)
- [x] **1.5** Initiales Git-Repository aufsetzen (`git init` & Initial Commit)

---

## ⚙️ Phase 2: Agent-Adapter ausprogrammieren (Native & KVM)
- [x] **2.1** `agents/hermes/adapters/native.sh` implementieren (VENV-Setup, Hermes-Start, PID-Tracking, Logs, Health-Check)
- [x] **2.2** `agents/openclaw/adapters/native.sh` implementieren (VENV-Setup, Start/Stop-Routinen, Status, Health-Check)
- [x] **2.3** `agents/hermes/adapters/kvm.sh` & `agents/openclaw/adapters/kvm.sh` an die virsh/KVM-Infrastruktur anbinden

---

## 🔐 Phase 3: AES-256 Secrets-Verschlüsselung
- [x] **3.1** Verschlüsselungs-/Entschlüsselungsfunktionen mit OpenSSL (`master.key`) in `dax.sh` integrieren
- [x] **3.2** `secret_set` so anpassen, dass Secrets verschlüsselt gespeichert werden
- [x] **3.3** `secret_get` und `secret_get_envfile` so erweitern, dass sie Werte im Speicher sicher entschlüsseln

---

## 🛡️ Phase 4: Watchdog Auto-Restart & Health Engine
- [x] **4.1** Watchdog-Fehlerbehandlungslogik in `dax.sh` erweitern (automatische Wiederherstellungsaktionen bei ≥3 Fehlversuchen)
- [x] **4.2** Logging aller Watchdog- und Recovery-Ereignisse in `logs/watchdog.log` absichern

---

## 🧪 Phase 5: Gesamttests & Verifikation
- [x] **5.1** Bash-Syntaxprüfung aller Skripte durchführen (`bash -n`)
- [x] **5.2** Secrets-Verschlüsselung und -Entschlüsselung testen
- [x] **5.3** Agent-Adapter Dispatch & Healthchecks testen
- [x] **5.4** Walkthrough-Dokumentation erstellen und Abschlussbericht vorlegen
