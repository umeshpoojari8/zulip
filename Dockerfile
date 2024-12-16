# Stage 1: Base image setup
# This base image is shared between the build and production stages
FROM ubuntu:24.04 AS base

# Set the locale for consistent UTF-8 encoding
ENV LANG="C.UTF-8"

# Argument to allow specifying a custom Ubuntu package mirror
ARG UBUNTU_MIRROR

# Update the base system, install necessary dependencies, and create the zulip user
RUN { [ ! "$UBUNTU_MIRROR" ] || sed -i "s|http://\(\w*\.\)*archive\.ubuntu\.com/ubuntu/\? |$UBUNTU_MIRROR |" /etc/apt/sources.list; } && \
    apt-get -q update && \
    apt-get -q dist-upgrade -y && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get -q install --no-install-recommends -y ca-certificates git locales python3 sudo tzdata && \
    touch /var/mail/ubuntu && chown ubuntu /var/mail/ubuntu && userdel -r ubuntu && \
    useradd -d /home/zulip -m zulip -u 1000

# Stage 2: Build stage for generating the Zulip release tarball
FROM base AS build

# Allow the zulip user to use sudo without a password
RUN echo 'zulip ALL=(ALL:ALL) NOPASSWD:ALL' >> /etc/sudoers

# Ensure zulip user has ownership of the necessary directories
USER root
RUN mkdir -p /home/zulip/zulip/help-beta && \
    chown -R zulip:zulip /home/zulip && \
    chown -R zulip:zulip /home/zulip/zulip/help-beta && \
    chown -R zulip:zulip /home/zulip/zulip/var

# Switch to the zulip user and set the working directory
USER zulip
WORKDIR /home/zulip

# Copy the local Zulip source code into the container
# Assumes the zulip codebase is in a directory named "zulip" relative to the Dockerfile
COPY ./ /home/zulip/zulip

# Set the working directory to the Zulip codebase
WORKDIR /home/zulip/zulip

# # Argument for specifying a branch, tag, or commit of the Zulip codebase (optional)
# ARG ZULIP_GIT_REF=9.3

# # Optional: Checkout the specified branch/tag if .git exists
# RUN if [ -d ".git" ]; then git checkout -b current "$ZULIP_GIT_REF"; fi

# Run provisioning and build the release tarball
RUN SKIP_VENV_SHELL_WARNING=1 ./tools/provision --build-release-tarball-only && \
    . /srv/zulip-py3-venv/bin/activate && \
    ./tools/build-release-tarball docker && \
    mv /tmp/tmp.*/zulip-server-docker.tar.gz /tmp/zulip-server-docker.tar.gz

# Stage 3: Production image setup
FROM base

# Define the directory where Zulip data will be stored
ENV DATA_DIR="/data"

# Copy the release tarball from the build stage
COPY --from=build /tmp/zulip-server-docker.tar.gz /root/

# Copy any custom configuration files (if needed)
# Replace this directory with your own customizations
COPY custom_zulip_files/ /root/custom_zulip

# Argument for specifying custom CA certificates (optional)
ARG CUSTOM_CA_CERTIFICATES

# Extract the release tarball, install Zulip, and clean up unnecessary files
RUN \
    # Disable Nginx startup to ensure Supervisor starts it instead
    dpkg-divert --add --rename /etc/init.d/nginx && \
    ln -s /bin/true /etc/init.d/nginx && \
    # Create the data directory for Zulip
    mkdir -p "$DATA_DIR" && \
    # Extract the Zulip server tarball
    cd /root && \
    tar -xf zulip-server-docker.tar.gz && \
    rm -f zulip-server-docker.tar.gz && \
    mv zulip-server-docker zulip && \
    # Apply custom configurations if provided
    cp -rf /root/custom_zulip/* /root/zulip && \
    rm -rf /root/custom_zulip && \
    # Run the Zulip installation script
    /root/zulip/scripts/setup/install --hostname="$(hostname)" --email="docker-zulip" \
      --puppet-classes="zulip::profile::docker" --postgresql-version=14 && \
    # Clean up unnecessary files and temporary directories
    rm -f /etc/zulip/zulip-secrets.conf /etc/zulip/settings.py && \
    apt-get -qq autoremove --purge -y && \
    apt-get -qq clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy the entrypoint script and certbot deploy hook into the image
COPY entrypoint.sh /sbin/entrypoint.sh
COPY certbot-deploy-hook /sbin/certbot-deploy-hook

# Expose the ports for HTTP (80) and HTTPS (443)
EXPOSE 80 443

# Define the default volume for data persistence
VOLUME ["$DATA_DIR"]

# Set the default entrypoint and command for the container
ENTRYPOINT ["/sbin/entrypoint.sh"]
CMD ["app:run"]
