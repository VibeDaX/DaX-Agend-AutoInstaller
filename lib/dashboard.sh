#!/usr/bin/env bash
# =============================================================================
# DAX CONTROL PLANE — DASHBOARD MODULE (lib/dashboard.sh)
# Embedded Web Status Dashboard & JSON API (Port 9090)
# =============================================================================
set -Eeuo pipefail

DASHBOARD_PORT="${DASHBOARD_PORT:-9090}"
DASHBOARD_PID_FILE="$PID_DIR/dashboard.pid"

dashboard_start(){
  if [[ -f "$DASHBOARD_PID_FILE" ]] && kill -0 "$(cat "$DASHBOARD_PID_FILE")" 2>/dev/null; then
    ok "Web Dashboard läuft bereits auf http://localhost:$DASHBOARD_PORT (PID: $(cat "$DASHBOARD_PID_FILE"))"
    return 0
  fi

  info "Starte Web Dashboard auf Port $DASHBOARD_PORT..."
  python3 -c "
import http.server, socketserver, json, os, subprocess

PORT = $DASHBOARD_PORT
STATE_DIR = '$STATE_DIR'

class DashboardHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/api/status':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()

            state = {}
            if os.path.exists(os.path.join(STATE_DIR, 'state.json')):
                with open(os.path.join(STATE_DIR, 'state.json')) as f:
                    state = json.load(f)

            watchdog = {}
            if os.path.exists(os.path.join(STATE_DIR, 'watchdog.json')):
                with open(os.path.join(STATE_DIR, 'watchdog.json')) as f:
                    watchdog = json.load(f)

            resp = {
                'status': 'ONLINE',
                'version': state.get('version', '6.3-control-plane'),
                'platform': state.get('platform', 'unknown'),
                'os_name': state.get('os_name', 'Linux'),
                'gpu_type': state.get('gpu_type', 'cpu'),
                'gpu_name': state.get('gpu_name', 'CPU'),
                'capabilities': state.get('capabilities', {}),
                'watchdog': watchdog
            }
            self.wfile.write(json.dumps(resp, indent=2).encode())
        else:
            self.send_response(200)
            self.send_header('Content-type', 'text/html; charset=utf-8')
            self.end_headers()
            html = '''<!DOCTYPE html>
<html>
<head>
    <title>DAX Control Plane Dashboard</title>
    <meta charset='utf-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1'>
    <style>
        body { font-family: system-ui, sans-serif; background: #0b0f19; color: #e2e8f0; margin: 0; padding: 2rem; }
        .card { background: #1e293b; border-radius: 12px; padding: 1.5rem; margin-bottom: 1.5rem; border: 1px solid #334155; }
        h1 { color: #00d2ff; font-size: 1.8rem; margin-top: 0; }
        h2 { color: #00ff7f; font-size: 1.2rem; margin-top: 0; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 1rem; }
        .badge { background: #00ff7f; color: #000; padding: 4px 10px; border-radius: 20px; font-weight: bold; font-size: 0.8rem; }
        pre { background: #0f172a; padding: 1rem; border-radius: 8px; overflow-x: auto; color: #38bdf8; }
    </style>
</head>
<body>
    <div class='card'>
        <h1>🤖 DAX Control Plane (v6.3) Status Dashboard</h1>
        <p>Live Monitoring & API Server &nbsp; <span class='badge'>ONLINE</span></p>
    </div>
    <div class='grid'>
        <div class='card'>
            <h2>🖥️ Platform & Hardware</h2>
            <div id='sysinfo'>Lade Daten...</div>
        </div>
        <div class='card'>
            <h2>🛡️ Watchdog & Services</h2>
            <div id='watchdog'>Lade Daten...</div>
        </div>
    </div>
    <div class='card'>
        <h2>🔌 JSON API Status (/api/status)</h2>
        <pre id='json-output'>Lade JSON...</pre>
    </div>
    <script>
        async function fetchStatus() {
            try {
                const res = await fetch('/api/status');
                const data = await res.json();
                document.getElementById('json-output').innerText = JSON.stringify(data, null, 2);
                document.getElementById('sysinfo').innerHTML = `
                    <p><b>OS:</b> ${data.os_name} (${data.platform})</p>
                    <p><b>GPU:</b> ${data.gpu_name} [${data.gpu_type}]</p>
                    <p><b>Docker Daemon:</b> ${data.capabilities.docker_daemon ? '✔ ERREICHBAR' : '✖ OFF'}</p>
                    <p><b>KVM Virtualisierung:</b> ${data.capabilities.kvm_device ? '✔ ACTIVATED' : '✖ OFF'}</p>
                `;
                document.getElementById('watchdog').innerHTML = `
                    <pre>${JSON.stringify(data.watchdog, null, 2)}</pre>
                `;
            } catch (e) {
                console.error(e);
            }
        }
        fetchStatus();
        setInterval(fetchStatus, 5000);
    </script>
</body>
</html>'''
            self.wfile.write(html.encode())

with socketserver.TCPServer(('', PORT), DashboardHandler) as httpd:
    httpd.serve_forever()
" >/dev/null 2>&1 &
  local pid=$!
  echo "$pid" > "$DASHBOARD_PID_FILE"
  wait_for_port "$DASHBOARD_PORT" 10 || warn "Dashboard Port $DASHBOARD_PORT nicht erreichbar."
  ok "Web Dashboard gestartet auf http://localhost:$DASHBOARD_PORT (PID: $pid)"
}

dashboard_stop(){
  if [[ -f "$DASHBOARD_PID_FILE" ]]; then
    local pid
    pid="$(cat "$DASHBOARD_PID_FILE")"
    kill "$pid" 2>/dev/null || true
    rm -f "$DASHBOARD_PID_FILE"
    ok "Web Dashboard gestoppt (PID: $pid)."
  else
    warn "Web Dashboard läuft derzeit nicht."
  fi
}

dashboard_status(){
  if [[ -f "$DASHBOARD_PID_FILE" ]] && kill -0 "$(cat "$DASHBOARD_PID_FILE")" 2>/dev/null; then
    echo "Web Dashboard: RUNNING (http://localhost:$DASHBOARD_PORT)"
  else
    echo "Web Dashboard: STOPPED"
  fi
}

dashboard_manager(){
  echo "=== WEB STATUS DASHBOARD & API (PORT 9090) ==="
  dashboard_status
  echo "1) Web Dashboard starten"
  echo "2) Web Dashboard stoppen"
  read -rp "Auswahl: " c
  case "$c" in
    1) dashboard_start ;;
    2) dashboard_stop ;;
  esac
}
