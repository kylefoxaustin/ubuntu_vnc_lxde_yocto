# Security notes

This is a **development convenience container**: a full LXDE desktop plus a Yocto
build toolchain, reachable over VNC and HTTP. It is not hardened, and some of
what follows is inherent to what it does rather than fixable.

Read this before you publish any of its ports anywhere but `127.0.0.1`.

---

## Known, accepted, and not fixed

### The base image is Ubuntu 18.04, which is past standard support

18.04 left standard support in **May 2023**. Its archives still serve packages
(verified 2026-07), but they no longer receive general security updates outside
Ubuntu Pro/ESM. So the OS packages in this image carry unpatched CVEs, and no
amount of dependency tidying changes that.

It is deliberate. The reason this container exists is the *specific* Yocto and
NXP i.MX host-package set that 18.04 shipped, which is what the BSPs of that era
expect. Bumping the base is not a one-line change:

- `chromium-browser` becomes a **snap transitional package** from 20.04 onward,
  and snaps do not work in a plain container — it needs replacing outright.
- `python-pysqlite2`, `ttf-*` font packages and several others were renamed or
  dropped.
- The Yocto host requirements differ per release, so the package list has to be
  re-derived against whichever BSP you actually target.

**If you want a supported base, that is a port, not an upgrade.** Start from the
Yocto host-requirements page for your target release.

### There is no authentication unless you ask for it

Both entry points are wide open by default:

| Port | Service | Default |
|------|---------|---------|
| 80 | nginx → noVNC client | **no auth** unless `HTTP_PASSWORD` is set |
| 5900 | x11vnc (`-forever -shared`) | **no auth** unless `VNC_PASSWORD` is set |

`startup.sh` now prints a warning to stderr on startup for each one that is
unset, and `make run` binds only to `127.0.0.1`. Anyone who can reach an
unauthenticated port gets a full desktop session with a root shell in it.

```bash
# both, please, if this is reachable by anything but your own loopback
docker run -e HTTP_PASSWORD=... -e VNC_PASSWORD=... ...
```

### Everything runs as root

`USER` defaults to `root`, `sudo` is installed, and supervisord runs the desktop
as that user. Passing `-e USER=youruser -e PASSWORD=...` creates an unprivileged
account and runs the desktop panel/file manager as it, but supervisord itself
still runs as root.

### Chromium runs with `--no-sandbox`

`/usr/local/bin/chromium-browser-sound.sh` passes `--no-sandbox`, which disables
Chromium's renderer sandbox. It is there because the sandbox needs kernel
privileges the container does not have by default. The alternative is running the
container with a suitable seccomp profile and `--cap-add SYS_ADMIN`, which is its
own tradeoff. **Do not browse untrusted sites in this container.**

---

## Fixed in the 2026 cleanup

| Was | Now |
|-----|-----|
| `apt-get install --allow-unauthenticated` — package signature verification **disabled** | removed; signatures enforced |
| `ADD https://github.com/.../tini /bin/tini` — remote binary, **no integrity check** | `curl` + pinned `v0.19.0` + `sha256sum -c` |
| `curl -sL https://deb.nodesource.com/setup_8.x \| bash -` — pipe-to-shell, EOL Node | builder stage removed entirely |
| `apt-key add` — deprecated, trusts the key for *all* repos | removed with the builder stage |
| `curl … johnvansickle.com/ffmpeg/… \| tar xJ` — third-party tarball, no checksum (**and a dead URL: 404**) | removed with the video feature |
| VNC password written in **plaintext** to `/.password1` and left on disk | passed to `x11vnc -storepasswd` directly; only the hash persists; any stale file removed |
| `docker rm $(docker ps -aq)` in `cleanrun` — **deleted every container on the host** | scoped to this project's container |
| `-p 5900:5900` in `make run` — unauthenticated desktop on **all interfaces** | `127.0.0.1` only, and `make run-vnc` refuses to start without a password |
| `.dockerignore` listed only `web/node_modules`, so `.git` went into the build context | excludes VCS, docs, editor and Python artefacts |
| Python 2 Flask/gevent backend, 40 CVE alerts, unupgradable (see below) | removed |
| Node 8 + Vue toolchain, 243 CVE alerts | removed |

### Why the Python backend was deleted rather than upgraded

The Flask/gevent API server carried all 40 of the repo's runtime dependency
alerts, including a critical gevent privilege-escalation issue. Those pins could
not simply be raised:

**Ubuntu 18.04 ships Python 3.6.** Modern Flask (3.x), Werkzeug (3.x) and
gevent (23.9+) all require **Python ≥ 3.8**. The patched versions were therefore
unreachable without changing the base image — the port described above.

Its only consumer was the Vue frontend, which was already being removed, so the
backend went with it. The features that went too: `/api/state`, `/api/reset`
(dynamic resolution changes via HTTP) and `/api/live.flv` (the FLV video/audio
stream). Plain VNC — the thing the container is for — is unaffected.

`websockify` and `supervisor` now come from **apt** rather than pip/vendored
copies, so they receive distro updates and contribute no dependency manifest.

---

## Reporting

This is an unmaintained hobby project. If you find something, open an issue —
but please do not expect a patched release.
