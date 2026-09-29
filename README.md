# Brave + PCManFM RDP for Railway

A deliberately small Linux graphical environment for **Windows Remote Desktop (RDP)**. It uses:

- Debian 13 (trixie)
- `xrdp` + `xorgxrdp`
- Openbox as the window manager
- PCManFM as the lightweight file manager
- Brave Browser from Brave's official Debian repository
- Software rendering through Mesa/llvmpipe
- A Railway Volume mounted at `/data` for persistent personal data

There is no GNOME, KDE, XFCE, Cinnamon, display manager, or other full desktop environment.

## What persists

Mount the Railway Volume at exactly `/data`.

The container keeps the graphical user's home at:

`/data/home/rdp`

This means the following survive container restarts and redeployments:

- Brave profile, bookmarks, cookies, extensions, settings, sessions
- `Downloads`
- PCManFM configuration
- Openbox configuration
- other files placed under the user's persistent home
- diagnostics under `/data/logs`

Brave's temporary cache is intentionally kept in the container's `/tmp` rather than making every cache write persistent. This reduces volume I/O while keeping the actual browser profile persistent.

Railway volumes are mounted at runtime and persist across restarts/deployments. Do not expect `/data` to exist during Docker build; this image creates its persistent directories when the container starts.

## Deploy on Railway

1. Put this repository on GitHub.
2. In Railway, create a project and deploy this GitHub repository as a service.
3. Add a Railway **Volume** to that service.
4. Set its mount path to:

   `/data`

5. Add this environment variable:

   `RDP_PASSWORD=<a strong password>`

6. Deploy/redeploy the service.
7. In the service's **Settings → Networking → TCP Proxy**, create a TCP proxy for internal port **3389**.
8. Railway will provide a proxy hostname and an external TCP port.
9. On Windows, open **Remote Desktop Connection** (`mstsc.exe`) and connect to:

   `<Railway TCP proxy domain>:<Railway TCP proxy port>`

10. Log in as:

   `rdp`

   Use the value of `RDP_PASSWORD` as the password.

Railway's TCP proxy is intentionally used instead of an HTTP domain because RDP is a raw TCP protocol.

### Important Railway networking detail

Do **not** expect the public port to be 3389. Railway's TCP Proxy normally gives you a generated public port. The container itself listens on 3389, and Railway forwards the generated external TCP port to it.

### Important Railway volume detail

The volume must be mounted at `/data`. The image is specifically designed around that path.

## Local testing

Docker Compose is included for local testing.

```bash
docker compose up --build
```

Then connect with Windows Remote Desktop to:

`localhost:3389`

The local test data is stored in `./data`.

The Compose file gives the container a larger shared-memory area (`1g`) than Docker's common default. This is helpful for Chromium-heavy testing.

## First login

After a successful RDP login, Openbox starts with:

- Brave
- PCManFM

There is intentionally no taskbar-heavy desktop shell.

PCManFM can browse `/data`, and the home directory's `Downloads` folder points to `/data/Downloads`.

Brave's normal file chooser works through the X11 desktop session, so uploads and downloads can use the persistent storage.

## Brave stability choices

The launcher intentionally does **not** use `--no-sandbox`.

The graphical user is non-root, so Chromium's sandbox remains enabled.

The launcher disables GPU acceleration and forces software-oriented Mesa settings because Railway may not provide a usable physical GPU. It also uses X11 explicitly and disables `/dev/shm` dependence with:

`--disable-dev-shm-usage`

These choices are intended to avoid common Chromium/Xorg problems such as GPU initialization failures, OpenGL driver crashes, and container shared-memory exhaustion.

Brave is still normal multi-process Brave. There is no single-tab or single-window restriction. Multiple windows, tabs, extensions, downloads, JavaScript-heavy sites, and ordinary browser features remain available.

## Resource expectations

This is lightweight at the desktop level, but Brave itself can use substantial RAM with many tabs and extensions. Do not interpret "lightweight" as a guarantee of low Brave memory usage.

For practical stability, give the Railway service enough memory for the number of tabs you intend to keep open. Browser crashes caused by an out-of-memory condition cannot be fixed by changing the window manager.

## Logs and diagnostics

Persistent logs are in:

`/data/logs/`

Useful files include:

- `startup.log` - container startup and RDP service lifecycle
- `xrdp.log` - xrdp server
- `xrdp-sesman.log` - session manager
- `xrdp-internal.log` - xrdp's own configured log
- `xrdp-sesman-internal.log` - session manager's own log
- `session.log` - XRDP graphical session/Openbox startup
- `brave.log` - Brave launch output
- `pcmanfm.log` - file manager output
- `graphics.log` - Mesa/OpenGL diagnostics
- `dbus.log` - D-Bus startup diagnostics

Railway also captures the main xrdp/session output in the service logs.

## Recovery behavior

- Closing or crashing Brave does not end the RDP session.
- Openbox is supervised by the session startup script and is restarted if it unexpectedly exits.
- The RDP server is independent of Brave and Openbox.
- Brave is started once per graphical session, so the setup does not contain a blind infinite Brave restart loop.
- The container exits if an essential RDP daemon dies, allowing Railway's deployment restart policy to recover the service.
- The user's profile is not recreated on every startup, avoiding accidental deletion or reset of browser data.

## Security notes

The only application port exposed by this image is TCP 3389 for RDP.

The graphical account is the non-root `rdp` user.

The RDP password is supplied through `RDP_PASSWORD` and is not stored in the repository.

RDP itself is exposed to the public internet when you create a Railway TCP Proxy. Use a strong, unique password and keep the container updated by rebuilding it periodically.

Do not put secrets, passwords, or cookies into Git.

## Backups

A Railway Volume protects data from normal container restarts/redeployments, but it is not a substitute for backups.

Back up `/data`, especially the Brave profile, if the browser contains important sessions or files.

## Architecture

```text
Windows mstsc.exe
        |
        | RDP over TCP
        v
Railway TCP Proxy
        |
        v
container:3389
        |
        +--> xrdp
              |
              +--> xrdp-sesman
                    |
                    +--> Xorg/xorgxrdp
                          |
                          +--> Openbox
                                |
                                +--> Brave
                                |
                                +--> PCManFM
        |
        +--> /data  <-- Railway persistent Volume
```

## Notes

This image intentionally avoids a systemd dependency. Railway containers normally run one foreground process, so the startup script launches the required xrdp daemons directly and keeps the container alive while surfacing their logs.

The image also does not use a Docker `VOLUME` instruction. Persistence is provided by Railway's runtime Volume mounted at `/data`.
