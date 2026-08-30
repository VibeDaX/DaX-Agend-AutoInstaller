#!/usr/bin/env python3
# =============================================================================
# DAX CONTROL PLANE — STATE HELPER MODULE (lib/state_helper.py)
# Zentrales Python-Modul für JSON-Read/Write-Operationen
# =============================================================================

import json
import os
import sys
import subprocess


def json_read(path):
    """Liest eine JSON-Datei und gibt das Dict zurück."""
    with open(path, 'r') as f:
        return json.load(f)


def json_write(path, data):
    """Schreibt ein Dict als JSON-Datei."""
    with open(path, 'w') as f:
        json.dump(data, f, indent=2)


def json_get_secret(data, key):
    """Liest einen Secret-Wert aus einem Dict mit 'secrets' oder 'keys' Key."""
    sec = data.get('secrets', data.get('keys', {}))
    return sec.get(key, '')


def json_set_secret(data, key, value):
    """Setzt einen Secret-Wert in einem Dict mit 'secrets' oder 'keys' Key."""
    if 'secrets' in data:
        data['secrets'][key] = value
    elif 'keys' in data:
        data['keys'][key] = value
    return data


def json_del_secret(data, key):
    """Löscht einen Secret-Wert aus einem Dict mit 'secrets' oder 'keys' Key."""
    for container in ('secrets', 'keys'):
        if container in data and key in data[container]:
            del data[container][key]
    return data


def decrypt_value(ciphertext, master_key_file):
    """Entschlüsselt einen AES-256-CBC verschlüsselten Wert."""
    if not ciphertext.startswith('enc:'):
        return ciphertext
    raw = ciphertext[4:]
    try:
        res = subprocess.check_output(
            ['openssl', 'enc', '-d', '-aes-256-cbc', '-pbkdf2', '-salt',
             '-pass', f'file:{master_key_file}', '-a', '-A'],
            input=raw.encode()
        ).decode().strip()
        return res
    except Exception:
        return ''


def print_envfile(data, master_key_file):
    """Gibt Key=Value Paare für ein Envfile aus, entschlüsselt enc: Werte."""
    sec = data.get('secrets', data.get('keys', {}))
    for k, v in sec.items():
        if v.startswith('${') and v.endswith('}'):
            continue
        if v.startswith('enc:'):
            raw = v[4:]
            try:
                res = subprocess.check_output(
                    ['openssl', 'enc', '-d', '-aes-256-cbc', '-pbkdf2', '-salt',
                     '-pass', f'file:{master_key_file}', '-a', '-A'],
                    input=raw.encode()
                ).decode().strip()
                print(f'{k}={res}')
            except Exception:
                pass
        else:
            print(f'{k}={v}')


def update_watchdog(path, service, status):
    """Aktualisiert den Watchdog-Status für einen Service."""
    if os.path.exists(path):
        with open(path, 'r') as f:
            d = json.load(f)
    else:
        d = {}

    if service in d:
        node = d[service]
    else:
        node = {'attempts': 0, 'last_status': 'UNKNOWN'}

    if status == 'HEALTHY':
        node['attempts'] = 0
    else:
        node['attempts'] = node.get('attempts', 0) + 1

    node['last_status'] = status
    d[service] = node

    with open(path, 'w') as f:
        json.dump(d, f, indent=2)


def json_get(data, key_path, default=''):
    """Holt einen Wert aus einem verschachtelten Dict via Dot-Notation."""
    keys = key_path.split('.')
    current = data
    for key in keys:
        if isinstance(current, dict) and key in current:
            current = current[key]
        else:
            return default
    return current


if __name__ == '__main__':
    # CLI-Interface für direkte Aufrufe
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'help'

    if cmd == 'json_read':
        path = sys.argv[2]
        print(json.dumps(json_read(path)))

    elif cmd == 'json_write':
        path = sys.argv[2]
        data = json.loads(sys.argv[3])
        json_write(path, data)

    elif cmd == 'json_get_secret':
        path = sys.argv[2]
        key = sys.argv[3]
        data = json_read(path)
        print(json_get_secret(data, key))

    elif cmd == 'json_set_secret':
        path = sys.argv[2]
        key = sys.argv[3]
        value = sys.argv[4]
        data = json_read(path)
        json_set_secret(data, key, value)
        json_write(path, data)

    elif cmd == 'json_del_secret':
        path = sys.argv[2]
        key = sys.argv[3]
        data = json_read(path)
        json_del_secret(data, key)
        json_write(path, data)

    elif cmd == 'decrypt':
        ciphertext = sys.argv[2]
        master_key_file = sys.argv[3]
        print(decrypt_value(ciphertext, master_key_file))

    elif cmd == 'print_envfile':
        path = sys.argv[2]
        master_key_file = sys.argv[3]
        data = json_read(path)
        print_envfile(data, master_key_file)

    elif cmd == 'update_watchdog':
        path = sys.argv[2]
        service = sys.argv[3]
        status = sys.argv[4]
        update_watchdog(path, service, status)

    elif cmd == 'json_get':
        path = sys.argv[2]
        key_path = sys.argv[3]
        default = sys.argv[4] if len(sys.argv) > 4 else ''
        data = json_read(path)
        print(json_get(data, key_path, default))

    else:
        print(f'Unknown command: {cmd}', file=sys.stderr)
        sys.exit(1)
