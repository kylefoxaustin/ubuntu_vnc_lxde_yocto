# ubuntu_vnc_lxde_yocto container

# Overview


the purpose of the script is to provide a full LXDE desktop GUI environment within the
container, accessible by your remote host system by a VNC viewer (127.0.0.1:5900)

The container serves dual purposes:
1) enable a full ubuntu 18 installation with LXDE GUI + sound so you can do anything with
   the container you would normally do with Ubuntu
2) an interactive menu that enables via terminal to install Yocto projects and i.MX BSPs

eventually the intent is to port this container to run natively on i.MX 8 or any
i.MX processor that can run docker-ce engine.  That way you can pull down this container
and use the i.MX 8 processor to drive a local screen.  In essence, it enables you to pull
the container onto i.MX 8 and run Ubuntu with just two commands (pull, then run) vs a full
native install

This container has been tested on:
 Acer Aspire E 17 laptop running Ubuntu 18
 Acer Aspire E 17 laptop running Windows 10 + VirtualBox with a Ubuntu VM (docker on VM)

 This script will also enable the user to specify a USER name and PASSWORD.
 These parameters are passed to the startup.sh by the docker run command itself, not via this script's argument processing capabilities
 that is why you see USER and PASSWORD processed below without any apparent checking for those arguments to be passed into the shell itself.
 that is all handled by docker...

 you do not have to include a USER name/Password or VNC or SSL configuration unless you so choose

# Maintainer:  kyle fox (github.com/kylefoxaustin)

# source for LXDE_VNC docker image:  https://github.com/fcwu/docker-ubuntu-vnc-desktop
 and many thanks to fcwu (aka Doro Wu), fcwu.tw@gmail.com for creating the initial
 LXDE_VNC docker image

You can use this container with the command line arguments listed below (copied from the fcwu/docker-ubuntu-vnc-desktop source readme.md)

Happy Coding

Kylef





docker-ubuntu-vnc-desktop
=========================

[![Docker Pulls](https://img.shields.io/docker/pulls/dorowu/ubuntu-desktop-lxde-vnc.svg)](https://hub.docker.com/r/dorowu/ubuntu-desktop-lxde-vnc/)
[![Docker Stars](https://img.shields.io/docker/stars/dorowu/ubuntu-desktop-lxde-vnc.svg)](https://hub.docker.com/r/dorowu/ubuntu-desktop-lxde-vnc/)

Docker image to provide HTML5 VNC interface to access Ubuntu 16.04 LXDE desktop environment.

Quick Start
-------------------------

Run the docker container and access with port `6080`

```
docker run -p 6080:80 dorowu/ubuntu-desktop-lxde-vnc
```

Browse http://127.0.0.1:6080/

<img src="https://raw.github.com/fcwu/docker-ubuntu-vnc-desktop/master/screenshots/lxde.png?v1" width=700/>

**Ubuntu Version**

Choose your favorite Ubuntu version with [tags](https://hub.docker.com/r/dorowu/ubuntu-desktop-lxde-vnc/tags/)

- bionic: Ubuntu 18.04 (latest)
- xenial: Ubuntu 16.04
- trusty: Ubuntu 14.04

VNC Viewer
------------------

Forward VNC service port 5900 to host by

```
docker run -p 6080:80 -p 5900:5900 dorowu/ubuntu-desktop-lxde-vnc
```

Now, open the vnc viewer and connect to port 5900. If you would like to protect vnc service by password, set environment variable `VNC_PASSWORD`, for example

```
docker run -p 6080:80 -p 5900:5900 -e VNC_PASSWORD=mypassword dorowu/ubuntu-desktop-lxde-vnc
```

A prompt will ask password either in the browser or vnc viewer.

HTTP Base Authentication
---------------------------

This image provides base access authentication of HTTP via `HTTP_PASSWORD`

```
docker run -p 6080:80 -e HTTP_PASSWORD=mypassword dorowu/ubuntu-desktop-lxde-vnc
```

SSL
--------------------

To connect with SSL, generate self signed SSL certificate first if you don't have it

```
mkdir -p ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ssl/nginx.key -out ssl/nginx.crt
```

Specify SSL port by `SSL_PORT`, certificate path to `/etc/nginx/ssl`, and forward it to 6081

```
docker run -p 6081:443 -e SSL_PORT=443 -v ${PWD}/ssl:/etc/nginx/ssl dorowu/ubuntu-desktop-lxde-vnc
```

Screen Resolution
------------------

The Resolution of virtual desktop adapts browser window size when first connecting the server. You may choose a fixed resolution by passing `RESOLUTION` environment variable, for example

```
docker run -p 6080:80 -e RESOLUTION=1920x1080 dorowu/ubuntu-desktop-lxde-vnc
```

Default Desktop User
--------------------

The default user is `root`. You may change the user and password respectively by `USER` and `PASSWORD` environment variable, for example,

```
docker run -p 6080:80 -e USER=doro -e PASSWORD=password dorowu/ubuntu-desktop-lxde-vnc
```

Sound (Preview version and Linux only)
-------------------

It only works in Linux. 

First of all, insert kernel module `snd-aloop` and specify `2` as the index of sound loop device

```
sudo modprobe snd-aloop index=2
```

Start the container

```
docker run -it --rm -p 6080:80 --device /dev/snd -e ALSADEV=hw:2,0 dorowu/ubuntu-desktop-lxde-vnc
```

where `--device /dev/snd -e ALSADEV=hw:2,0` means to grant sound device to container and set basic ASLA config to use card 2.

Launch a browser with URL http://127.0.0.1:6080/#/?video, where `video` means to start with video mode. Now you can start Chromium in start menu (Internet -> Chromium Web Browser Sound) and try to play some video.

Following is the screen capture of these operations. Turn on your sound at the end of video!

[![demo video](http://img.youtube.com/vi/Kv9FGClP1-k/0.jpg)](http://www.youtube.com/watch?v=Kv9FGClP1-k)


Troubleshooting and FAQ
==================

1. boot2docker connection issue, https://github.com/fcwu/docker-ubuntu-vnc-desktop/issues/2
2. Multi-language supports, https://github.com/fcwu/docker-ubuntu-vnc-desktop/issues/80


License
==================

See the LICENSE file for details.
