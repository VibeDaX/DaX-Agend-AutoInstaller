/**
 * ⚡ DAX NEUROTERM - UNIFIED OS v5.8.8 (QUANTUM COMMANDER)
 * ROLE: FRONTEND / TERMINAL-UI / DASHBOARD-VISUALISIERUNG
 * PURPOSE: Reines Frontend-Element für NEXUS-RT Terminal-Interface
 * TYPE: TUI (Text User Interface) - Keine Backend-Logik
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const readline = require('readline');
const { SystemMonitor } = require('./system_monitor');
require('dotenv').config();

const ROOT_DIR = '/data/data/com.termux/files/home/NEXUS-RT';
const TEAMLOG_PATH = path.join(ROOT_DIR, 'storage/nexus-rt/teamlog.json');
const monitor = new SystemMonitor();

const colors = { 
    reset: "\x1b[0m", bright: "\x1b[1m", cyan: "\x1b[38;5;51m", 
    gold: "\x1b[38;5;214m", green: "\x1b[38;5;46m", 
    red: "\x1b[31m", yellow: "\x1b[33m", orange: "\x1b[38;5;208m",
    gray: "\x1b[90m", purple: "\x1b[38;5;165m"
};

let currentView = 'DASHBOARD'; 
let heartbeat = true;
let marathon = { level: 9, currentTasks: 0, targetTasks: 1, elf: 3.85 };

function renderHeader() {
    process.stdout.write('\x1Bc');
    const time = new Date().toLocaleTimeString();
    const freeMem = Math.round(os.freemem() / 1024 / 1024);
    const health = monitor.getHealthStatus();
    const qSymbol = heartbeat ? "🌀" : "  ";
    heartbeat = !heartbeat;

    console.log(`${colors.purple}  ██████╗  █████╗ ██╗  ██╗  ${colors.bright}v5.9.8${colors.reset}`);
    console.log(`${colors.purple}  ██╔══██╗██╔══██╗╚██╗██╔╝  ${colors.purple}QUANTUM COMMANDER${colors.reset}`);
    console.log(`${colors.purple}  ██║  ██║███████║ ╚███╔╝   ${colors.gray}TAG 45 | ${time}${colors.reset}`);
    console.log(`${colors.purple}  ██║  ██║██╔══██║ ██╔██╗   ${colors.cyan}TIME-TRAVEL SYNC ACTIVE${colors.reset}`);
    console.log(`${colors.purple}  ██████╔╝██║  ██║██╔╝ ██╗  ${qSymbol}`);
    console.log(`${colors.purple}  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝${colors.reset}`);

    console.log(`${colors.cyan}┌────────────────────────────────────────────────────────────┐`);
    console.log(`│ RAM: ${freeMem}MB | STATUS: ${colors.purple}TIME-FLOW-LOCKED${colors.cyan} `.padEnd(68) + `│`);
    console.log(`└────────────────────────────────────────────────────────────┘${colors.reset}`);
}

function renderDashboard() {
    renderHeader();
    console.log(`\n ${colors.bright}QUANTUM COMMANDS:${colors.reset}`);
    console.log(` ${colors.cyan}[F]${colors.reset} Explorer   | ${colors.cyan}[A]${colors.reset} History    | ${colors.purple}[Q]${colors.reset} Branching`);
    console.log(` ${colors.gold}[M]${colors.reset} Metrics    | ${colors.pink}[R]${colors.reset} Rewind     | ${colors.red}[X]${colors.reset} Exit`);
    
    console.log(`\n ${colors.yellow}System-Integrity: 100% | Current Branch: evolution-v1${colors.reset}`);
    console.log(` ${colors.gold}Current Intelligence Level: x${marathon.elf}${colors.reset}`);
}

function renderQuantum() {
    renderHeader();
    console.log(`\n ${colors.purple}🌌 QUANTUM BRANCHING CONTROL${colors.reset}`);
    console.log(` ────────────────────────────────────────────────────────────`);
    console.log(` 1. Create New Timeline (Branch)`);
    console.log(` 2. Merge Realities (Merge to Main)`);
    console.log(` 3. Purge Dead Timelines (Branch Cleanup)`);
    console.log(` ────────────────────────────────────────────────────────────`);
    console.log(`\n ${colors.bg_teal} B: Back ${colors.reset}`);
}

readline.emitKeypressEvents(process.stdin);
if (process.stdin.isTTY) process.stdin.setRawMode(true);
process.stdin.on('keypress', (s, k) => {
    if (k && k.name === 'x') process.exit();
    if (currentView === 'DASHBOARD') {
        if (k.name === 'q') { currentView = 'QUANTUM'; renderQuantum(); }
    } else if (k.name === 'b') { currentView = 'DASHBOARD'; renderDashboard(); }
});

setInterval(() => {
    if (currentView === 'DASHBOARD') renderDashboard();
    else if (currentView === 'QUANTUM') renderQuantum();
}, 1000);

renderDashboard();
