FROM alpine:latest

LABEL maintainer="gergely@mkoffice.hu"

ENV STRONGSWAN_LATEST https://download.strongswan.org/strongswan.tar.bz2
ENV RAW_GITHUB https://raw.githubusercontent.com

RUN  apk update && apk add --no-cache \
        curl \
        curl-dev \
        bind-tools \
        build-base \
        linux-headers \
        ca-certificates \
        openssl \
        openssl-dev \
        wget \
        ip6tables \
        iproute2 \
        iptables-dev

WORKDIR /tmp

RUN wget -q -O "strongswan.tar.bz2" ${STRONGSWAN_LATEST} && \
    mkdir -p strongswan-latest && \
    tar --strip-components=1 -xjf "strongswan.tar.bz2" -C strongswan-latest/ && \ 
    rm -f "strongswan.tar.bz2" && \
    cd strongswan-latest/ && \
    ./configure --prefix=/usr \
            --sysconfdir=/etc \
            --libexecdir=/usr/lib \
            --with-ipsecdir=/usr/lib/strongswan \
            --enable-aesni \
            --enable-chapoly \
            --enable-cmd \
            --enable-curl \
            --enable-dhcp \
            --enable-eap-dynamic \
            --enable-eap-identity \
            --enable-eap-md5 \
            --enable-eap-mschapv2 \
            --enable-eap-tls \
            --enable-farp \
            --enable-files \
            --enable-gcm \
            --enable-md4 \
            --enable-newhope \
            --enable-ntru \
            --enable-openssl \
            --enable-sha3 \
            --enable-shared \
            --disable-des \
            --disable-gmp \
            --disable-hmac \
            --disable-ikev1 \
            --disable-md5 \
            --disable-rc2 \
            --disable-static && \
    make && \
    make install && \
    mkdir -p /ipsec-init    

ADD ${RAW_GITHUB}/szecsig/docker-ipsec-vpn-server/master/entrypoint.sh /ipsec-init/
ADD ${RAW_GITHUB}/szecsig/docker-ipsec-vpn-server/master/config/ipsec.conf /ipsec-init/
ADD ${RAW_GITHUB}/szecsig/docker-ipsec-vpn-server/master/config/ipsec.secrets /ipsec-init/

RUN cd /ipsec-init && \
    chmod +x entrypoint.sh && cp ./ipsec.conf /etc/ipsec.conf && \
    cp ./ipsec.secrets /etc/ipsec.secrets


EXPOSE 500/udp 4500/udp

ENTRYPOINT ["/bin/sh", "/ipsec-init/entrypoint.sh"]
CMD ["start", "--nofork"]