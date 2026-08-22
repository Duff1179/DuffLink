# DuffLink — ProPresenter Stage Display

A desktop app that connects to ProPresenter's API and hosts a stage display web page that any device on your network can open.

## What it does

* **Host PC runs the app** → enter your ProPresenter IP, port, and service start time
* **Phone/tablet opens a browser** → sees a live dark stage display with:

  * Current slide text
  * Next slide text
  * Current presentation name
  * Slides remaining in the current presentation
  * Active ProPresenter timer (name + value)
  * Elapsed service time (auto-counted from your start time)

## Building the .exe (Windows)

### Prerequisites

* [Node.js](https://nodejs.org/) v18 or newer installed on the build machine

### Steps

Run these commands in the terminal in the DuffLink root folder

```bash
# 1. Install dependencies
npm install

# 2. Build the Windows portable .exe
npm run build:win
```

The output will be at:

```
dist/DuffLink.exe
```

This is a portable single-file executable — no install needed. Just double-click and run.

## Usage

1. Open DuffLink.exe on the **host PC** (the one running ProPresenter, or any PC on the same network)
2. Enter:

   * **IP Address** — the IP of the machine running ProPresenter (check ProPresenter → Preferences → Network)
   * **Port** — default is `1025` for ProPresenter 7
   * **Service Start Time** — used to show elapsed service time on client devices
3. Click **Connect \& Start Hosting**
4. A URL like `http://192.168.1.x:8765` will appear
5. Open that URL on any phone/tablet on the same WiFi network or try to connect using the Roku App
6. You will have to disable screensaver on Roku [Settings -> Theme -> Screensaver -> Start Time -> Never] to make it not time out

## Roku connection choices

When the Roku app starts, choose **DuffLink host** to use automatic discovery or the existing manual DuffLink connection. Choose **Direct ProPresenter 7** to connect to ProPresenter's OpenAPI directly. Enter the ProPresenter IP, port (usually `1025`), and optional same-day service times as comma-separated `HH:MM` values.

## ProPresenter Setup

In ProPresenter 7:

* Go to **Preferences → Network**
* Enable the **Network** toggle
* Note the **IP** and **Port** (default 1025)
* The app uses the ProPresenter WebSocket API (`/v1`)

## Port used by this app

The web server for phone clients runs on port **8765**.
Make sure Windows Firewall allows inbound connections on port 8765 if clients can't connect.

> Quick fix: When Windows asks "Allow access?" after launching, click Allow
> Or manually: Windows Defender Firewall → Allow an app → add ProMonitor.exe
