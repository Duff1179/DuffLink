const { app, BrowserWindow, ipcMain, Tray, Menu, Notification, nativeImage } = require('electron');
const path = require('path');
const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const os = require('os');

let mainWindow;
let tray = null;
let clientWss = null;
let httpServer = null;
let pollTimeout = null;
let pollFailCount = 0;
let hasShownTrayNotif = false;

let state = {
  connected: false,
  presentationName: '',
  currentSlideText: '',
  nextSlideText: '',
  slideIndex: 0,
  slideCount: 0,
  clocks: [],
  serviceStartISO: null,
  serviceTimes: []
};

// ── Electron window ───────────────────────────────────────────────────────────
app.whenReady().then(() => {
  mainWindow = new BrowserWindow({
    width: 480,
    height: 600,
    resizable: false,
    title: 'DuffLink',
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false,
      zoomFactor: 1.0 // Explicitly forces the UI back to 100% to clear Electron's cache
    },
  });
  mainWindow.loadFile('ui/index.html');
  mainWindow.setMenuBarVisibility(false);
  
  // Secondary failsafe to ensure the web contents zoom is reset
  mainWindow.webContents.on('did-finish-load', () => {
    mainWindow.webContents.setZoomFactor(1.0);
  });

  // ── Native Minimize Interceptor ──
  // Intercepts the standard Windows '-' minimize button
  mainWindow.on('minimize', (event) => {
    if (tray) {
      event.preventDefault(); // Stop standard minimize
      mainWindow.hide();      // Hide to tray instead

      if (!hasShownTrayNotif && Notification.isSupported()) {
        new Notification({
          title: 'DuffLink minimized',
          body: 'DuffLink is still running in the background. Check your system tray to open it.',
          icon: path.join(__dirname, 'icon.ico')
        }).show();
        hasShownTrayNotif = true;
      }
    }
  });

  // ── System Tray Setup ──
  try {
    const trayIconPath = path.join(__dirname, 'tray-icon.png');
    
    // Load the image AND force it to 16x16 right here
    const trayImage = nativeImage.createFromPath(trayIconPath).resize({ width: 16, height: 16 }); 
    
    tray = new Tray(trayImage);
    
    const contextMenu = Menu.buildFromTemplate([
      { label: 'Show DuffLink', click: () => mainWindow.show() },
      { type: 'separator' },
      { label: 'Quit', click: () => { cleanup(); app.quit(); } }
    ]);
    
    tray.setToolTip('DuffLink Stage Monitor');
    tray.setContextMenu(contextMenu);

    tray.on('click', () => mainWindow.show());
  } catch (err) {
    console.error("Failed to create tray icon:", err);
    tray = null;
  }
});

app.on('window-all-closed', () => { cleanup(); app.quit(); });

// ── HTTP JSON Fetcher ─────────────────────────────────────────────────────────
function fetchJson(url) {
  return new Promise((resolve) => {
    const req = http.get(url, { timeout: 2000 }, (res) => {
      if (res.statusCode !== 200) {
          res.resume();
          return resolve(null);
      }
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try { resolve(JSON.parse(data)); }
        catch (e) { resolve(null); }
      });
    });
    req.on('error', () => resolve(null));
    req.on('timeout', () => { req.destroy(); resolve(null); });
  });
}

// ── IPC Handlers ──────────────────────────────────────────────────────────────
ipcMain.handle('connect', async (event, { ip, port, serviceTimes }) => {
  cleanup();
  state.serviceTimes = serviceTimes || [];
  state.connected = false;

  const expressApp = express();
  expressApp.use(express.static(path.join(__dirname, 'ui/client')));
  httpServer = http.createServer(expressApp);
  clientWss = new WebSocket.Server({ server: httpServer });
  clientWss.on('connection', (ws) => {
    ws.send(JSON.stringify({ type: 'state', payload: state }));
  });
  
  await new Promise(r => httpServer.listen(8765, '0.0.0.0', r));

  return new Promise((resolve) => {
      const req = http.get(`http://${ip}:${port}/v1/presentation/active`, { timeout: 4000 }, (res) => {
          res.resume();
          state.connected = true;
          const localIp = getLocalIp();
          startPolling(ip, port);
          resolve({ ok: true, url: `http://${localIp}:8765` });
      });
      req.on('error', (err) => {
          cleanup();
          resolve({ ok: false, error: 'Could not connect. Ensure ProPresenter network is enabled and OpenAPI port is correct.' });
      });
      req.on('timeout', () => {
          req.destroy();
          cleanup();
          resolve({ ok: false, error: 'Connection timed out. Check your IP and OpenAPI port.' });
      });
  });
});

ipcMain.handle('disconnect', () => { cleanup(); });

// ── ProPresenter Polling (OpenAPI) ────────────────────────────────────────────
async function startPolling(ip, port) {
    if (!state.connected) return;
    const baseUrl = `http://${ip}:${port}`;

    try {
        const [presRes, idxRes, timersRes] = await Promise.all([
            fetchJson(`${baseUrl}/v1/presentation/active`),
            fetchJson(`${baseUrl}/v1/presentation/slide_index`),
            fetchJson(`${baseUrl}/v1/timers/current`) // <-- Updated endpoint
        ]);

        if (presRes === null && idxRes === null && timersRes === null) {
            pollFailCount++;
            if (pollFailCount >= 5) {
                cleanup(true);
                return;
            }
        } else {
            pollFailCount = 0;
            if (presRes && presRes.presentation) {
                state.presentationName = presRes.presentation.id?.name || state.presentationName;
                let slides = [];
                if (presRes.presentation.groups) {
                    slides = presRes.presentation.groups.flatMap(g => g.slides || []);
                }
                state.slideCount = slides.length;
                
                let idx = 0;
                if (idxRes) {
                    if (typeof idxRes.presentation_index === 'object') idx = idxRes.presentation_index.index;
                    else if (idxRes.index !== undefined) idx = idxRes.index;
                    else idx = parseInt(idxRes, 10);
                }
                state.slideIndex = isNaN(idx) ? 0 : idx;
                
                state.currentSlideText = slides[state.slideIndex]?.text || '';
                state.nextSlideText = slides[state.slideIndex + 1]?.text || '';
            } else if (presRes === null) {
                state.presentationName = '';
                state.currentSlideText = '';
                state.nextSlideText = '';
                state.slideCount = 0;
            }

            // ── EXACT JSON PARSER ──
            if (Array.isArray(timersRes)) {
                state.clocks = timersRes.map(t => ({
                    name: t.id?.name || "Timer",
                    time: t.time || "",
                    state: String(t.state || "stopped").toLowerCase()
                }));
            } else {
                state.clocks = [];
            }

            updateServiceStart();
            broadcast({ type: "state", payload: state });
        }
    } catch (err) {
        // Safe to ignore
    }

    pollTimeout = setTimeout(() => startPolling(ip, port), 1000);
}

// ── Helpers ───────────────────────────────────────────────────────────────────
function updateServiceStart() {
    if (!state.serviceTimes || state.serviceTimes.length === 0) return;
    const now = Date.now();
    let best = null;
    let minDiff = Infinity;
    let nextUpcoming = null;
    let minUpcomingDiff = Infinity;

    for (const t of state.serviceTimes) {
        const ms = new Date(t).getTime();
        const diff = now - ms;
        if (diff >= 0) { 
            if (diff < minDiff) {
                minDiff = diff;
                best = t;
            }
        } else { 
            if (-diff < minUpcomingDiff) {
                minUpcomingDiff = -diff;
                nextUpcoming = t;
            }
        }
    }
    state.serviceStartISO = best || nextUpcoming;
}

function broadcast(msg) {
  if (!clientWss) return;
  const data = JSON.stringify(msg);
  clientWss.clients.forEach(ws => {
    if (ws.readyState === WebSocket.OPEN) ws.send(data);
  });
}

function getLocalIp() {
  const ifaces = os.networkInterfaces();
  for (const name of Object.keys(ifaces)) {
    for (const iface of ifaces[name]) {
      if (iface.family === 'IPv4' && !iface.internal) return iface.address;
    }
  }
  return 'localhost';
}

function cleanup(emitDisconnect = false) {
  clearTimeout(pollTimeout);
  pollFailCount = 0;
  httpServer?.close(); httpServer = null;
  clientWss = null;
  state.connected = false;
  state.clocks = [];
  if (emitDisconnect) {
     mainWindow?.webContents.send('disconnected');
  }
}