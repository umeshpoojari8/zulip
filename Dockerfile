# Use an official Ubuntu base image
FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV ZULIP_PATH /home/zulip

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-dev \
    python3-venv \
    build-essential \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    wget \
    curl \
    llvm \
    libncurses5-dev \
    libncursesw5-dev \
    xz-utils \
    tk-dev \
    libffi-dev \
    liblzma-dev \
    nodejs \
    npm \
    postgresql \
    redis-server \
    memcached \
    supervisor \
    apt-transport-https \
    ca-certificates \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Install Yarn globally
RUN npm install -g yarn

# Create Zulip directory
RUN useradd -ms /bin/bash zulip && mkdir -p ${ZULIP_PATH}
WORKDIR ${ZULIP_PATH}

# Copy Zulip source code into the image
COPY . ${ZULIP_PATH}

# Install Python and Node.js dependencies
RUN pip3 install --upgrade pip setuptools wheel \
    && pip3 install -r requirements/dev.txt \
    && yarn install \
    && tools/provision

# Expose the Zulip development server ports
EXPOSE 9991

# Start the development server
CMD ["/bin/bash", "-c", "scripts/run-dev.py"]
