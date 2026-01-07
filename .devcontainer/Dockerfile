ARG ALPINE_TAG=3.21.3

FROM alpine:${ALPINE_TAG}

WORKDIR /opt/vlang

ENV PATH=/opt/vlang:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN apk --no-cache add \
	musl-dev libc-dev libc6-compat gcompat \
	openssl-dev sqlite-dev mbedtls \
	libuv-dev libev-dev libevent-dev libmemcached-dev \
	binutils diffutils elfutils pcre strace rsync \
	libunwind-dev libunwind-static gc gc-dev \
	make bash file git upx tmux micro nano nano-syntax \
	gcc gdb wasi-sdk \
	mesa-dev mesa-gl mesa-gles mesa-glapi \
	glfw-dev \
	glu-dev \
	glew-dev \
	freetype-dev \
	freeglut-dev \
	libxi-dev libxi-static \
	libxcursor-dev \
	libx11-dev \
	icu-data-full \
	sdl2_net-dev \
	sdl2_gfx-dev \
	sdl2_ttf-dev \
	sdl2_image-dev \  
	sdl2_mixer-dev \
	sdl2_pango-dev \
	sdl2-dev

RUN ln -s /opt/vlang/v /usr/local/bin/v

ARG V_RELEASE_TAG=0.4.9

RUN git clone --depth=1 --quiet https://github.com/vlang/v/ /opt/vlang && \
	rm -rf /vlang-local

RUN mkdir -p /tmp/v /tmp/v /home/ && chown -Rh 1000:1000 /opt/ /tmp/ /home/

USER 1000:1000
ENV HOME=/home
ENV VTMP=/tmp/v
ENV VMODULES=/tmp/vmodules

RUN make && v -version && ls -la v && \
	du -b -s . && \
	time v doctor && \
	time v cmd/tools/vfmt.v && \
	time v -prod self && \
	true

RUN find . -type f -name *_test.v -or -name *.vv -or -name *.out | xargs rm && \
	rm -rf v_old vc/ .git/ && \
	du -b -s .

CMD ["v"]