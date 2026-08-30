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

---

## 🔬 Phase 6: Automated Test Suite (100% Usecase-Abdeckung)
- [x] **6.1** Gemeinsame Test-Bibliothek & Assertion-Engine (`tests/test_helper.sh`)
- [x] **6.2** Modul-Test: Preflight & Capability Detection (`tests/test_preflight.sh`)
- [x] **6.3** Modul-Test: Policy Engine (`tests/test_policy.sh`)
- [x] **6.4** Modul-Test: Secrets Manager & AES-256 (`tests/test_secrets.sh`)
- [x] **6.5** Modul-Test: Volume Manager (`tests/test_volumes.sh`)
- [x] **6.6** Modul-Test: Template Engine (`tests/test_templates.sh`)
- [x] **6.7** Modul-Test: Agent Adapter & Dispatch (`tests/test_adapters.sh`)
- [x] **6.8** Modul-Test: Watchdog & Recovery (`tests/test_watchdog.sh`)
- [x] **6.9** Master Test Runner (`tests/run_tests.sh`) mit 100% Reporting und Menü-Integration

---

## ⚡ Phase 7: Code Quality & Performance Refactoring
- [x] **7.1** `lib/core.sh`: Logging, Preflight, Hardware-Caching & RAM-Engine auslagern
- [x] **7.2** `lib/policy.sh`: Policy Engine auslagern
- [x] **7.3** `lib/secrets.sh`: Secrets Engine & Trap Cleanup (`EXIT INT TERM`) auslagern
- [x] **7.4** `lib/volumes.sh`: Volume Manager auslagern
- [x] **7.5** `lib/templates.sh`: Template Engine auslagern
- [x] **7.6** `lib/watchdog.sh`: Watchdog & Health Engine auslagern
- [x] **7.7** `lib/adapters.sh`: Agent Dispatch System auslagern
- [x] **7.8** `dax.sh` auf schlankes Hauptskript umstellen & Menü-Optimierung
- [x] **7.9** 100% Testsuite-Validierung (`./tests/run_tests.sh`)
- [x] **7.10** Dokumentation aktualisieren & Git Commit + Push

---

## 🚀 Phase 8: Next-Gen Expansion & Automation
- [x] **8.1** GitHub Actions CI/CD Pipeline (`.github/workflows/ci.yml`) einrichten
- [x] **8.2** Encrypted Backup & Restore Modul (`lib/backup.sh`) implementieren
- [x] **8.3** Remote SSH Agent Deployment (`agents/*/adapters/remote.sh`) vervollständigen
- [x] **8.4** Web Status Dashboard & API (`lib/dashboard.sh`) auf Port 9090 einbauen
- [x] **8.5** Testsuite erweitern (`tests/test_backup.sh`) & 100% Validierung ausführen
- [x] **8.6** Dokumentation aktualisieren & Git Commit + Push zu GitHub

---

## 🎯 Phase 9: Code Review Refactoring — P0 (Security High-Impact)
> Ziel: Kritische Sicherheits- und Stabilitätsprobleme beheben vor weiteren Änderungen.

- [ ] **9.1** `lib/secrets.sh`: Unsicheren Fallback-Key bei fehlendem OpenSSL entfernen
  - **Akzeptanzkriterium:** `ensure_master_key` gibt bei fehlendem `openssl` Fehler zurück statt vorhersagbaren Fallback-Key zu nutzen; alternativ Key aus `/dev/urandom` lesen.
- [ ] **9.2** `agents/*/adapters/native.sh`: Command Injection durch unquotierte Variablen beheben
  - **Akzeptanzkriterium:** Alle `nohup $exec_bin` Aufrufe verwenden `nohup "$exec_bin"`; Leerzeichen in Pfaden brechen nicht mehr die Ausführung.
- [ ] **9.3** `agents/*/adapters/remote.sh`: SSH-Hardening (StrictHostKeyChecking)
  - **Akzeptanzkriterium:** Remote-Adapter nutzt `-o UserKnownHostsFile=/dev/null` oder verlangt expliziten Fingerprint-Check statt stillschweigend `accept-new`.
- [ ] **9.4** `lib/secrets.sh`: Predictable Tempfiles durch `mktemp` ersetzen
  - **Akzeptanzkriterium:** `/tmp/dax-secrets-*.env` wird durch `mktemp` generiert; Dateiname ist nicht vorhersagbar.
- [ ] **9.5** Regressionstest nach P0-Änderungen
  - **Akzeptanzkriterium:** `./tests/run_tests.sh` läuft weiterhin 100% grün (8/8 Module).

---

## 🔧 Phase 10: Code Review Refactoring — P1 (Qualität & CI)
> Ziel: Duplikation eliminieren und CI-Qualität verbessern.

- [ ] **10.1** Adapter-Duplikation eliminieren (Base-Adapter einführen)
  - **Akzeptanzkriterium:** Gemeinsame Logik aus `agents/hermes/adapters/native.sh` und `agents/openclaw/adapters/native.sh` in `lib/adapter_base.sh` ausgelagert; agentenspezifische Unterschiede nur noch in `manifest.yaml` oder Mini-Wrappern.
- [ ] **10.2** ShellCheck in CI integrieren
  - **Akzeptanzkriterium:** `.github/workflows/ci.yml` enthält einen `shellcheck -x` Job für alle `*.sh` Dateien (außer `dax-control-plane/`); Build schlägt bei ShellCheck-Fehlern fehl.
- [ ] **10.3** Tests an P0/P1-Änderungen anpassen
  - **Akzeptanzkriterium:** `tests/test_secrets.sh` prüft Fehlerverhalten bei fehlendem OpenSSL; `tests/test_adapters.sh` validiert quoted command execution.
- [ ] **10.4** Git Commit + Push nach abgeschlossener P1-Phase
  - **Akzeptanzkriterium:** Phase 10 ist vollständig committet und gepusht; Working tree ist clean.

---

## ⚡ Phase 11: Code Review Refactoring — P2 (Performance & Robustness)
> Ziel: Python-Overhead reduzieren und Wartezeiten optimieren.

- [ ] **11.1** `python3 -c` Inline-Skripte durch Helper-Modul ersetzen
  - **Akzeptanzkriterium:** Neue Datei `lib/state_helper.py` mit Funktionen für JSON-Read/Write; alle Inline-`python3 -c` Aufrufe nutzen dieses Modul; `import state_helper` ist zentral.
- [ ] **11.2** `sleep 1` nach Prozess-Start durch Port-Polling ersetzen
  - **Akzeptanzkriterium:** Funktion `wait_for_port <port> <timeout>` ersetzt feste `sleep 1` in Adaptern und Services; Tests sind nicht langsamer geworden.
- [ ] **11.3** Performance-Regressionstest
  - **Akzeptanzkriterium:** `./tests/run_tests.sh` läuft in < 15s (aktuell ~9s); keine neuen Timeouts in Tests.
- [ ] **11.4** Git Commit + Push nach abgeschlossener P2-Phase
  - **Akzeptanzkriterium:** Phase 11 ist vollständig committet und gepusht; Working tree ist clean.

---

## 🏗️ Phase 12: Code Review Refactoring — P3 (Architektur)
> Ziel: Modularisierung von `dax.sh` für bessere Wartbarkeit.

- [ ] **12.1** Service-Installer aus `dax.sh` in `lib/services.sh` auslagern
  - **Akzeptanzkriterium:** Funktionen `install_system_dependencies`, `install_ollama`, `pull_ollama_model`, `install_comfyui`, `start_comfyui`, `install_openwebui`, `start_openwebui`, `install_nodered`, `install_whisper`, `start_nodered`, `install_docker`, `docker_context_init` sind in `lib/services.sh`; `dax.sh` enthält nur noch Menü-Dispatcher.
- [ ] **12.2** Menü-Logik aus `dax.sh` in `lib/menus.sh` auslagern
  - **Akzeptanzkriterium:** Alle `menu_*` Funktionen sind in `lib/menus.sh`; `dax.sh` enthält nur noch `main_menu` als Entrypoint.
- [ ] **12.3** Finaler Integrationstest & Dokumentation
  - **Akzeptanzkriterium:** `./tests/run_tests.sh` läuft 100% grün; README/DOKUMENTATION verweisen auf neue Dateistruktur; Hilfe-Menü ([6]) ist aktuell.
- [ ] **12.4** Git Commit + Push nach abgeschlossener P3-Phase
  - **Akzeptanzkriterium:** Phase 12 ist vollständig committet und gepusht; Working tree ist clean.
