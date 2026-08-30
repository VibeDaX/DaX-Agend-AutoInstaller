# Changelog

Alle relevanten Änderungen an der **DAX Control Plane** werden in dieser Datei dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.0.0/).

---

## [v6.3-control-plane] - 2026-08-30

### Hinzugefügt
- **Control-Plane-Architektur**: Vollständige Modularisierung in Policy Engine, Agent-Adapter-System, Watchdog, Remote Runtime, Secrets Manager, Volume Manager, Template Engine.
- **Konsolidierung des Hauptverzeichnisses**: `dax.sh` als primäres Command-Center mit `start.sh` Entry-Point.
- **Hardware- & Platform-Detection**: Automatische Erkennung von Linux, WSL2, Termux, PRoot und GPU-Beschleunigern (NVIDIA CUDA, AMD ROCm, Intel Arc XPU, Apple Silicon MPS).
- **Vollständige Agent-Adapter**: Native-, Docker-, KVM- und Remote-Adapter für Hermes 2.0 und OpenClaw.
- **Sichere Secrets-Verschlüsselung**: AES-256 Verschlüsselung über Master-Key für globale, Agenten- und Remote-Secrets.
- **Watchdog Auto-Recovery**: Automatischer Neustart fehlerhafter Dienste bei Schwellenwert-Überschreitung.

---

## [v5.2-ultimate] - 2026

### Hinzugefügt
- Self-Healing Engine (`run_with_retry`)
- Node-RED + Faster-Whisper Integration
- RAM-Check Engine für Ollama-Modell-Empfehlung
- ZIP-Backup-Modul
- Live Log-Viewer

---

## [v2.6-logging] - 2026-08-30

### Hinzugefügt
- Integriertes Logging-System mit Zeitstempel und Log-Levels
- VENV-Isolierung für Hermes, OpenClaw und AntiGravity
- Post-Install Automation für Playwright & Headless Chromium
