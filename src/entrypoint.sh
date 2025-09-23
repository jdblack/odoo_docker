#!/bin/bash

set -e

####
# Common options
####
# specify alternate config file (default None)
export ODOO_CONFIG="${ODOO_CONFIG}"

# data_dir (default /var/lib/odoo)
export ODOO_DATA_DIR="${ODOO_DATA_DIR:-/volumes/data}"


####
# HTTP Service Configuration
####

# Docker Specific configuration
IMAGE_ODOO_ENTERPRISE_LOCATION="${IMAGE_ODOO_ENTERPRISE_LOCATION:-/volumes/enterprise}"

# If the enterprise folder exists, add it to the ODOO_ADDONS_PATH
if [ -d "${IMAGE_ODOO_ENTERPRISE_LOCATION}" ]; then
    echo "Odoo Enterprise has been detected"

    if [ -z "$ODOO_ADDONS_PATH" ]; then
        export ODOO_ADDONS_PATH="$IMAGE_ODOO_ENTERPRISE_LOCATION"
    else
        export ODOO_ADDONS_PATH="$ODOO_ADDONS_PATH,$IMAGE_ODOO_ENTERPRISE_LOCATION"
    fi
fi

# If the enterprise folder exists, add it to the ODOO_ADDONS_PATH
if [ -d "${IMAGE_EXTRA_ADDONS_LOCATION}" ]; then
    echo "Additional addons have been detected"

    if [ -z "$ODOO_ADDONS_PATH" ]; then
        export ODOO_ADDONS_PATH="$IMAGE_EXTRA_ADDONS_LOCATION"
    else
        export ODOO_ADDONS_PATH="$ODOO_ADDONS_PATH,$IMAGE_EXTRA_ADDONS_LOCATION"
    fi
fi

# Set the secrets directory from the environment variable IMAGE_SECRETS_DIR (defaulting to /run/secrets)
IMAGE_SECRETS_DIR="${IMAGE_SECRETS_DIR:-/run/secrets}"

# Set the secrets directory from the environment variable IMAGE_SECRETS_DIR (defaulting to /run/secrets)
# Loop through each file in the configured secrets directory and export its content as an environment variable
if [ -d "$IMAGE_SECRETS_DIR" ]; then
    while IFS= read -r -d '' secret; do
        [ -f "$secret" ] || continue
        secret_name=$(basename "$secret")
        env_var=$(echo "$secret_name" | tr '[:lower:]' '[:upper:]')
        # Read and trim; skip empty values to avoid breaking int/choice options
        value=$(tr -d '\r' < "$secret" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        [ -n "$value" ] || continue
        export "${env_var}=${value}"
    done < <(find "$IMAGE_SECRETS_DIR" -mindepth 1 -maxdepth 1 -type f -print0)
fi


IMAGE_CONFIG_LOCATION="${IMAGE_CONFIG_LOCATION:-/volumes/config/odoo.conf}"

# Substitute environment variables into the config file
# and write them to the generated config file
envsubst < "${IMAGE_CONFIG_LOCATION}" > "${ODOO_RC}"

/hook_setup "$@"

case "$1" in
    -- | odoo)
        shift
        if [[ "$1" == "scaffold" ]] ; then
            exec odoo "$@"
        else
            wait-for-psql.py "$@"
            exec odoo "$@"
        fi
        ;;
    -*)
        wait-for-psql.py "$@"
        exec odoo "$@"
        ;;
    *)
        exec "$@"
esac

exit 1
