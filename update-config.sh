#!/bin/bash

# Set the environment variables
export DB_HOST="10.85.0.22"
export DB_HOST_PORT="5432"
export REMOTE_POSTGRES_SSLMODE="require"
export SECRETS_postgres_password="password"

export REDIS_HOST="34.58.192.255"
export REDIS_PORT="6379"
export SECRETS_redis_password="password"

export RABBITMQ_HOST="34.30.16.244"
export RABBITMQ_PORT="5672"
export SECRETS_rabbitmq_password="password"

export MEMCACHED_HOST="35.192.145.111"
export MEMCACHED_PORT="11211"
export SECRETS_memcached_password="password"

# SMTP settings from transactional email provider (example: SendInBlue)
export EMAIL_HOST="smtp.sendgrid.net"
export EMAIL_HOST_USER="apikey"
export EMAIL_PASSWORD="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"
export EMAIL_USE_TLS="True"
export EMAIL_PORT="587"

# Set the path to the settings file and secrets file
SETTINGS_PY="/etc/zulip/settings.py"
DATA_DIR="/etc/zulip"
ZULIP_SECRETS_CONF="$DATA_DIR/zulip-secrets.conf"

# Function to set a value in settings.py
setConfigurationValue() {
    local key="$1"
    local value="$2"
    local config_file="$3"
    local value_type="$4"

    if [ "$value_type" == "string" ]; then
        sed -i "s|^\($key = \).*|\1\"$value\"|" "$config_file"
    elif [ "$value_type" == "boolean" ]; then
        if [ "$value" == "true" ]; then
            sed -i "s|^\($key = \).*|\1True|" "$config_file"
        else
            sed -i "s|^\($key = \).*|\1False|" "$config_file"
        fi
    fi
}

# Function to configure the database settings
databaseConfiguration() {
    echo "Setting database configuration ..."
    
    # PostgreSQL configuration
    setConfigurationValue "REMOTE_POSTGRES_HOST" "$DB_HOST" "$SETTINGS_PY" "string"
    setConfigurationValue "REMOTE_POSTGRES_PORT" "$DB_HOST_PORT" "$SETTINGS_PY" "string"
    setConfigurationValue "REMOTE_POSTGRES_SSLMODE" "$REMOTE_POSTGRES_SSLMODE" "$SETTINGS_PY" "string"
    setConfigurationValue "POSTGRES_PASSWORD" "$SECRETS_postgres_password" "$SETTINGS_PY" "string"
    
    # Redis configuration
    setConfigurationValue "REDIS_HOST" "$REDIS_HOST" "$SETTINGS_PY" "string"
    setConfigurationValue "REDIS_PORT" "$REDIS_PORT" "$SETTINGS_PY" "string"
    setConfigurationValue "REDIS_PASSWORD" "$SECRETS_redis_password" "$SETTINGS_PY" "string"
    
    # RabbitMQ configuration
    setConfigurationValue "RABBITMQ_HOST" "$RABBITMQ_HOST" "$SETTINGS_PY" "string"
    setConfigurationValue "RABBITMQ_PORT" "$RABBITMQ_PORT" "$SETTINGS_PY" "string"
    setConfigurationValue "RABBITMQ_PASSWORD" "$SECRETS_rabbitmq_password" "$SETTINGS_PY" "string"
    
    # Memcached configuration
    setConfigurationValue "MEMCACHED_HOST" "$MEMCACHED_HOST" "$SETTINGS_PY" "string"
    setConfigurationValue "MEMCACHED_PORT" "$MEMCACHED_PORT" "$SETTINGS_PY" "string"
    setConfigurationValue "MEMCACHED_PASSWORD" "$SECRETS_memcached_password" "$SETTINGS_PY" "string"

    echo "Database configuration succeeded."
}

# Function to configure the secrets
secretsConfiguration() {
    echo "Setting Zulip secrets ..."
    
    # PostgreSQL password
    if [ -n "$SECRETS_postgres_password" ]; then
        crudini --set "$ZULIP_SECRETS_CONF" "secrets" "POSTGRES_PASSWORD" "$SECRETS_postgres_password"
    fi
    
    # Redis password
    if [ -n "$SECRETS_redis_password" ]; then
        crudini --set "$ZULIP_SECRETS_CONF" "secrets" "REDIS_PASSWORD" "$SECRETS_redis_password"
    fi
    
    # RabbitMQ password
    if [ -n "$SECRETS_rabbitmq_password" ]; then
        crudini --set "$ZULIP_SECRETS_CONF" "secrets" "RABBITMQ_PASSWORD" "$SECRETS_rabbitmq_password"
    fi
    
    # Memcached password
    if [ -n "$SECRETS_memcached_password" ]; then
        crudini --set "$ZULIP_SECRETS_CONF" "secrets" "MEMCACHED_PASSWORD" "$SECRETS_memcached_password"
    fi

    echo "Zulip secrets configuration succeeded."
}

# Function to configure other Zulip settings (email, logging, etc.)
otherConfiguration() {
    echo "Setting other Zulip configuration ..."
    
    # ALLOWED_HOSTS configuration
    setConfigurationValue "ALLOWED_HOSTS" "[\"*\"]" "$SETTINGS_PY" "string"

    # Email configuration (SMTP settings for SendGrid)
    setConfigurationValue "EMAIL_HOST" "$EMAIL_HOST" "$SETTINGS_PY" "string"
    setConfigurationValue "EMAIL_HOST_USER" "$EMAIL_HOST_USER" "$SETTINGS_PY" "string"
    setConfigurationValue "EMAIL_PASSWORD" "$EMAIL_PASSWORD" "$SETTINGS_PY" "string"
    setConfigurationValue "EMAIL_USE_TLS" "$EMAIL_USE_TLS" "$SETTINGS_PY" "boolean"
    setConfigurationValue "EMAIL_PORT" "$EMAIL_PORT" "$SETTINGS_PY" "string"

    echo "Other configuration succeeded."
}

# Main entry point
echo "Starting Zulip configuration ..."

# Configure database settings
databaseConfiguration

# Configure secrets (database passwords)
secretsConfiguration

# Configure other settings (ALLOWED_HOSTS and email)
otherConfiguration

echo "Zulip configuration complete."

# Start the Zulip services (example)
echo "Starting Zulip services..."
# You can add the commands to start your services here
