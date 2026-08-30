# DAX Control Plane Backups

Dieses Verzeichnis enthält Sicherungen von Konfigurationen, Policies und States.

## Was hier hin gehört

- `.dax/` State-Backups (policy.yaml, volumes.yaml, remote_hosts.yaml, watchdog.json)
- `agents/*/manifest.yaml` Backups
- `templates/` Version-strukturierte Snapshots

## Nutzung

Backup-Manual:
```bash
cd /home/dax/DaX Agend AutoInstaller/dax-control-plane
zip -r ../backups/$(date +%Y%m%d_%H%M%S)_dax-backup.zip .dax/ agents/ --exclude '.dax/secrets/*'
```

Hinweis: Secrets (master.key, secrets.json) werden NICHT mitgesichert – diese werden separat verwaltet.
