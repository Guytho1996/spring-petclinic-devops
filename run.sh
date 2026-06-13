#!/bin/bash

set -euo pipefail

# Change directory to the script's directory to ensure paths work correctly.
cd "$(dirname "$0")"

HOSTNAME_VALUE="$(hostname)"
if [[ "$HOSTNAME_VALUE" == *prod* ]]; then
    DEFAULT_ENV_FILE="$HOME/.spring-petclinic-devops-prod.env"
else
    DEFAULT_ENV_FILE="$HOME/.spring-petclinic-devops-dev.env"
fi

ENV_FILE="${PETCLINIC_ENV_FILE:-$DEFAULT_ENV_FILE}"

echo "==== Step 1: Checking Java 17 Installation ===="
if ! command -v java &> /dev/null || ! java -version 2>&1 | grep -q "17"; then
    echo "Java 17 was not found. Installing OpenJDK 17..."
    sudo apt-get update
    sudo apt-get install -y openjdk-17-jdk
else
    echo "Java 17 is already installed."
fi

echo "==== Step 2: Loading database configuration ===="
if [[ ! -f "$ENV_FILE" ]]; then
    echo "Database environment file not found: $ENV_FILE" >&2
    echo "Create it outside the repository or set PETCLINIC_ENV_FILE=/path/to/env-file." >&2
    exit 1
fi

ENV_PERMISSIONS="$(stat -c "%a" "$ENV_FILE")"
if [[ "$ENV_PERMISSIONS" != "600" ]]; then
    echo "Refusing to load $ENV_FILE because permissions are $ENV_PERMISSIONS; expected 600." >&2
    exit 1
fi

set -a
# shellcheck source=/dev/null
. "$ENV_FILE"
set +a

export SPRING_PROFILES_ACTIVE="${SPRING_PROFILES_ACTIVE:-postgres}"
: "${POSTGRES_URL:?POSTGRES_URL must be set in $ENV_FILE}"
: "${POSTGRES_USER:?POSTGRES_USER must be set in $ENV_FILE}"
: "${POSTGRES_PASS:?POSTGRES_PASS must be set in $ENV_FILE}"

echo "Using Spring profile: $SPRING_PROFILES_ACTIVE"
echo "Using database URL: $POSTGRES_URL"

echo "==== Step 3: Preparing Maven Wrapper ===="
# Ensure mvnw has execute permissions
chmod +x ./mvnw

echo "==== Step 4: Running the Application ===="
# Start the Spring Boot application
./mvnw spring-boot:run
