#!/bin/bash

# Exit on error
set -e

# Change directory to the script's directory to ensure paths work correctly
cd "$(dirname "$0")"

echo "==== Step 1: Checking Java 17 Installation ===="
if ! command -v java &> /dev/null || ! java -version 2>&1 | grep -q "17"; then
    echo "Java 17 was not found. Installing OpenJDK 17..."
    sudo apt-get update
    sudo apt-get install -y openjdk-17-jdk
else
    echo "Java 17 is already installed."
fi

echo "==== Step 2: Preparing Maven Wrapper ===="
# Ensure mvnw has execute permissions
chmod +x ./mvnw

echo "==== Step 3: Running the Application ===="
# Start the Spring Boot application
./mvnw spring-boot:run