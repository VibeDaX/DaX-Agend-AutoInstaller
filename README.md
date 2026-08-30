# 🤖 DAX Command Center & Control Plane (v6.3)

Ein hochmodulares, produktionsreifes **Management- und Orchestrierungs-Framework** für autonome KI-Agenten (**Hermes 2.0**, **OpenClaw**, **AntiGravity**), lokale LLMs (**Ollama**), Bild- & Workflow-GUIs (**ComfyUI**, **Open WebUI**) und Automationsdienste (**Node-RED**, **Faster-Whisper**).

---

## 🚀 Key Features

* **Multi-Runtime Control Plane:** Nahtlose Bereitstellung über **Native (Python VENVs)**, **Docker (isolierte, gehärtete Container)**, **KVM/QEMU (virtuelle Maschinen)** und **Remote Hosts (SSH-Orchestrierung)**.
* **Hardware & Preflight Matrix:** Automatische Erkennung der Plattform (Debian/Ubuntu, WSL2, Termux, PRoot) und Beschleuniger-Hardware (NVIDIA CUDA, AMD ROCm, Intel Arc XPU, Apple Silicon MPS).
* **Policy Engine (`.dax/policy.yaml`):** Plattform- und agentenbasierte Sicherheitsrichtlinien verhindern inkompatible oder ungesicherte Runtime-Starts.
* **Sichere Secrets-Verwaltung (`.dax/secrets/`):** Scoped Secrets (global, agentenspezifisch, remote) mit AES-256 Verschlüsselung über Master-Key.
* **Volume Manager (`.dax/volumes.yaml`):** Verwaltet persistente Speicherpfade und Docker-Bind-Mounts mit Berechtigungsverwaltung.
* **Watchdog & Self-Healing:** Überwacht laufende Dienste kontinuierlich, führt Health-Checks durch und triggert automatische Wiederherstellungsmaßnahmen bei Ausfällen.
* **Template Engine (`templates/`):** Vordefinierte Stacks für Docker Compose, KVM-VMs und Remote-Setups.

---

## 📊 Systemanforderungen

| Komponente | Mindestanforderung | Empfohlen |
| :--- | :--- | :--- |
| **Betriebssystem** | Linux (Debian/Ubuntu), WSL2 oder PRoot | Ubuntu 22.04 / 24.04 LTS nativ |
| **Arbeitsspeicher** | Min. 4 GB RAM | 16 GB+ RAM (für lokale LLMs & ComfyUI) |
| **GPU-Beschleunigung** | Optional (CPU Safe Mode vorhanden) | NVIDIA GPU (CUDA) oder AMD (ROCm) |
| **Virtualisierung** | Optional | KVM / `/dev/kvm` für VM-Isolierung |
| **Docker** | Optional | Docker Engine + Docker Compose V2 |

---

## 🛠️ Schnellstart

1. Ausführrechte setzen:
   ```bash
   chmod +x start.sh dax.sh
   ```

2. Command Center starten:
   ```bash
   ./start.sh
   # oder direkt:
   ./dax.sh
   ```

---

## 📋 Modul-Übersicht (Hauptmenü)

```text
HOST
  [0] System / Capability Check (Preflight Matrix)

RUNTIMES
  [1] Native Runtime / System Dependencies
  [2] Docker Runtime (Container & Compose Management)
  [3] KVM / VM Runtime (QEMU/libvirt & Snapshots)
  [4] Remote Runtime (SSH Orchestrierung)

CONTROL-PLANE MODULES
  [5] Agent Manager / Deployment Wizard
  [6] Agent Profiles (Manifeste)
  [7] Policy Manager
  [8] Volume Manager
  [9] Secrets Manager
  [10] Template Manager

SERVICES
  [11] Ollama konfigurieren & starten
  [12] Ollama Modell laden (intelligenter RAM-Check)
  [13] ComfyUI installieren/starten
  [14] Open WebUI installieren/starten
  [15] Node-RED + Faster-Whisper

OPERATIONS
  [16] Health / Watchdog Check
  [17] Installation verifizieren
  [18] State / Configuration anzeigen
  [19] Dienste stoppen
  [20] Logs anzeigen
  [21] Beenden
```

---

## 🔍 Diagnose & Logs

Alle Vorgänge werden detailliert protokolliert:
* **Installations- & Runtime-Log:** `./logs/installation.log`
* **Watchdog- & Health-Log:** `./logs/watchdog.log`

Live-Protokoll ansehen:
```bash
tail -f logs/installation.log
```

---

## 🛡️ Lizenz & Entwickler

* **Developer:** DAX / War Room Command Network
* **Version:** v6.3 Control-Plane Edition
