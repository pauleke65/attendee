FROM --platform=linux/amd64 ubuntu:22.04 AS base

SHELL ["/bin/bash", "-c"]

ENV project=attendee
ENV cwd=/$project

WORKDIR $cwd

ARG DEBIAN_FRONTEND=noninteractive

# Install minimal dependencies for web service only
RUN apt-get update && apt-get install -y \
    build-essential \
    ca-certificates \
    python3-pip \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Alias python3 to python
RUN ln -s /usr/bin/python3 /usr/bin/python

# Install basic Python dependencies
RUN pip install pyjwt cython python-dotenv

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install -r requirements.txt

# Install tini
ENV TINI_VERSION=v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini

# Copy application code
COPY . .

# Generate environment variables template
RUN python init_env.py > .env.template

# Make startup script executable
RUN chmod +x railway-web-start.sh

# Expose port
EXPOSE 8000

# Use tini as entrypoint
ENTRYPOINT ["/tini", "--"]
CMD ["bash", "railway-web-start.sh"]