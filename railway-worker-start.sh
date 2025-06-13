#!/bin/bash

# Railway worker service startup script
set -e

echo "👷 Starting Attendee Celery Worker..."

# Debug: Print environment variables
echo "🔍 Environment variables:"
echo "DATABASE_URL: ${DATABASE_URL:0:20}..." 
echo "REDIS_URL: ${REDIS_URL:0:20}..." 
echo "DJANGO_SETTINGS_MODULE: $DJANGO_SETTINGS_MODULE"

# Check if required environment variables are set
if [ -z "$DATABASE_URL" ]; then
    echo "❌ ERROR: DATABASE_URL environment variable is not set!"
    echo "Make sure you've added a PostgreSQL service in Railway"
    exit 1
fi

if [ -z "$REDIS_URL" ]; then
    echo "❌ ERROR: REDIS_URL environment variable is not set!"
    echo "Make sure you've added a Redis service in Railway"
    exit 1
fi

if [ -z "$DJANGO_SETTINGS_MODULE" ]; then
    echo "⚠️  WARNING: DJANGO_SETTINGS_MODULE not set, defaulting to production"
    export DJANGO_SETTINGS_MODULE="attendee.settings.production"
fi

# Generate environment file if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Generating environment configuration..."
    python init_env.py > .env
fi

# Add Railway-specific environment variables to .env
echo "DATABASE_URL=$DATABASE_URL" >> .env
echo "REDIS_URL=$REDIS_URL" >> .env
echo "DJANGO_SETTINGS_MODULE=$DJANGO_SETTINGS_MODULE" >> .env

# Test Redis connection
echo "🔗 Testing Redis connection..."
python -c "
import os
import redis
from urllib.parse import urlparse

redis_url = os.getenv('REDIS_URL')
if redis_url:
    try:
        r = redis.from_url(redis_url)
        r.ping()
        print('✅ Redis connection successful')
    except Exception as e:
        print(f'❌ Redis connection failed: {e}')
        exit(1)
else:
    print('❌ REDIS_URL not found')
    exit(1)
"

# Initialize PulseAudio (run as system if root)
echo "🔊 Initializing PulseAudio..."
rm -rf /var/run/pulse /var/lib/pulse /root/.config/pulse || true
pulseaudio -D --system --exit-idle-time=-1 || pulseaudio -D --exit-idle-time=-1 || true
sleep 2

# Initialize entrypoint dependencies (if entrypoint.sh exists)
if [ -f "/opt/bin/entrypoint.sh" ]; then
    echo "🚀 Running entrypoint initialization..."
    /opt/bin/entrypoint.sh &
    sleep 3
fi

# Test Celery can connect to broker
echo "🔧 Testing Celery broker connection..."
python -c "
import os
from celery import Celery

app = Celery('attendee')
app.config_from_object('django.conf:settings', namespace='CELERY')

try:
    # Test broker connection
    inspect = app.control.inspect()
    print('✅ Celery broker connection successful')
except Exception as e:
    print(f'❌ Celery broker connection failed: {e}')
    exit(1)
"

# Start Celery worker
echo "✅ Starting Celery worker..."
exec celery -A attendee worker -l INFO \
    --concurrency=2 \
    --max-tasks-per-child=100 \
    --task-events \
    --without-gossip \
    --without-mingle \
    --without-heartbeat