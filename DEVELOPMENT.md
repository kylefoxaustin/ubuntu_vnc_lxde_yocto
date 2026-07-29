# Development

## Build and run locally

```bash
make build
make run          # http://127.0.0.1:6080/
make shell        # bash inside the running container
make stop         # remove this project's container only
```

Add `LOCALBUILD=1` to `make build` for the Taiwan apt mirror.

## Layout

```
Dockerfile              amd64 image (the one that is built and tested)
Dockerfile.armhf        32-bit ARM variant -- UNTESTED, see its header
Makefile                build / run / stop targets
cleanrun                stop + rebuild + run
image/                  files copied verbatim to / in the image
  startup.sh            ENTRYPOINT: config, Yocto menu, exec tini -- supervisord
  etc/supervisor/...    service definitions (nginx, Xvfb, LXDE, x11vnc, websockify)
  etc/nginx/...         serves the client, proxies /websockify
  usr/local/lib/web/frontend/index.html   landing page -> noVNC client
web/static/             noVNC client, served as-is (no build step)
```

## Editing the desktop / services

Everything under `image/` lands at the filesystem root, so there is no build
indirection: change `image/etc/supervisor/conf.d/supervisord.conf`, rebuild, run.

To iterate without rebuilding, bind-mount over the file and restart the service:

```bash
docker run --rm -it -p 127.0.0.1:6080:80 \
  -v ${PWD}/image/etc/supervisor/conf.d/supervisord.conf:/etc/supervisor/conf.d/supervisord.conf:ro \
  kylefoxaustin/ubuntu_vnc_lxde_yocto

# inside:
supervisorctl -c /etc/supervisor/supervisord.conf status
supervisorctl -c /etc/supervisor/supervisord.conf restart x:
```

## Editing the browser client

There is **no frontend build**. `web/static/` is copied straight into the image
and served by nginx, so editing a file there and rebuilding is the whole loop.

The previous instructions here were:

```
cd web && yarn add && BACKEND=http://127.0.0.1:6080 npm run dev
```

That no longer applies. The Vue single-page app it referred to has been removed —
it required Node 8 (EOL) and its lockfile carried 243 CVE alerts for code that
never shipped inside the image. The client is now noVNC's own static UI.

Likewise the old "develop backend" section (`supervisorctl stop web`, then
`./run.py --debug`) is gone: there is no Python backend any more. See
[SECURITY.md](SECURITY.md) for why it could not simply be upgraded.

## Verifying a change

```bash
make build && make run
```

Then check the container reports healthy and the client loads:

```bash
docker inspect --format '{{.State.Health.Status}}' ubuntu-vnc-lxde-yocto
curl -fsS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:6080/
docker exec ubuntu-vnc-lxde-yocto \
  supervisorctl -c /etc/supervisor/supervisord.conf status
```

All supervisord programs should read `RUNNING`, and the health status should
reach `healthy` within about a minute of start (`--start-period=45s`).

## Dependency alerts

There are intentionally **no dependency manifests** in this repo — no
`package.json`, no `yarn.lock`, no `requirements.txt`. `websockify` and
`supervisor` come from apt so the distro patches them. If you reintroduce a
manifest, you reintroduce the alert stream; please read
[SECURITY.md](SECURITY.md) first.
