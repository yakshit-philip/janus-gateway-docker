############################################################
# Dockerfile - Janus Gateway on Debian Buster
# https://github.com/minelytics/janus-gateway-docker
############################################################

FROM buildpack-deps:buster
MAINTAINER Maanas Royy <m4manas@gmail.com>
RUN apt-get update -y && apt-get upgrade -y
RUN mkdir /build

# libnice
WORKDIR /build
RUN apt-get remove -y libnice-dev libnice10
RUN apt-get  update && \
    apt-get install -y gtk-doc-tools libgnutls28-dev
RUN git clone https://gitlab.freedesktop.org/libnice/libnice
WORKDIR libnice
RUN ./autogen.sh
RUN ./configure --prefix=/usr
RUN make && make install

# libsrtp
WORKDIR /build
RUN apt-get remove -y libsrtp0-dev 
RUN wget https://github.com/cisco/libsrtp/archive/v2.3.0.tar.gz 
RUN tar xfv v2.3.0.tar.gz
WORKDIR libsrtp-2.3.0
RUN ./configure --prefix=/usr --enable-openssl
RUN make shared_library && make install

# boringssl
WORKDIR /build
RUN apt-get  update && \
    apt-get install -y cmake libunwind-dev golang
RUN git clone https://boringssl.googlesource.com/boringssl
WORKDIR boringssl
RUN sed -i s/" -Werror"//g CMakeLists.txt
RUN mkdir -p build
WORKDIR build
RUN cmake -DCMAKE_CXX_FLAGS="-lrt" ..
RUN make
WORKDIR ..
RUN mkdir -p /opt/boringssl/lib
RUN cp -R include /opt/boringssl/  && \
	cp build/ssl/libssl.a /opt/boringssl/lib/  && \
	cp build/crypto/libcrypto.a /opt/boringssl/lib/

# data channel
WORKDIR /build
RUN git clone https://github.com/sctplab/usrsctp
WORKDIR usrsctp
RUN ./bootstrap
RUN ./configure --prefix=/usr 
RUN make && make install

# websocket
WORKDIR /build
RUN git clone https://github.com/warmcat/libwebsockets.git
WORKDIR libwebsockets
RUN git checkout v3.2-stable
RUN mkdir build
WORKDIR build
# See https://github.com/meetecho/janus-gateway/issues/732 re: LWS_MAX_SMP
RUN cmake -DLWS_MAX_SMP=1 -DCMAKE_INSTALL_PREFIX:PATH=/usr -DCMAKE_C_FLAGS="-fpic" ..
RUN make && make install


# janus
WORKDIR /build
RUN apt-get update -y && apt-get install -y libmicrohttpd-dev \
	libjansson-dev \
    libsofia-sip-ua-dev \
    libglib2.0-dev \
    libopus-dev \
    libogg-dev \
    libcurl4-openssl-dev \
    liblua5.3-dev \
    libini-config-dev \
    libcollection-dev \
    libconfig-dev \
    libavformat-dev \
    libavcodec-dev \
    libavutil-dev \
    pkg-config\
    gengetopt \
    libtool \
    automake \
    cmake \
    ca-certificates

RUN git clone https://github.com/meetecho/janus-gateway.git
WORKDIR janus-gateway
RUN sh autogen.sh
RUN ./configure --prefix=/opt/janus \
	--enable-post-processing \
    --enable-boringssl \
    --enable-data-channels \
    --disable-rabbitmq \
    --disable-mqtt \
    --disable-unix-sockets \
    --enable-dtls-settimeout \
    --enable-plugin-echotest \
    --enable-plugin-recordplay \
    --enable-plugin-sip \
    --enable-plugin-videocall \
    --enable-plugin-voicemail \
    --enable-plugin-textroom \
    --enable-plugin-audiobridge \
    --enable-plugin-nosip \
    --enable-all-handlers && \
    make && make install && make configs && ldconfig


# FROM debian:buster-slim
# COPY --from=0 /opt/janus /opt/janus
# COPY --from=0 /opt/boringssl /opt/boringssl

WORKDIR /opt/janus
ENTRYPOINT ["/opt/janus/bin/janus"]
