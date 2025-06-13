#!/bin/bash

# Railway startup script
set -e

echo "🚀 Starting Attendee on Railway..."

# Generate environment file if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Generating environment configuration..."
    python init_env.py > .env
fi

# Initialize PulseAudio
echo "🔊 Initializing PulseAudio..."
rm -rf /var/run/pulse /var/lib/pulse /root/.config/pulse || true
pulseaudio -D --exit-idle-time=-1 || true
sleep 2

# Run migrations
echo "📊 Running database migrations..."
python manage.py migrate --noinput

# Collect static files
echo "📁 Collecting static files..."
python manage.py collectstatic --noinput

# Start the application
echo "✅ Starting Gunicorn server..."
exec gunicorn attendee.wsgi:application \
    --bind 0.0.0.0:$PORT \
    --workers 2 \
    --worker-class gthread \
    --threads 4 \
    --worker-connections 1000 \
    --max-requests 1000 \
    --max-requests-jitter 100 \
    --timeout 30 \
    --keep-alive 2 \
    --access-logfile - \
    --error-logfile -