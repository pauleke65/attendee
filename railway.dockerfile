FROM --platform=linux/amd64 ubuntu:22.04 AS base

SHELL ["/bin/bash", "-c"]

ENV project=attendee
ENV cwd=/$project

WORKDIR $cwd

ARG DEBIAN_FRONTEND=noninteractive

# Install Dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    gdb \
    git \
    gfortran \
    libopencv-dev \
    libdbus-1-3 \
    libgbm1 \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libglib2.0-dev \
    libssl-dev \
    libx11-dev \
    libx11-xcb1 \
    libxcb-image0 \
    libxcb-keysyms1 \
    libxcb-randr0 \
    libxcb-shape0 \
    libxcb-shm0 \
    libxcb-xfixes0 \
    libxcb-xtest0 \
    libgl1-mesa-dri \
    libxfixes3 \
    linux-libc-dev \
    pkgconf \
    python3-pip \
    tar \
    unzip \
    zip \
    vim \
    libpq-dev \
    xvfb \
    x11-xkb-utils \
    xfonts-100dpi \
    xfonts-75dpi \
    xfonts-scalable \
    xfonts-cyrillic \
    x11-apps \
    libvulkan1 \
    fonts-liberation \
    xdg-utils \
    wget \
    libasound2 \
    libasound2-plugins \
    alsa \
    alsa-utils \
    alsa-oss \
    pulseaudio \
    pulseaudio-utils \
    ffmpeg \
    universal-ctags \
    gstreamer1.0-tools \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    libgirepository1.0-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Chrome
RUN wget -q http://dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-stable/google-chrome-stable_134.0.6998.88-1_amd64.deb \
    && apt-get update \
    && apt-get install -y ./google-chrome-stable_134.0.6998.88-1_amd64.deb \
    && rm google-chrome-stable_134.0.6998.88-1_amd64.deb

# Alias python3 to python
RUN ln -s /usr/bin/python3 /usr/bin/python

# Install Python dependencies early
RUN pip install pyjwt cython gdown deepgram-sdk python-dotenv

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install -r requirements.txt

# Install tini
ENV TINI_VERSION=v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini

# Copy application code
COPY . .

# Create and setup entrypoint
COPY entrypoint.sh /opt/bin/entrypoint.sh
RUN chmod +x /opt/bin/entrypoint.sh

# Add root to pulse-access group
RUN adduser root pulse-access

# Generate environment variables for production
RUN python init_env.py > .env.template

# Set up proper permissions
RUN chmod +x /opt/bin/entrypoint.sh

# Expose port
EXPOSE 8000

# Use tini as entrypoint and start the application
ENTRYPOINT ["/tini", "--"]
CMD ["/bin/bash", "-c", "/opt/bin/entrypoint.sh && python manage.py migrate && gunicorn attendee.wsgi:application --bind 0.0.0.0:8000 --workers 2"]