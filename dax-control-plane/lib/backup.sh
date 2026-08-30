#!/usr/bin/env bash
# =============================================================================
# DAX CONTROL PLANE — BACKUP MODULE (lib/backup.sh)
# AES-256 Encrypted Backup & Restore Engine
# =============================================================================
set -Eeuo pipefail

BACKUP_DIR="$SCRIPT_DIR/data/backups"

backup_create(){
  mkdir -p "$BACKUP_DIR"
  ensure_master_key
  local timestamp
  timestamp="$(date '+%Y%m%d-%H%M%S')"
  local raw_tar="/tmp/dax-backup-${timestamp}.tar.gz"
  local enc_file="$BACKUP_DIR/dax-backup-${timestamp}.tar.gz.enc"

  info "Erstelle Roh-Archiv von .dax/ ..."
  tar -czf "$raw_tar" -C "$SCRIPT_DIR" ".dax" 2>/dev/null || { warn "Fehler beim Erstellen des Tar-Archivs"; return 1; }

  info "Verschlüssele Backup mit AES-256..."
  if command_exists openssl; then
    openssl enc -aes-256-cbc -pbkdf2 -salt -pass "file:$MASTER_KEY_FILE" -in "$raw_tar" -out "$enc_file" 2>/dev/null
    rm -f "$raw_tar"
    ok "Verschlüsseltes Backup erfolgreich erstellt: $enc_file"
    echo "$enc_file"
  else
    mv "$raw_tar" "$BACKUP_DIR/dax-backup-${timestamp}.tar.gz"
    warn "OpenSSL nicht gefunden. Backup unverschlüsselt gespeichert."
  fi
}

backup_list(){
  mkdir -p "$BACKUP_DIR"
  echo "=== DAX ENCRYPTED BACKUPS ==="
  local count=0
  for b in "$BACKUP_DIR"/dax-backup-*; do
    [[ -f "$b" ]] || continue
    echo "  • $(basename "$b") ($(du -h "$b" | awk '{print $1}'))"
    count=$((count + 1))
  done
  if [[ $count -eq 0 ]]; then
    echo "  (Keine Backups gefunden)"
  fi
}

backup_restore(){
  local file="${1:-}"
  if [[ -z "$file" ]]; then
    backup_list
    read -rp "Name des Backup-Archivs (im Ordner data/backups): " file_input
    file="$BACKUP_DIR/$file_input"
  fi

  [[ -f "$file" ]] || { warn "Backup-Datei nicht gefunden: $file"; return 1; }
  ensure_master_key

  local tmp_tar="/tmp/dax-restore-tmp.tar.gz"
  if [[ "$file" == *.enc ]]; then
    info "Entschlüssele Backup-Archiv..."
    openssl enc -d -aes-256-cbc -pbkdf2 -pass "file:$MASTER_KEY_FILE" -in "$file" -out "$tmp_tar" 2>/dev/null || { warn "Entschlüsselung fehlgeschlagen (Falscher Key?)"; return 1; }
  else
    cp "$file" "$tmp_tar"
  fi

  info "Stelle .dax/ Konfiguration wieder her..."
  tar -xzf "$tmp_tar" -C "$SCRIPT_DIR" 2>/dev/null || { warn "Fehler beim Entpacken des Archivs"; rm -f "$tmp_tar"; return 1; }
  rm -f "$tmp_tar"
  ok "Backup erfolgreich wiederhergestellt!"
}

backup_manager(){
  echo "=== ENCRYPTED BACKUP & RESTORE ==="
  echo "1) Neues AES-256 Backup erstellen"
  echo "2) Vorhandene Backups auflisten"
  echo "3) Backup wiederherstellen"
  read -rp "Auswahl: " c
  case "$c" in
    1) backup_create ;;
    2) backup_list ;;
    3) backup_restore ;;
  esac
}
