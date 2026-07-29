################################################################################
# ubuntu_vnc_lxde_yocto
#
# An Ubuntu 18.04 LXDE desktop, reachable from a browser (noVNC) or a VNC
# viewer, preloaded with the host packages needed to build Yocto / NXP i.MX
# BSPs.
#
# The base is deliberately still ubuntu:18.04: the Yocto host-package set this
# image exists to provide is the one that release shipped. 18.04 is past its
# standard support window -- see SECURITY.md for what that costs and what to do
# about it.
#
# Maintainer: kylefoxaustin (github.com/kylefoxaustin)
# Derived from https://github.com/fcwu/docker-ubuntu-vnc-desktop by
# Doro Wu (fcwu.tw@gmail.com) -- thank you.
################################################################################

FROM ubuntu:18.04
LABEL maintainer="kylefoxaustin"

# ARG rather than ENV: keeps noninteractive out of the running container's env.
ARG DEBIAN_FRONTEND=noninteractive

# Optional closer mirror for local builds (make build passes this).
ARG localbuild
RUN if [ -n "$localbuild" ]; then \
        sed -i 's#http://archive.ubuntu.com/#http://tw.archive.ubuntu.com/#' /etc/apt/sources.list; \
    fi

################################################################################
# Desktop, VNC and web stack.
#
# One apt layer. The previous Dockerfile ran `apt-get update` five separate
# times and installed build-essential/gcc-multilib three times over.
#
# websockify comes from apt instead of the vendored copy under web/static, so it
# gets distro security updates and contributes no dependency manifest. Same for
# supervisor, which used to be pip-installed at a pinned 3.2.0 on top of the
# apt one.
#
# --allow-unauthenticated has been REMOVED: it disabled package signature
# verification for everything installed here.
################################################################################
RUN apt-get update && apt-get install -y --no-install-recommends \
        supervisor nginx sudo net-tools ca-certificates curl apache2-utils \
        vim-tiny zenity xz-utils \
        dbus-x11 x11-utils alsa-utils \
        mesa-utils libgl1-mesa-dri \
        lxde xvfb x11vnc websockify \
        gtk2-engines-murrine gtk2-engines-pixbuf gnome-themes-standard arc-theme \
        firefox chromium-browser \
        fonts-ubuntu ttf-wqy-zenhei \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

################################################################################
# Yocto / NXP i.MX host packages.
#
# The union of the four overlapping lists the previous Dockerfile spread across
# five layers, deduplicated. Sources: the Yocto Project quick-start host
# requirements and NXP's i.MX Yocto user guide.
################################################################################
RUN apt-get update && apt-get install -y --no-install-recommends \
        asciidoc autoconf automake build-essential chrpath coreutils cpio cvs \
        debianutils desktop-file-utils diffstat docbook-utils emacs g++ gawk \
        gcc gcc-multilib git git-core gpg-agent groff help2man iputils-ping \
        libgl1-mesa-dev libglu1-mesa-dev libsdl1.2-dev lzop make mercurial \
        python python-pysqlite2 python3 python3-pexpect python3-pip sed socat \
        subversion tar texi2html texinfo u-boot-tools unzip wget xterm \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

################################################################################
# tini, for PID-1 signal handling and zombie reaping (startup.sh execs it).
#
# Pinned AND CHECKSUM VERIFIED. The previous version used a bare
# `ADD https://github.com/.../tini /bin/tini`, which trusts whatever bytes that
# URL serves at build time with no integrity check whatsoever.
################################################################################
ARG TINI_VERSION=v0.19.0
ARG TINI_SHA256=93dcc18adc78c65a028a84799ecf8ad40c936fdfc5f2a57b1acda5a8117fa82c
RUN curl -fsSLo /bin/tini \
        "https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini" \
    && echo "${TINI_SHA256}  /bin/tini" | sha256sum -c - \
    && chmod +x /bin/tini

################################################################################
# Web assets.
#
# The browser client is noVNC, served as static files by nginx -- no build step.
# The old multi-stage builder installed Node 8 (EOL) and yarn via `curl | bash`
# plus the deprecated `apt-key add`, purely to compile a Vue wrapper whose
# lockfile carried 243 of this repo's 287 Dependabot alerts -- none of which
# ever shipped inside the image.
################################################################################
COPY web/static/ /usr/local/lib/web/frontend/static/
COPY image/ /

# COPY preserves the source mode, and these scripts were committed 100644 in
# every revision of this repo. An exec-form ENTRYPOINT on a non-executable file
# fails with "permission denied", and supervisord could not launch xvfb.sh
# either -- so the image as previously committed could not start at all. The git
# modes are fixed too; this is belt-and-braces for clones that lose the bit
# (Windows, zip downloads, some CI checkouts).
RUN chmod +x /startup.sh /usr/local/bin/xvfb.sh /usr/local/bin/chromium-browser-sound.sh

# 80   nginx -> noVNC client + /websockify
# 5900 x11vnc, for a native VNC viewer. Publishing this exposes the desktop;
#      set VNC_PASSWORD if you do. See SECURITY.md.
EXPOSE 80 5900

WORKDIR /root
ENV TERM=xterm \
    HOME=/root \
    SHELL=/bin/bash

# Was: curl --fail http://127.0.0.1:/6079/api/health
# The colon was misplaced, so the port was empty and the check could never pass.
# (Dockerfile.amd64 carried the corrected URL; the file `make build` actually
# used did not.) There is no /api backend now, so check the thing that matters:
# nginx serving the client. start-period covers desktop start-up.
HEALTHCHECK --interval=30s --timeout=5s --start-period=45s --retries=3 \
    CMD curl -fsS http://127.0.0.1/ >/dev/null || exit 1

# startup.sh execs `tini -- supervisord` itself, so tini is not repeated here.
ENTRYPOINT ["/startup.sh"]
