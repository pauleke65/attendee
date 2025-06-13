#!/bin/bash

# Railway web service startup script
set -e

echo "🌐 Starting Attendee Web Service..."

# Debug: Print environment variables
echo "🔍 Environment variables:"
echo "DATABASE_URL: ${DATABASE_URL:0:20}..." 
echo "REDIS_URL: ${REDIS_URL:0:20}..." 
echo "DJANGO_SETTINGS_MODULE: $DJANGO_SETTINGS_MODULE"
echo "PORT: $PORT"

# Check if required environment variables are set
if [ -z "$DATABASE_URL" ]; then
    echo "❌ ERROR: DATABASE_URL environment variable is not set!"
    echo "Make sure you've added a PostgreSQL service in Railway"
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
echo "REDIS_URL=${REDIS_URL:-redis://localhost:6379}" >> .env
echo "DJANGO_SETTINGS_MODULE=$DJANGO_SETTINGS_MODULE" >> .env

# Test database connection
echo "🔗 Testing database connection..."
python -c "
import os
import dj_database_url
import psycopg2
from urllib.parse import urlparse

url = os.getenv('DATABASE_URL')
if url:
    parsed = urlparse(url)
    try:
        conn = psycopg2.connect(
            host=parsed.hostname,
            port=parsed.port,
            user=parsed.username,
            password=parsed.password,
            database=parsed.path[1:]
        )
        conn.close()
        print('✅ Database connection successful')
    except Exception as e:
        print(f'❌ Database connection failed: {e}')
        exit(1)
else:
    print('❌ DATABASE_URL not found')
    exit(1)
"

# Run migrations
echo "📊 Running database migrations..."
python manage.py migrate --noinput

# Collect static files
echo "📁 Collecting static files..."
python manage.py collectstatic --noinput

# Start the web application
echo "✅ Starting Gunicorn web server on port ${PORT:-8000}..."
exec gunicorn attendee.wsgi:application \
    --bind 0.0.0.0:${PORT:-8000} \
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