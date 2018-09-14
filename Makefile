.PHONY: build run

REPO  ?= kylefoxaustin/imx8_yocto_build_container_ubuntu_lxde_vnc
TAG   ?= latest

build:
	docker build -t $(REPO):$(TAG) --build-arg localbuild=1 .

run:
	docker run --rm \
		-p 6080:80 -p 6081:443 \
		-p 5900:5900 \
		-v ${PWD}:/src:ro \
		-e USER=kyle -e PASSWORD=mypassword \
		-e ALSADEV=hw:2,0 \
		-e SSL_PORT=443 \
		-v ${PWD}/ssl:/etc/nginx/ssl \
		--device /dev/snd \
		--name imx8-yocto-build-test \
		$(REPO):$(TAG)

shell:
	docker exec -it imx8-yocto-build-test bash

gen-ssl:
	mkdir -p ssl
	openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
		-keyout ssl/nginx.key -out ssl/nginx.crt
