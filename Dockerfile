# Base image setup
FROM ubuntu:24.04 AS base

ENV LANG="C.UTF-8"

ARG UBUNTU_MIRROR

RUN { [ ! "$UBUNTU_MIRROR" ] || sed -i "s|http://\(\w*\.\)*archive\.ubuntu\.com/ubuntu/\? |$UBUNTU_MIRROR |" /etc/apt/sources.list; } && \
    apt-get -q update && \
    apt-get -q dist-upgrade -y && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get -q install --no-install-recommends -y ca-certificates git locales python3 sudo tzdata openssl && \
    touch /var/mail/ubuntu && chown ubuntu /var/mail/ubuntu && userdel -r ubuntu && \
    useradd -d /home/zulip -m zulip -u 1000

# Create self-signed SSL certificates
RUN mkdir -p /etc/ssl/private /etc/ssl/certs && \
    openssl genrsa -out /etc/ssl/private/zulip.key 2048 && \
    openssl req -new -x509 -key /etc/ssl/private/zulip.key -out /etc/ssl/certs/zulip.combined-chain.crt -days 365 \
        -subj "/C=US/ST=State/L=City/O=Organization/OU=Department/CN=ggateway.ai" && \
    chmod 600 /etc/ssl/private/zulip.key && \
    chmod 644 /etc/ssl/certs/zulip.combined-chain.crt

# Add Zulip development setup
FROM base AS build

RUN echo 'zulip ALL=(ALL:ALL) NOPASSWD:ALL' >> /etc/sudoers

USER zulip
WORKDIR /home/zulip

ARG ZULIP_GIT_URL=https://github.com/zulip/zulip.git
ARG ZULIP_GIT_REF=main

RUN git clone "$ZULIP_GIT_URL" && \
    cd zulip && \
    git checkout -b current "$ZULIP_GIT_REF"

WORKDIR /home/zulip/zulip

# Build the release tarball
RUN SKIP_VENV_SHELL_WARNING=1 ./tools/provision --build-release-tarball-only
RUN . /srv/zulip-py3-venv/bin/activate && \
    ./tools/build-release-tarball docker && \
    mv /tmp/tmp.*/zulip-server-docker.tar.gz /tmp/zulip-server-docker.tar.gz

# Build the production image
FROM base

ENV DATA_DIR="/data"

COPY --from=build /tmp/zulip-server-docker.tar.gz /root/
COPY custom_zulip_files/ /root/custom_zulip

RUN mkdir -p "$DATA_DIR" && \
    cd /root && \
    tar -xf zulip-server-docker.tar.gz && \
    rm -f zulip-server-docker.tar.gz && \
    mv zulip-server-docker zulip && \
    cp -rf /root/custom_zulip/* /root/zulip && \
    rm -rf /root/custom_zulip && \
    /root/zulip/scripts/setup/install --hostname="$(hostname)" --email="docker-zulip" \
      --puppet-classes="zulip::profile::docker" --postgresql-version=14 && \
    apt-get -qq autoremove --purge -y && \
    apt-get -qq clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY entrypoint.sh /sbin/entrypoint.sh
RUN chmod +x /sbin/entrypoint.sh

VOLUME ["$DATA_DIR"]
EXPOSE 80 443

ENTRYPOINT ["/sbin/entrypoint.sh"]
CMD ["app:run"]
