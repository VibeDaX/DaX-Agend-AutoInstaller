# DAX Command Center — Test-Checkliste

> **Legende:** ✅ Getestet & OK | ⚠️ Teilweise / Workaround | ❌ Fehlgeschlagen | ⬜ Noch nicht getestet

---

## [1] HOST (Preflight Matrix & Hardware Check)

| Status | Funktion | Bemerkung |
|--------|----------|-----------|
| ⬜ | [1] System / Caplight Matrix (show_preflight) | |
| ⬜ | [2] Zurück | |

---

## [2] RUNTIMES (Native, Docker, KVM, Remote)

### Native Runtime
| Status | Funktion | Bemerkung |
|--------|----------|-----------|
| ⬜ | [1/1a] System Dependencies installieren (install_system_dependencies) | |
| ⬜ | [1b] System Dependencies deinstallieren (uninstall_system_dependencies) | |

### Docker Runtime
| Status | Funktion | Bemerkung |
|--------|----------|-----------|
| ⬜ | [2/2a] Docker & Compose installieren (runtime_menu) | |
| ⬜ | [2b] Docker deinstallieren (uninstall_docker) | |

### KVM / VM Runtime
| Status | Funktion | Bemerkung |
|--------|----------|-----------|
| ⬜ | [3/3a] KVM & libvirt installieren (vm_menu) | |
| ⬜ | [3b] KVM deinstallieren | |

### Remote Runtime
| Status | Funktion | Bemerkung |
|--------|----------|-----------|
| ⬜ | [4] Remote Runtime (SSH Orchestrierung) | |

---

## [3] CONTROL-PLANE MODULES

### Agent Manager
| Status | Funktion | Bemerkung |
|--------|----------|-----------|
| ⬜ | [1] Agent Deployment Wizard (agent_deployment_wizard) | |
| ⬜ | [1u] Agent deinstallieren (agent_dispatch uninstall) | |

### Agenten — Hermes (Native)
| Status | Funktion | Bemerkung |
|--------|----------|-----------|
| ❌ | Install (adapter_base_install) | **FIX:** get-pip.py Bootstrap + UV_LINK_MODE=copy |
| ⬜ | Start (adapter_base_start) | |
| ⬜ | Stop (adapter_base_stop) | |
| ⬜ | Status (adapter_base_status) | |
| ⬜ | Logs (adapter_base_logs) | |
| ⬜ | Health (adapter_base_health) | |
| ⬜ | Uninstall (adapter_base_uninstall) | |

### Agenten — Hermes (Docker)
| Status | Funktion | Bemerkung |
|--------|----------|-----------|
| ⬜ | Install | |
| ⬜ | Start | |
| ⬜ | Stop | |
| ⬜ | Status | |

### Agenten — Hermes (KVM)
| Status | Funktion | Bemerkung |
|--------|----------|-----------|
| ⬜ | Install | |
| ⬜ | Start | |
| ⬜ | Stop | |
| ⬜ | Status | |

### Agenten — Hermes (Remote)
| Status | Funktion | Bemerkung |
|--------|----------|-----------|
| ⬜ | Install | |
| ⬜ | Start | |
| ⬜ | Stop | |
| ⬜ | Status | |

### Agenten — OpenClaw (Native)
| Status | Funktion | Bemerkung |
|--------|----------|-----------|
| ⬜ | Install | |
| ⬜ | Start | |
| ⬜ | Stop | |
| ⬜ | Status | |
| ⬜ | Logs | |
| ⬜ | Health | |
| ⬜ | Uninstall | |

### Agenten — OpenClaw (Docker)
| Status | Funktion | Bemerkung |
|--------|----------|-----------|
| ⬜ | Install | |
| ⬜ | Start | |
| ⬜ | Stop | |
| ⬜ | Status | |

### Agenten — OpenClaw (KVM)
| Status | Funktion | Bemerkung |
|--------|----------|-----------|
| ⬜ | Install | |
| ⬜ | Start | |
| ⬜ | Stop | |
| ⬜ | Status | |

### Agenten — OpenClaw (Remote)
| Status | Funktion | Bemerkung |
|--------|----------|-----------|
| ⬜ | Install | |
| ⬜ | Start | |
| ⬜ | Stop | |
| ⬜ | Status | |

### Control Plane Module Funktionen
| Status | Funktion | Bemerkung |
|--------|----------|-----------|
| ⬜ | [2] Agent Profiles (agent_profiles) | |
| ⬜ | [3] Policy Manager (policy_manager) | |
| ⬜ | [4] Volume Manager (volume_manager) | |
| ⬜ | [5] Secrets Manager (secrets_manager) | |
| ⬜ | [5d] Secrets löschen | |
| ⬜ | [6] Template Manager (template_manager) | |
| ⬜ | [7] Backup & Restore (backup_manager) | |
| ⬜ | [7d] Backups löschen | |
| ⬜ | [8] Web Dashboard & API (dashboard_manager) | |

---

## [4] SERVICES

### Ollama
| Status | Funktion | Bemerkung |
|--------|----------|-----------|
| ⬜ | [1/1a] Ollama installieren/starten (install_ollama) | |
| ⬜ | [1b] Ollama deinstallieren (uninstall_ollama) | |
| ⬜ | [2] Ollama Modell laden (pull_ollama_model) | |

### ComfyUI
| Status | Funktion | Bemerkung |
|--------|----------|-----------|
| ⬜ | [3/3a] ComfyUI installieren/starten (install_comfyui + start_comfyui) | |
| ⬜ | [3b] ComfyUI deinstallieren (uninstall_comfyui) | |

### Open WebUI
| Status | Funktion | Bemerkung |
|--------|----------|-----------|
| ⬜ | [4/4a] Open WebUI installieren/starten (install_openwebui + start_openwebui) | |
| ⬜ | [4b] Open WebUI deinstallieren (uninstall_openwebui) | |

### Node-RED + Faster-Whisper
| Status | Funktion | Bemerkung |
|--------|----------|-----------|
| ⬜ | [5a] Node-RED installieren/starten (install_nodered + start_nodered) | |
| ⬜ | [5b] Node-RED deinstallieren (uninstall_nodered) | |
| ⬜ | [5c] Faster-Whisper installieren (install_whisper) | |
| ⬜ | [5d] Faster-Whisper deinstallieren (uninstall_whisper) | |

---

## [5] OPERATIONS & MONITORING

| Status | Funktion | Bemerkung |
|--------|----------|-----------|
| ⬜ | [1] Health / Watchdog Check (health_check) | |
| ⬜ | [2] Installation verifizieren (verify_installations) | |
| ⬜ | [3] State / Configuration anzeigen (show_state) | |
| ⬜ | [4] Automatisierte Testsuite (run_tests.sh) | |
| ⬜ | [5] Dienste stoppen (stop_services) | |
| ⬜ | [6] Logs anzeigen (view_logs) | |

---

## [6] HILFE & ANLEITUNG

| Status | Funktion | Bemerkung |
|--------|----------|-----------|
| ⬜ | [1] Hauptmenü erklärt (help_main) | |
| ⬜ | [2] Kategorie [1] Host (help_host) | |
| ⬜ | [3] Kategorie [2] Runtimes (help_runtimes) | |
| ⬜ | [4] Kategorie [3] Control-Plane (help_control_plane) | |
| ⬜ | [5] Kategorie [4] Services (help_services) | |
| ⬜ | [6] Kategorie [5] Operations (help_operations) | |
| ⬜ | [7] Schritt-für-Schritt Workflows (help_workflows) | |

---

## Bekannte Fixes

| Datum | Fix | Status |
|-------|-----|--------|
| 2026-08-30 | pip-Bootstrap via get-pip.py für Termux/PRoot | ✅ Gepusht (06dd2f2) |
| 2026-08-30 | UV_LINK_MODE=copy für PRoot-Hardlink-Fix | ✅ Gepusht (06dd2f2) |
| 2026-08-30 | command_exists pip Check vor System-pip Nutzung | ✅ Gepusht (06dd2f2) |

---

## Offene Probleme

| Problem | Plattform | Status |
|---------|-----------|--------|
| hermes Installation: pip fehlt im VENV | Termux/PRoot | 🔧 Fix gepusht, noch nicht auf Testsystem verifiziert |
| uv Hardlink Fehler (Operation not permitted) | PRoot | 🔧 Fix gepusht (UV_LINK_MODE=copy), noch nicht verifiziert |
| Hermes Installer: "Failed to install requirements from build-system.requires" | PRoot | ⬜ Abhängig von UV_LINK_MODE=copy Fix |
