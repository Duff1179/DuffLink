const { app, BrowserWindow, ipcMain, Tray, Menu, Notification, nativeImage } = require('electron');
const path = require('path');
const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const os = require('os');
const dgram = require('dgram'); // ADDED for Roku Auto-Discovery

let mainWindow;
let tray = null;
let clientWss = null;
let httpServer = null;
let pollTimeout = null;
let pollFailCount = 0;
let hasShownTrayNotif = false;

// UDP Broadcast variables
let udpClient = null;
let udpInterval = null;

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

app.whenReady().then(() => {
  mainWindow = new BrowserWindow({
    width: 480, height: 600, resizable: false, title: 'DuffLink',
    webPreferences: { nodeIntegration: true, contextIsolation: false, zoomFactor: 1.0 },
  });
  mainWindow.loadFile('ui/index.html');
  mainWindow.setMenuBarVisibility(false);
  mainWindow.webContents.on('did-finish-load', () => mainWindow.webContents.setZoomFactor(1.0));

  mainWindow.on('minimize', (event) => {
    if (tray) {
      event.preventDefault(); mainWindow.hide();
      if (!hasShownTrayNotif && Notification.isSupported()) {
        new Notification({ title: 'DuffLink minimized', body: 'DuffLink is still running in the background. Check your system tray to open it.', icon: path.join(__dirname, 'icon.ico') }).show();
        hasShownTrayNotif = true;
      }
    }
  });

  try {
    const trayIconPath = path.join(__dirname, 'tray-icon.png');
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
  } catch (err) { tray = null; }
});

app.on('window-all-closed', () => { cleanup(); app.quit(); });

function fetchJson(url) {
  return new Promise((resolve) => {
    const req = http.get(url, { timeout: 2000 }, (res) => {
      if (res.statusCode !== 200) { res.resume(); return resolve(null); }
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => { try { resolve(JSON.parse(data)); } catch (e) { resolve(null); } });
    });
    req.on('error', () => resolve(null));
    req.on('timeout', () => { req.destroy(); resolve(null); });
  });
}

ipcMain.handle('connect', async (event, { ip, port, serviceTimes }) => {
  cleanup();
  state.serviceTimes = serviceTimes || [];
  state.connected = false;

  const expressApp = express();
  expressApp.use(express.static(path.join(__dirname, 'ui/client')));
  
  // ADDED: Simple HTTP endpoint for the Roku to poll
  expressApp.get('/api/state', (req, res) => res.json(state)); 

  httpServer = http.createServer(expressApp);
  clientWss = new WebSocket.Server({ server: httpServer });
  clientWss.on('connection', (ws) => ws.send(JSON.stringify({ type: 'state', payload: state })));
  
  await new Promise(r => httpServer.listen(8765, '0.0.0.0', r));

  return new Promise((resolve) => {
      const req = http.get(`http://${ip}:${port}/v1/presentation/active`, { timeout: 4000 }, (res) => {
          res.resume();
          state.connected = true;
          const localIp = getLocalIp();
          startPolling(ip, port);
          
          // ADDED: Start UDP Broadcasting so Roku can auto-discover
          startUdpBroadcast(localIp);

          resolve({ ok: true, url: `http://${localIp}:8765` });
      });
      req.on('error', () => { cleanup(); resolve({ ok: false, error: 'Could not connect.' }); });
      req.on('timeout', () => { req.destroy(); cleanup(); resolve({ ok: false, error: 'Connection timed out.' }); });
  });
});

ipcMain.handle('disconnect', () => { cleanup(); });

function startUdpBroadcast(ip) {
    udpClient = dgram.createSocket('udp4');
    udpClient.bind(() => udpClient.setBroadcast(true));
    const broadcastMsg = Buffer.from(JSON.stringify({ app: 'DuffLink', ip: ip, port: 8765 }));
    udpInterval = setInterval(() => {
        if (udpClient) udpClient.send(broadcastMsg, 0, broadcastMsg.length, 8766, '255.255.255.255');
    }, 2000); // Shouts its location every 2 seconds
}

async function startPolling(ip, port) {
    if (!state.connected) return;
    const baseUrl = `http://${ip}:${port}`;
    try {
        const [presRes, slideIndexRes, slideStatusRes, timersRes] = await Promise.all([
            fetchJson(`${baseUrl}/v1/presentation/active`),
            fetchJson(`${baseUrl}/v1/presentation/slide_index`),
            fetchJson(`${baseUrl}/v1/status/slide`),
            fetchJson(`${baseUrl}/v1/timers/current`)
        ]);

        if (presRes === null && slideIndexRes === null && slideStatusRes === null && timersRes === null) {
            pollFailCount++;
            if (pollFailCount >= 5) { cleanup(true); return; }
        } else {
            pollFailCount = 0;
            if (presRes && presRes.presentation) {
                state.presentationName = presRes.presentation.id?.name || state.presentationName;
                const slides = presRes.presentation.groups ? presRes.presentation.groups.flatMap(g => g.slides || []) : [];
                state.slideCount = slides.length;
            } else if (presRes === null) {
                state.presentationName = ''; state.slideCount = 0;
            }

            let idx = 0;
            if (slideIndexRes) {
                if (typeof slideIndexRes.presentation_index === 'object') idx = slideIndexRes.presentation_index.index;
                else if (slideIndexRes.index !== undefined) idx = slideIndexRes.index;
                else idx = parseInt(slideIndexRes, 10);
            }
            state.slideIndex = isNaN(idx) ? 0 : idx;

            if (slideStatusRes && slideStatusRes.current) {
                state.currentSlideText = slideStatusRes.current.text || '';
                state.nextSlideText = slideStatusRes.next?.text || '';
            } else {
                state.currentSlideText = '';
                state.nextSlideText = '';
            }

            if (Array.isArray(timersRes)) {
                state.clocks = timersRes.map(t => ({ name: t.id?.name || "Timer", time: t.time || "", state: String(t.state || "stopped").toLowerCase() }));
            } else { state.clocks = []; }

            updateServiceStart();
            broadcast({ type: "state", payload: state });
        }
    } catch (err) {}
    pollTimeout = setTimeout(() => startPolling(ip, port), 1000);
}

function updateServiceStart() {
    if (!state.serviceTimes || state.serviceTimes.length === 0) return;
    const now = Date.now();
    let best = null; let minDiff = Infinity; let nextUpcoming = null; let minUpcomingDiff = Infinity;
    for (const t of state.serviceTimes) {
        const diff = now - new Date(t).getTime();
        if (diff >= 0) { if (diff < minDiff) { minDiff = diff; best = t; } } 
        else { if (-diff < minUpcomingDiff) { minUpcomingDiff = -diff; nextUpcoming = t; } }
    }
    state.serviceStartISO = best || nextUpcoming;
}

function broadcast(msg) {
  if (!clientWss) return;
  const data = JSON.stringify(msg);
  clientWss.clients.forEach(ws => { if (ws.readyState === WebSocket.OPEN) ws.send(data); });
}

function getLocalIp() {
  const ifaces = os.networkInterfaces();
  for (const name of Object.keys(ifaces)) {
    for (const iface of ifaces[name]) { if (iface.family === 'IPv4' && !iface.internal) return iface.address; }
  }
  return 'localhost';
}

function cleanup(emitDisconnect = false) {
  clearTimeout(pollTimeout);
  if (udpInterval) { clearInterval(udpInterval); udpInterval = null; }
  if (udpClient) { try { udpClient.close(); } catch(e){} udpClient = null; }
  pollFailCount = 0;
  httpServer?.close(); httpServer = null;
  clientWss = null;
  state.connected = false; state.clocks = [];
  if (emitDisconnect) mainWindow?.webContents.send('disconnected');
}