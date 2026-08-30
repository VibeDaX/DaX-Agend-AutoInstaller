<div align="center">

# 🤖 DAX Command Center & Control Plane (v6.3)

**Ein hochmodulares, produktionsreifes Orchestrierungs-Framework für autonome KI-Agenten, lokale LLMs und ML-Workflows.**

[![DAX Control Plane CI](https://github.com/VibeDaX/DaX-Agend-AutoInstaller/actions/workflows/ci.yml/badge.svg)](https://github.com/VibeDaX/DaX-Agend-AutoInstaller/actions)
[![Build Status](https://img.shields.io/badge/Test_Suite-100%25_PASSED_--_8_Modules-00FF7F?style=for-the-badge&logo=github-actions&logoColor=white)](https://github.com/VibeDaX/DaX-Agend-AutoInstaller/actions)
[![Version](https://img.shields.io/badge/Version-v6.3_Control_Plane-00D2FF?style=for-the-badge)](https://github.com/VibeDaX/DaX-Agend-AutoInstaller/releases)
[![Platform](https://img.shields.io/badge/Platform-Linux_%7C_WSL2_%7C_Termux-D4AF37?style=for-the-badge&logo=linux&logoColor=white)](#-systemanforderungen)
[![License](https://img.shields.io/badge/License-MIT-brightgreen?style=for-the-badge)](LICENSE)

[Features](#-key-features) • [Architektur](#-system-architektur) • [Schnellstart](#-schnellstart) • [Dashboard](#-web-status-dashboard--api) • [Test Suite](#-automated-test-suite) • [Lizenz](#-lizenz)

</div>

---

## 💡 Über das Projekt

Das **DAX Command Center** ist eine universelle Control Plane zur sicheren Bereitstellung, Konfiguration und Überwachung komplexer KI-Dienste. Es kombiniert Multi-Runtime-Isolierung (Native VENVs, Docker Container, KVM Virtualisierung, Remote SSH) mit dynamischer Hardware-Erkennung, AES-256 Verschlüsselung, 1-Click Backups und automatischer Wiederherstellung (Self-Healing Watchdog).

```
                  ┌─────────────────────────────────────────┐
                  │       DAX Command Center (dax.sh)       │
                  └────────────────────┬────────────────────┘
                                       │
       ┌───────────────────────────────┼───────────────────────────────┐
       ▼                               ▼                               ▼
 ┌──────────────┐                ┌──────────────┐                ┌──────────────┐
 │ Policy Engine│                │Secrets Engine│                │Volume Manager│
 │(.dax/policy) │                │(AES-256 CBC) │                │(.dax/volumes)│
 └──────┬───────┘                └──────┬───────┘                └──────┬───────┘
        │                               │                               │
        └───────────────────────────────┼───────────────────────────────┘
                                        │
       ┌────────────────────────────────┼───────────────────────────────┐
       ▼                                ▼                               ▼
 ┌──────────────┐                ┌──────────────┐                ┌──────────────┐
 │Native VENVs  │                │Docker Engine │                │ KVM / QEMU   │
 │(Hermes/Claw) │                │(Compose V2)  │                │(libvirt/QCOW)│
 └──────────────┘                └──────────────┘                └──────────────┘
```

---

## 🚀 Key Features

* ⚡ **Multi-Runtime Control Plane:** Bereitstellung von KI-Agenten und Services über **Native Python VENVs**, **Docker Container**, **KVM Virtuelle Maschinen** oder **Remote SSH-Hosts**.
* 🧠 **Hardware & Preflight Matrix:** Automatische Erkennung der System-Plattform (Debian/Ubuntu, WSL2, Termux, PRoot) und Beschleuniger-Hardware (**NVIDIA CUDA**, **AMD ROCm**, **Intel Arc XPU**, **Apple Silicon MPS**).
* 🔒 **Policy Engine (`.dax/policy.yaml`):** Granulare Plattform- und Agenten-Restriktionen verhindern inkompatible oder ungesicherte Ausführungen.
* 🔑 **AES-256 Secrets Manager (`.dax/secrets/`):** Verschlüsselung sensibler API-Keys und Passwörter mit OpenSSL (`master.key`) und flüchtiger On-the-Fly-Decryption für Docker & Remote SSH.
* 📦 **Volume Manager (`.dax/volumes.yaml`):** Verwaltet persistente Host-Pfade (`/var/lib/dax/*`) und erzeugt Docker-Bind-Mount-Parameter mit automatischen Berechtigungen.
* 💾 **Encrypted Backup & Restore (`lib/backup.sh`):** 1-Klick Erstellung AES-256 verschlüsselter `.tar.gz.enc` System-Backups und Entschlüsselung.
* 🌐 **Web Status Dashboard & API (Port 9090):** Integrierter HTTP-Server mit visueller HTML-Oberfläche und JSON-API (`/api/status`) für Live-Monitoring.
* 🛡️ **Watchdog Self-Healing:** Kontinuierliches Hintergrund-Monitoring aller Dienste mit automatischem Neustart bei Ausfällen (`attempts >= 3`).
* 🐙 **GitHub Actions CI/CD (`.github/workflows/ci.yml`):** Vollautomatische Ausführung der Testsuite bei jedem Push.
* 🧪 **100% Automated Test Suite (`tests/`):** Test-Engine mit 8 Modulen zur vollständigen Validierung aller Subsysteme.

---

## 🌐 Web Status Dashboard & API (Port 9090)

Das Command Center verfügt über ein eingebettetes Web-Dashboard zur Live-Überwachung aller Komponenten im Browser (`http://localhost:9090`):

* **HTML Interface:** Visuelle Karten für Platform Info, GPU Acceleration, Docker Status und Watchdog Health.
* **JSON API:** RESTful Endpoint unter `/api/status` für externe Monitoring-Systeme oder Skripte.

---

## 🛠️ Schnellstart & Installation

### Option 1: Einzeiler-Schnellstart (Copy & Paste)
```bash
git clone https://github.com/VibeDaX/DaX-Agend-AutoInstaller.git && cd DaX-Agend-AutoInstaller && chmod +x start.sh dax.sh lib/*.sh tests/*.sh && ./start.sh
```

---

### Option 2: Schritt-für-Schritt Installation

1. **Repository klonen:**
   ```bash
   git clone https://github.com/VibeDaX/DaX-Agend-AutoInstaller.git
   cd DaX-Agend-AutoInstaller
   ```

2. **Ausführrechte setzen & starten:**
   ```bash
   chmod +x start.sh dax.sh lib/*.sh tests/*.sh
   ./start.sh
   ```

3. **Automatisierte Testsuite ausführen (100% Validierung):**
   ```bash
   ./tests/run_tests.sh
   ```

---

## 📋 Control-Plane Hauptmenü (Interaktiv)

```text
HOST
  [0]  System / Capability Check (Preflight Matrix)

RUNTIMES
  [1]  Native Runtime / System Dependencies (Python VENVs)
  [2]  Docker Runtime (Container & Compose Management)
  [3]  KVM / VM Runtime (QEMU/libvirt & Snapshots)
  [4]  Remote Runtime (SSH Orchestrierung)

CONTROL-PLANE MODULES
  [5]  Agent Manager / Deployment Wizard
  [6]  Agent Profiles (Manifeste)
  [7]  Policy Manager (.dax/policy.yaml)
  [8]  Volume Manager (.dax/volumes.yaml)
  [9]  Secrets Manager (AES-256)
  [10] Template Manager (Compose, VM, Remote Stacks)
  [11] Encrypted Backup & Restore (.tar.gz.enc)
  [12] Web Status Dashboard & API (Port 9090)

SERVICES
  [13] Ollama konfigurieren & starten
  [14] Ollama Modell laden (RAM-Check Engine)
  [15] ComfyUI installieren/starten (CUDA/ROCm/CPU)
  [16] Open WebUI installieren/starten
  [17] Node-RED + Faster-Whisper Integration

OPERATIONS
  [18] Health / Watchdog Check
  [19] Installation verifizieren
  [20] State / Configuration anzeigen
  [21] Automatisierte Testsuite ausführen (100% Validierung)
  [22] Dienste stoppen
  [23] Logs anzeigen
  [24] Beenden
```

---

## 🧪 Automated Test Suite

Die integrierte Test-Engine garantiert höchste Stabilität und Fehlerfreiheit über 8 eigenständige Testmodule:

```bash
./tests/run_tests.sh
```

```text
══════════════════════════════════════════════════════════════════════
📊 TEST SUITE ZUSAMMENFASSUNG & ERGEBNIS-REPORT
══════════════════════════════════════════════════════════════════════
  ✔ PASS : test_preflight.sh   (Hardware, GPU, OS Detection)
  ✔ PASS : test_policy.sh      (Platform & Agent Restrictions)
  ✔ PASS : test_secrets.sh     (AES-256 Encryption & Scopes)
  ✔ PASS : test_volumes.sh     (Docker Mount & Path Provisioning)
  ✔ PASS : test_templates.sh   (Compose & VM Template Verification)
  ✔ PASS : test_adapters.sh    (Agent Dispatch & Interface Validation)
  ✔ PASS : test_watchdog.sh     (Health Ticks & Auto-Recovery)
  ✔ PASS : test_backup.sh       (AES-256 Backup & Restore Validation)
──────────────────────────────────────────────────────────────────────
Module gesamt: 8 | Bestanden: 8 | Fehlgeschlagen: 0 | Dauer: 3s

🎉 100% FEHLERFREIHEIT ERREICHT! Alle Tests erfolgreich bestanden.
```

---

## 📄 Lizenz

Dieses Projekt ist unter der **MIT-Lizenz** lizenziert — frei verwendbar, anpassbar und erweiterbar. Weitere Details findest du in der Datei [LICENSE](LICENSE).

---

<div align="center">
  <sub>Developed with ❤️ by <b>VibeDaX / War Room Command Network</b></sub>
</div>
