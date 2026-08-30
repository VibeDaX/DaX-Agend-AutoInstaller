<div align="center">

# 🤖 DAX Command Center & Control Plane (v6.3)

**Ein hochmodulares, produktionsreifes Orchestrierungs-Framework für autonome KI-Agenten, lokale LLMs und ML-Workflows.**

[![Build Status](https://img.shields.io/badge/Test_Suite-100%25_PASSED-00FF7F?style=for-the-badge&logo=github-actions&logoColor=white)](https://github.com/VibeDaX/DaX-Agend-AutoInstaller/actions)
[![Version](https://img.shields.io/badge/Version-v6.3_Control_Plane-00D2FF?style=for-the-badge)](https://github.com/VibeDaX/DaX-Agend-AutoInstaller/releases)
[![Platform](https://img.shields.io/badge/Platform-Linux_%7C_WSL2_%7C_Termux-D4AF37?style=for-the-badge&logo=linux&logoColor=white)](#-systemanforderungen)
[![License](https://img.shields.io/badge/License-MIT-brightgreen?style=for-the-badge)](LICENSE)

[Features](#-key-features) • [Architektur](#-system-architektur) • [Schnellstart](#-schnellstart) • [Agenten](#-unterstützte-agenten) • [Test Suite](#-automated-test-suite) • [Lizenz](#-lizenz)

</div>

---

## 💡 Über das Projekt

Das **DAX Command Center** ist eine universelle Control Plane zur sicheren Bereitstellung, Konfiguration und Überwachung komplexer KI-Dienste. Es kombiniert Multi-Runtime-Isolierung (Native VENVs, Docker Container, KVM Virtualisierung, Remote SSH) mit dynamischer Hardware-Erkennung, AES-256 Verschlüsselung und automatischer Wiederherstellung (Self-Healing Watchdog).

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
* 🛡️ **Watchdog Self-Healing:** Kontinuierliches Hintergrund-Monitoring aller Dienste mit automatischem Neustart bei Ausfällen (`attempts >= 3`) und Protokollierung in `logs/watchdog.log`.
* 🧪 **100% Automated Test Suite (`tests/`):** Integrierte Test-Engine zur vollständigen Validierung aller 7 System-Module vor dem Produktiveinsatz.

---

## 🤖 Unterstützte Agenten & Services

| Komponente | Typ | Runtimes | Beschreibung |
| :--- | :--- | :--- | :--- |
| **Hermes 2.0 Agent** | AI Agent | `Native` `Docker` `KVM` `Remote` | Autonomer Agent für Browser- & System-Automatisierung. |
| **OpenClaw Agent** | AI Agent | `Native` `Docker` `KVM` `Remote` | Leichtgewichtiger Agent für Shell- & Task-Execution. |
| **AntiGravity** | AI Agent | `Native` `Docker` | Multi-Agent Orchestrator & CLI Interface. |
| **Ollama** | Local LLM | `Native` `Docker` `Remote` | Inferenz-Engine für Llama 3, Mistral, Qwen u.v.m. |
| **ComfyUI** | Image GUI | `Native` `Docker` | Node-basierte GUI für Stable Diffusion & FLUX. |
| **Open WebUI** | Chat Interface | `Native` `Docker` | Feature-reiches ChatGPT-ähnliches Frontend. |
| **Node-RED & Whisper** | Automation/STT | `Native` `Docker` | Workflow-Engine mit Faster-Whisper Sprach-Erkennung. |

---

## 🛠️ Schnellstart

### 1. Repository klonen & Ausführrechte setzen
```bash
git clone https://github.com/VibeDaX/DaX-Agend-AutoInstaller.git
cd DaX-Agend-AutoInstaller
chmod +x start.sh dax.sh tests/*.sh
```

### 2. Command Center starten
```bash
./start.sh
# oder direkt:
./dax.sh
```

### 3. Automatisierte Testsuite ausführen (100% Validierung)
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
  [9]  Secrets Manager (AES-256 GCM/CBC)
  [10] Template Manager (Compose, VM, Remote Stacks)

SERVICES
  [11] Ollama konfigurieren & starten
  [12] Ollama Modell laden (RAM-Check Engine)
  [13] ComfyUI installieren/starten (CUDA/ROCm/CPU)
  [14] Open WebUI installieren/starten
  [15] Node-RED + Faster-Whisper Integration

OPERATIONS
  [16] Health / Watchdog Check
  [17] Installation verifizieren
  [18] State / Configuration anzeigen
  [19] Automatisierte Testsuite ausführen (100% Validierung)
  [20] Dienste stoppen
  [21] Logs anzeigen
  [22] Beenden
```

---

## 🧪 Automated Test Suite

Die integrierte Test-Engine garantiert höchste Stabilität und Fehlerfreiheit über 7 eigenständige Testmodule:

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
──────────────────────────────────────────────────────────────────────
Module gesamt: 7 | Bestanden: 7 | Fehlgeschlagen: 0 | Dauer: 4s

🎉 100% FEHLERFREIHEIT ERREICHT! Alle Tests erfolgreich bestanden.
```

---

## 📄 Lizenz

Dieses Projekt ist unter der **MIT-Lizenz** lizenziert — frei verwendbar, anpassbar und erweiterbar. Weitere Details findest du in der Datei [LICENSE](LICENSE).

---

<div align="center">
  <sub>Developed with ❤️ by <b>VibeDaX / War Room Command Network</b></sub>
</div>
