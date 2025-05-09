################################################################################
# base system
################################################################################

FROM ubuntu:18.04 as system

ARG localbuild
RUN if [ "x$localbuild" != "x" ]; then sed -i 's#http://archive.ubuntu.com/#http://tw.archive.ubuntu.com/#' /etc/apt/sources.list; fi

# && add-apt-repository ppa:fcwu-tw/apps  x11vnc
# built-in packages
RUN apt-get update \
    && apt-get install -y --no-install-recommends software-properties-common curl apache2-utils \
    && apt-get update \
    && apt-get install -y --no-install-recommends --allow-unauthenticated \
        supervisor nginx sudo vim-tiny net-tools zenity xz-utils \
        dbus-x11 x11-utils alsa-utils \
        mesa-utils libgl1-mesa-dri \
        lxde xvfb x11vnc \
        gtk2-engines-murrine gnome-themes-standard gtk2-engines-pixbuf gtk2-engines-murrine arc-theme \
        firefox chromium-browser \
        ttf-ubuntu-font-family ttf-wqy-zenhei \
    && add-apt-repository -r ppa:fcwu-tw/apps \
    && apt-get autoclean \
    && apt-get autoremove \
    && rm -rf /var/lib/apt/lists/*
# Additional packages require ~600MB
# libreoffice  pinta language-pack-zh-hant language-pack-gnome-zh-hant firefox-locale-zh-hant libreoffice-l10n-zh-tw

# tini for subreap                                   
ARG TINI_VERSION=v0.18.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /bin/tini
RUN chmod +x /bin/tini

# ffmpeg
RUN mkdir -p /usr/local/ffmpeg \
    && curl -sSL https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-64bit-static.tar.xz | tar xJvf - -C /usr/local/ffmpeg/ --strip 1

# python library
COPY image/usr/local/lib/web/backend/requirements.txt /tmp/
RUN apt-get update \
    && dpkg-query -W -f='${Package}\n' > /tmp/a.txt \
    && apt-get install -y python-pip python-dev build-essential \
	&& pip install setuptools wheel && pip install -r /tmp/requirements.txt \
    && dpkg-query -W -f='${Package}\n' > /tmp/b.txt \
    && apt-get remove -y `diff --changed-group-format='%>' --unchanged-group-format='' /tmp/a.txt /tmp/b.txt | xargs` \
    && apt-get autoclean -y \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt/* /tmp/a.txt /tmp/b.txt

# start installing Yocto base host packages, git, tar, python
RUN apt-get update && apt-get install -y --no-install-recommends git tar python3

# now install additional yocto base host packages
RUN apt-get update && apt-get install -y --no-install-recommends gawk wget git-core diffstat unzip texinfo gpg-agent gcc-multilib \
     build-essential chrpath socat cpio python python3 python3-pip python3-pexpect \
     xz-utils debianutils iputils-ping libsdl1.2-dev xterm

RUN apt-get update

# now install from the NXP i.MX recommended yocto packages
RUN apt-get update && apt-get install -y --no-install-recommends gawk wget git-core diffstat unzip texinfo gcc-multilib \
 build-essential chrpath socat libsdl1.2-dev libsdl1.2-dev xterm sed cvs subversion coreutils texi2html \
docbook-utils python-pysqlite2 help2man make gcc g++ desktop-file-utils \
libgl1-mesa-dev libglu1-mesa-dev mercurial autoconf automake groff curl lzop asciidoc 

RUN apt-get update

# now install uboot tools from NXP i.MX recommended yocto packages
RUN apt-get update && apt-get install -y --no-install-recommends u-boot-tools

RUN apt-get update

# now install emacs
RUN apt-get update && apt-get install -y --no-install-recommends emacs

RUN apt-get update


################################################################################
# builder
################################################################################
FROM ubuntu:16.04 as builder

ARG localbuild
RUN if [ "x$localbuild" != "x" ]; then sed -i 's#http://archive.ubuntu.com/#http://tw.archive.ubuntu.com/#' /etc/apt/sources.list; fi

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates

# nodejs
RUN curl -sL https://deb.nodesource.com/setup_8.x | bash - \
    && apt-get install -y nodejs

# yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && apt-get update \
    && apt-get install -y yarn

# build frontend
COPY web /src/web
RUN cd /src/web \
    && yarn \
    && npm run build

################################################################################
# merge
################################################################################
FROM system
LABEL maintainer="kylefoxaustin"

COPY --from=builder /src/web/dist/ /usr/local/lib/web/frontend/
COPY image /

EXPOSE 80
WORKDIR /root 
ENV TERM=xterm
ENV HOME=/root/ \
    SHELL=/bin/bash
HEALTHCHECK --interval=30s --timeout=5s CMD curl --fail http://127.0.0.1:/6079/api/health
ENTRYPOINT ["/startup.sh"]
