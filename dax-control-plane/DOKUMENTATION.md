## 📖 DAX Control Plane Dokumentation

**Version:** v6.3-control-plane

**Architektur:** Bash / Linux Shell Execution

---

### 1. Architektur & Funktionsweise

Das DAX Control Plane Bundle ist ein modulares Steuerungswerkzeug für Linux-Systeme, das mehrere Runtime- und Agenten-management-Komponenten in einer einheitlichen Control-Plane-Hierarchie vereint.

#### Host
- Native Runtime (Systemdienste, Python/VENV, direkt gestartete Daemons)
- Docker Runtime (Kontainer, Compose, Agent-Images)
- KVM/QEMU Runtime (VMs über libvirt/virt-install)
- Remote Runtime (SSH-basierte Remote-Exec-Schnittstelle)

#### Control-Plane-Module

- **Policy Engine**: `.dax/policy.yaml` definiert, welche Runtimes auf welcher Plattform erlaubt/verboten sind, und welche Runtimes pro Agent erlaubt sind. Funktionsweise: `policy_allow_runtime_for_platform runtime` und `policy_allow_runtime_for_agent agent runtime`.
- **Agent-Adapter-System**: Jeder Agent (`agents/*/manifest.yaml`) definiert unterstützte Runtimes, Default-Runtime und angehängte Volumes. Adapter-Skripte (`adapters/{runtime}.sh`) implementieren die Einheitsschnittstelle. Der Dispatch-Mechanismus `agent_dispatch agent action runtime` wählt den richtigen Adapter aus.
- **Watchdog**: `.dax/watchdog.json` speichert Health-Status und Wiederholungsversuche je Service/Agent. `watchdog_tick service status` aktualisiert den State.
- **Remote Runtime**: `.dax/remote_hosts.yaml` listet Remote-Hosts mit Host, User, Port und Tags. `remote_exec host_id cmd` führt Befehle per SSH aus.
- **Secrets Manager**: `.dax/secrets/` enthält global secrets.json, agentenspezifische JSONs und remote-Host-Secrets. `secret_set key value` und `secret_get key`.
- **Volume Manager**: `.dax/volumes.yaml` definiert Volume-Klassen (agent_data, cache) und konkrete Volumes mit Host-Pfad, Container-Pfad, Typ (docker_bind), Owner und Mode. `volume_ensure vol` und `volume_mount_docker vol`.
- **Template Engine**: Templates in `templates/` für VMs, Agent-Stacks, Compose-Dateien, Remote-Hosts. Wird vom jeweiligen Manager-Kontext konsumiert.

---

### 2. Menü-Übersicht (Main Menu)

```
HOST
  [0] System / Capability Check

RUNTIMES
  [1] Native Runtime / System Dependencies
  [2] Docker Runtime
  [3] KVM / VM Runtime
  [4] Remote Runtime

CONTROL-PLANE MODULES
  [5] Agent Manager / Deployment Wizard
  [6] Agent Profiles
  [7] Policy Manager
  [8] Volume Manager
  [9] Secrets Manager
  [10] Template Manager

SERVICES
  [11] Ollama konfigurieren
  [12] Ollama Modell laden
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

### 3. Agent-Manifest-Kontrakt

Jedes `agents/*/manifest.yaml` kann definieren:

- `name`, `version`
- `supported_runtimes` (Liste)
- `default_runtime`
- `volumes` (Liste)
- `resources` (cpus, memory)
- `security` (non_root, no_new_privileges, cap_drop_all)
- `network` (mode)
- `healthcheck` (enabled)

---

### 4. Adapter-Schnittstelle

Jeder `adapters/{runtime}.sh` stellt folgende Funktionen bereit:

- `adapter_install()`
- `adapter_start()`
- `adapter_stop()`
- `adapter_status()`
- `adapter_logs()`
- `adapter_health()`
- `adapter_uninstall()`

Der Dispatch-Mechanismus (`agent_dispatch`) quillt den richtigen Adapter basierend auf Agent-Manifest und Policy.

---

### 5. Wartung & Erweiterung

- **Neuen Agenten hinzufügen**: `agents/<name>/manifest.yaml` anlegen, `agents/<name>/adapters/` mit den gewünschten Runtime-Adaptern befüllen.
- **Neues Runtime-Ziel**: Neuer Adapter unter `agents/<name>/adapters/<runtime>.sh` + Policy-Eintrag in `.dax/policy.yaml`.
- **Remote-Hosts**: `.dax/remote_hosts.yaml` erweitern.
- **Templates**: Neue YAML-Dateien unter `templates/<category>/` ablegen; Compose-Templates werden von `template_apply_compose` direkt auf `docker/compose.yml` kopiert.
