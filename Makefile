.PHONY: build run run-vnc shell stop clean gen-ssl help

# Was: kylefoxaustin/imx8_yocto_build_container_ubuntu_lxde_vnc -- a third name,
# matching neither this repo nor the README (which pointed at upstream's image).
REPO ?= kylefoxaustin/ubuntu_vnc_lxde_yocto
TAG  ?= latest
NAME ?= ubuntu-vnc-lxde-yocto

# Host port for the browser client.
WEB_PORT ?= 6080

help:
	@echo "make build     build $(REPO):$(TAG)"
	@echo "make run       run it; browser client on http://127.0.0.1:$(WEB_PORT)/"
	@echo "make run-vnc   as above, plus a native VNC port (requires VNC_PASSWORD)"
	@echo "make shell     bash inside the running container"
	@echo "make stop      stop and remove THIS project's container only"
	@echo "make clean     stop, then remove the built image"
	@echo "make gen-ssl   generate a self-signed cert into ./ssl"

# localbuild=1 switches apt to a Taiwan mirror (inherited from upstream, whose
# author is based there). The old `build` target passed it unconditionally, which
# meant every user everywhere fetched ~600 packages from tw.archive.ubuntu.com.
# Now opt-in: make build LOCALBUILD=1
build:
	docker build -t $(REPO):$(TAG) $(if $(LOCALBUILD),--build-arg localbuild=1,) .

# Ports are bound to 127.0.0.1 on purpose. `-p 6080:80` binds 0.0.0.0, which
# publishes an unauthenticated desktop to every host on your network; the old
# default did exactly that with 5900. Set HTTP_PASSWORD and change the bind
# address deliberately if you actually want it reachable.
run:
	docker run --rm -it \
		-p 127.0.0.1:$(WEB_PORT):80 \
		--name $(NAME) \
		$(REPO):$(TAG)

# Native VNC viewer access. VNC_PASSWORD is required rather than optional here:
# x11vnc runs with -forever -shared and no password unless one is supplied.
run-vnc:
	@if [ -z "$(VNC_PASSWORD)" ]; then \
		echo "refusing to publish 5900 without a password."; \
		echo "usage: make run-vnc VNC_PASSWORD=something"; \
		exit 1; \
	fi
	docker run --rm -it \
		-p 127.0.0.1:$(WEB_PORT):80 \
		-p 127.0.0.1:5900:5900 \
		-e VNC_PASSWORD=$(VNC_PASSWORD) \
		--name $(NAME) \
		$(REPO):$(TAG)

shell:
	docker exec -it $(NAME) bash

# Scoped to this project's container. `cleanrun` used to run
# `docker rm $(docker ps -aq)`, which removes every container on the host.
stop:
	-docker stop $(NAME)
	-docker rm $(NAME)

clean: stop
	-docker rmi $(REPO):$(TAG)

gen-ssl:
	mkdir -p ssl
	openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
		-keyout ssl/nginx.key -out ssl/nginx.crt
