# DuffLink

DuffLink is a desktop host for a ProPresenter stage display. It connects to ProPresenter's OpenAPI, then serves live presentation information to phones, tablets, web browsers, and Roku devices on the same local network.

## Recent changes

* Added automatic reconnecting for ProPresenter 7 API endpoints when the app is relaunched
* Fixed service times not displaying until the hour was changed
* Fixed HTTP API leak that would cause the app to crash after half and hour
* Improved stability across the application
* Standardized the reconnection process
* Changed ProPresenter 7 API to be the default connection

## Displayed information

Connected clients can show:

* Current slide text
* Next slide text
* Presentation name
* Slides remaining
* Active ProPresenter timer and timer name
* Elapsed service time

## Requirements

* Windows host PC with [Node.js](https://nodejs.org/) 18 or newer for building
* ProPresenter 7 with its network API enabled
* Client devices connected to the same local network as the host PC

## Build the Windows app

From the DuffLink root folder:

```bash
npm install
npm run build:win
```

The portable executable is created at `dist/DuffLink.exe`. It does not require an installer.

## Use the desktop host

1. Open `DuffLink.exe` on the host PC. This can be the PC running ProPresenter or another PC on the same network.
2. Enter the ProPresenter IP address and port. The host form defaults to port `1025`; use the port shown in ProPresenter's network settings if it differs.
3. Select the service date and enter up to three service start times. Empty time fields are ignored.
4. Click **Connect & Start Hosting**.
5. Open the displayed URL, such as `http://192.168.1.x:8765`, on a phone, tablet, or computer connected to the same network.

The host minimizes to the system tray and continues running. Use the tray menu to show or quit DuffLink.

## Roku

When the Roku app starts, choose one of these connection modes:

* **DuffLink host**: automatically discovers a DuffLink host on the local network. The Roku app uses the host's stage display data and listens for discovery broadcasts on UDP port `8766`.
* **Direct ProPresenter 7**: discovers ProPresenter or lets you enter its IP manually, then connects directly to its OpenAPI. The default direct connection port is `1025`.

For either Roku mode, enter service times when prompted. Use the `HH:MM` format; up to three times can be selected. To prevent the display from timing out, disable the Roku screensaver under **Settings > Theme > Screensaver > Start time > Never**.

## ProPresenter setup

In ProPresenter 7:

1. Open **Preferences > Network**.
2. Enable the network API.
3. Note the machine's IP address and API port.

DuffLink reads the active presentation, slide index, slide status, and current timers from the `/v1` API endpoints.

## Network and firewall

DuffLink serves client pages on TCP port `8765` and uses UDP port `8766` for Roku host discovery. Allow DuffLink through Windows Firewall when prompted. If clients cannot connect, allow inbound traffic on TCP `8765` and UDP `8766` for the local network.
