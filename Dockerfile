FROM ubuntu:22.04

ENV TZ=Europe/Lisbon \
    DEBIAN_FRONTEND=noninteractive

# Updating and installing packages
RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    tree \
    quilt \
    qemu-user \
    qemu-user-static \
    vim \
    nano \
    build-essential \
    sudo \
    locales \
    net-tools \
    iputils-ping \
    subversion \
    git \
    wget \
    curl \
    jq \
    python3 \
    python3-pip \
    python3-venv \
    python-is-python3 \
    zlib1g-dev \
    libncurses5-dev \
    libssl-dev \
    libsqlite3-dev \
    libbz2-dev \
    liblzma-dev \
    libffi-dev \
    libreadline-dev \
    libdb5.3-dev \
    libpcap-dev \
    libusb-dev \
    libc6 \
    libc6:i386 \
    gawk \
    flex \
    bison \
    diffstat \
    texinfo \
    chrpath \
    socat \
    python3-pyelftools \
    gcc \
    g++ \
    make \
    cpio \
    file \
    automake \
    autoconf \
    uuid \
    cmake \
    rsync \
    gdisk \
    unzip \
    lz4 \
    liblzo2-2 \
    liblzo2-dev \
    uuid-dev \
    libc6-dev \
    libpopt-dev \
    libtool \
    tcl \
    bc \
    python3-dev \
    python3-packaging \
    fakeroot \
    ca-certificates \
    libgssapi-krb5-2 \
    zstd && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Creating a non-root user ($whoami)
ARG UID=1000
ARG USERNAME
RUN useradd -u $UID -ms /usr/bin/bash $USERNAME && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Setting the working directory
ARG CUSTOM_PATH
WORKDIR $CUSTOM_PATH
USER $USERNAME

CMD ["sh", "-c", "sudo hostname WIZARD-DOCKER"]
CMD ["/bin/bash"]
