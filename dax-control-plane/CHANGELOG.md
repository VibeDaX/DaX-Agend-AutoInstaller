# Changelog

Alle relevanten Änderungen an der **DAX Control Plane** werden hier dokumentiert.

Format: [Keep a Changelog](https://keepachangelog.com/de/1.0.0/)

---

## [v6.3-control-plane] - 2026-08-30

### Hinzugefügt

- **Control-Plane-Architektur**: Modularisierung in Policy Engine, Agent-Adapter-System, Watchdog, Remote Runtime, Secrets Manager, Volume Manager, Template Engine.
- **Policy Engine (v1)**: Plattform-aware Runtime-Freigabe (linux, wsl2, termux, proot) + Agent-spezifische Policy-Abfragen.
- **Agent-Adapter-System (v1)**: Einheitliche `adapter_{install,start,stop,status,logs,health,uninstall}`-Schnittstelle pro Runtime (native, docker, kvm, remote) pro Agent.
- **Watchdog (v1)**: JSON-basiertes Health-State-Tracking mit `watchdog_tick` und optionalem Scheduler-Stub.
- **Remote Runtime (v1)**: `remote_exec host_id cmd` über SSH-Konfiguration aus `.dax/remote_hosts.yaml`.
- **Secrets Manager (v1)**: `secret_set`/`secret_get` mit globalem + agentenspezifischem + remote-Hosts-Secrets-Store.
- **Volume Manager (v1)**: `volume_ensure`/`volume_mount_docker` für Docker-Bind-Mounts aus `.dax/volumes.yaml`.
- **Template Engine (v1)**: `template_apply_vm`, `template_apply_agent_stack`, `template_apply_compose`, `template_apply_remote`.

### Geändert

- **Hauptscript**: `dax.sh` als Control-Plane-Hub mit aufgeräumtem Hauptmenü (Host, Runtimes, Control-Plane Modules, Services, Operations).
- **Agent-Manifeste**: `agents/*/manifest.yaml` mit `supported_runtimes`, `default_runtime`, `volumes`, `security`, `healthcheck`.

### Entfernt

- Keine vorherigen Menüversionen entfernt — Kompatibilität mit v5.2/2.6-Skripten bleibt erhalten.

---

## [v5.2-ultimate] - 2026

### Hinzugefügt

- Self-Healing Engine (`run_with_retry`)
- Node-RED + Faster-Whisper Integration
- RAM-Check Engine für Ollama-Modell-Empfehlung
- ZIP-Backup-Modul
- Live Log-Viewer
- Multi-Agents: Hermes, OpenClaw, AntiGravity
- GUIs: ComfyUI, Open WebUI

---

## [v2.6-logging] - 2026-08-30

### Hinzugefügt

- Integriertes Logging-System
- Zeitstempel & Log-Level
- Konsolen-Output-Spiegelung
- Self-Healing Engine (v1)
- System-Dokumentation

---

## [v2.5.0] - 2026-08-29

### Hinzugefügt

- Self-Healing Engine: Automatische Fehlerdiagnose und Korrekturschleife
- Automatische Reparatur-Logik (Permission denied, Pip-VENV, dpkg/apt)

---

## [v2.0.0] - 2026-08-28

### Hinzugefügt

- Erweiterte Agenten-Unterstützung: OpenClaw, AntiGravity
- Hermes Post-Install Automatisierung
- Erweiterte Backup-Routine
- Cyberpunk UI Theme
