# DAX Control Plane Bundle

Komplettes DAX Command Center als Control-Plane-Architektur — Policy Engine, Agent-Adapter-System, Watchdog, Remote Runtime, Secrets Manager, Volume Manager und Template Engine.

## Struktur

```text
dax-control-plane/
  dax.sh                      # Hauptscript (Command Center v6.3 + Erweiterungen)
  .dax/
    policy.yaml               # Policy Engine
    volumes.yaml              # Volume Manager
    remote_hosts.yaml         # Remote Runtime Hosts
    secrets/
      master.key              # AES-256-GCM Key
      secrets.json            # globale Secrets
      agents/
        hermes.json
        openclaw.json
      remote/
        lab01.json
    watchdog.json             # Watchdog State
  agents/
    hermes/
      manifest.yaml
      adapters/
        native.sh
        docker.sh
        kvm.sh
        remote.sh
    openclaw/
      manifest.yaml
      adapters/
        native.sh
        docker.sh
        kvm.sh
        remote.sh
  templates/
    vm/
      ubuntu-small.yaml
      ubuntu-gpu.yaml
    agents/
      hermes-stack.yaml
      openclaw-stack.yaml
    compose/
      ollama-comfyui.yaml
      full-stack.yaml
    remote/
      lab01-hermes.yaml
  logs/
    installation.log
    watchdog.log
  backups/
    README.md
```

## Schnellstart

```bash
cd dax-control-plane
chmod +x dax.sh
./dax.sh
```

## Module

- **Policy Engine** — Plattform- und Agent-Runtime-Richtlinien (.dax/policy.yaml)
- **Agent-Adapter-System** — Einheitliche Adapter-Schnittstelle für native/docker/kvm/remote
- **Watchdog** — Health-State-Tracking (.dax/watchdog.json)
- **Remote Runtime** — SSH-basierte Remote-Exec-Schnittstelle (.dax/remote_hosts.yaml)
- **Secrets Manager** — Globale + agentenspezifische Secrets (.dax/secrets/)
- **Volume Manager** — Docker-Bind-Mount-Definitionen (.dax/volumes.yaml)
- **Template Engine** — VM-, Agent-, Compose- und Remote-Templates (templates/)

## Anforderungen

- Linux (Debian/Ubuntu empfohlen), WSL2 oder Termux/PRoot
- Python 3, pip, venv
- Docker (optional, für Kontainer-Runtime)
- KVM/QEMU + libvirt (optional, für VM-Runtime)
