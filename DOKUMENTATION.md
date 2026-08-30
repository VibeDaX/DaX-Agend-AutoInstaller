## 📖 DAX Control Plane Dokumentation & Betriebs-Handbuch

**Version:** v6.3 Control-Plane Edition  
**Architektur:** Modular Bash / Shell Orchestration & Multi-Runtime Control Plane  

---

### 1. Architektur & Kern-Module

Das DAX Command Center steuert autonome KI-Agenten und ML-Dienste über eine Schichten-Architektur:

```
                  ┌─────────────────────────────────┐
                  │    DAX Command Center (dax.sh)  │
                  └────────────────┬────────────────┘
                                   │
      ┌────────────────────────────┼────────────────────────────┐
      ▼                            ▼                            ▼
┌──────────────┐             ┌──────────────┐             ┌──────────────┐
│ Policy Engine│             │Secrets Engine│             │Volume Manager│
│(.dax/policy) │             │(.dax/secrets)│             │(.dax/volumes)│
└──────┬───────┘             └──────┬───────┘             └──────┬───────┘
       │                            │                            │
       └────────────────────────────┼────────────────────────────┘
                                   │
      ┌────────────────────────────┼────────────────────────────┐
      ▼                            ▼                            ▼
┌──────────────┐             ┌──────────────┐             ┌──────────────┐
│Native Runtime│             │Docker Runtime│             │ KVM/QEMU VM  │
│(Python VENVs)│             │(Containers)  │             │(libvirt/QCOW)│
└──────────────┘             └──────────────┘             └──────────────┘
```

#### 1.1 Policy Engine (`.dax/policy.yaml`)
Verhindert unautorisierte oder für die Plattform ungeeignete Ausführungen:
* Plattform-Beschränkungen (z. B. kein KVM auf WSL2, kein Docker auf Termux/PRoot).
* Agenten-Beschränkungen (z. B. welche Runtimes für Hermes oder OpenClaw freigegeben sind).

#### 1.2 Secrets Manager (`.dax/secrets/`)
Verwaltet sensible Daten mit Scopes (`global`, `agent`, `remote`). Die Daten werden über OpenSSL mit dem Master-Key (`master.key`) verschlüsselt und zur Laufzeit entschlüsselt.

#### 1.3 Volume Manager (`.dax/volumes.yaml`)
Definiert persistente Host-Pfade (`/var/lib/dax/*`) und erzeugt Docker-Bind-Mount-Parameter (`-v <host>:<container>:rw`) mit sauberen Berechtigungen.

#### 1.4 Agent-Adapter-System (`agents/<agent>/adapters/`)
Jeder Agent implementiert eine einheitliche Schnittstelle:
* `adapter_install()`: Richtet Abhängigkeiten, VENVs oder Docker-Images ein.
* `adapter_start()`: Startet den Dienst im Hintergrund mit PID-Tracking.
* `adapter_stop()`: Beendet den Prozess ordnungsgemäß.
* `adapter_status()`: Gibt den aktuellen Betriebszustand aus.
* `adapter_logs()`: Zeigt relevante Protokolle.
* `adapter_health()`: Liefert standardisiert `HEALTHY` oder `STOPPED`.
* `adapter_uninstall()`: Bereinigt Daten und Umgebungen.

---

### 2. Standard-Ports & Schnittstellen

| Dienst | Port | Schnittstelle |
| :--- | :--- | :--- |
| **Ollama Local LLM** | `11434` | `http://localhost:11434` |
| **ComfyUI Image Engine** | `8188` | `http://localhost:8188` |
| **Open WebUI Chat** | `8080` | `http://localhost:8080` |
| **Node-RED Automation** | `1880` | `http://localhost:1880` |
| **Faster-Whisper STT** | `8000` | `http://localhost:8000` (Docker API) |

---

### 3. Log- & Watchdog-System

Alle Aktionen werden in `./logs/` abgelegt:
* `installation.log`: Terminal-Ausgaben, Installations-Logs und Befehlsausführungen.
* `watchdog.log`: Healthcheck-Ergebnisse und Auto-Recovery-Aktionen.

Log-Stufen: `[INFO]`, `[OK]`, `[WARN]`, `[ERROR]`, `[RECOVERY]`.
