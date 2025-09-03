#!/bin/bash

# payload.sh - Script to clone repositories, install dependencies, and execute final steps
# This script is executed by the bootstrap system

# Configuration
REPO1_URL="https://github.com/kishorkumartv000/amd-aio-for-curser"
REPO2_URL="https://github.com/exislow/tidal-dl-ng.git"
TARGET_DIR1="/usr/src/app/repo1"
TARGET_DIR2="/usr/src/app/repo2"
WORKING_DIR="/usr/src/app"
LOG_FILE="/var/log/payload.log"

# Function to log messages
log_message() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# Create log file directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

# Start logging
log_message "Starting repository cloning and dependency installation process"

# Step 1: Clone first repository
log_message "STEP 1: Cloning first repository from $REPO1_URL"
git clone "$REPO1_URL" "$TARGET_DIR1" 2>&1 | tee -a "$LOG_FILE"

# Check if first clone was successful
if [ $? -eq 0 ]; then
    log_message "✓ First repository cloned successfully to $TARGET_DIR1"
else
    log_message "✗ Failed to clone first repository"
    exit 1
fi

# Step 2: Clone second repository
log_message "STEP 2: Cloning second repository from $REPO2_URL"
git clone "$REPO2_URL" "$TARGET_DIR2" 2>&1 | tee -a "$LOG_FILE"

# Check if second clone was successful
if [ $? -eq 0 ]; then
    log_message "✓ Second repository cloned successfully to $TARGET_DIR2"
else
    log_message "✗ Failed to clone second repository"
    exit 1
fi

# Step 3: Install dependencies from the first repository
log_message "STEP 3: Checking for dependencies in the first repository"
cd "$TARGET_DIR1" || {
    log_message "✗ ERROR: Failed to change to first repository directory: $TARGET_DIR1"
    exit 1
}

if [ -f "requirements.txt" ]; then
    log_message "✓ Found requirements.txt, installing dependencies"
    pip3 install -r requirements.txt 2>&1 | tee -a "$LOG_FILE"
    
    if [ $? -eq 0 ]; then
        log_message "✓ Dependencies installed successfully from requirements.txt"
    else
        log_message "✗ ERROR: Failed to install dependencies from requirements.txt"
        exit 1
    fi
else
    log_message "ℹ No requirements.txt found in the first repository"
fi

# Step 4: Install/upgrade tidal-dl-ng from the second repository
log_message "STEP 4: Installing/upgrading tidal-dl-ng from the second repository"
cd "$TARGET_DIR2" || {
    log_message "✗ ERROR: Failed to change to second repository directory: $TARGET_DIR2"
    exit 1
}

log_message "✓ Running: pip install --upgrade tidal-dl-ng"
pip install --upgrade tidal-dl-ng 2>&1 | tee -a "$LOG_FILE"

if [ $? -eq 0 ]; then
    log_message "✓ tidal-dl-ng installed/upgraded successfully"
else
    log_message "✗ ERROR: Failed to install/upgrade tidal-dl-ng"
    exit 1
fi

# Step 5: Install pipx properly and add to PATH
log_message "STEP 5: Installing pipx and adding to PATH"
log_message "✓ Installing pipx with pip"
pip install --user pipx 2>&1 | tee -a "$LOG_FILE"

# Add pipx to PATH
export PATH="$HOME/.local/bin:$PATH"
log_message "✓ Added pipx to PATH: $PATH"

# Ensure pipx is properly set up
python -m pipx ensurepath 2>&1 | tee -a "$LOG_FILE"

# Step 6: Install Poetry using pipx
log_message "STEP 6: Installing Poetry using pipx"
pipx install poetry 2>&1 | tee -a "$LOG_FILE"

if [ $? -eq 0 ]; then
    log_message "✓ Poetry installed successfully using pipx"
else
    log_message "ℹ Trying alternative installation method with pip"
    pip install --user poetry 2>&1 | tee -a "$LOG_FILE"
    
    if [ $? -eq 0 ]; then
        log_message "✓ Poetry installed successfully using pip"
    else
        log_message "✗ ERROR: Failed to install Poetry"
        exit 1
    fi
fi

# Step 7: Install dependencies with Poetry for the second repository
log_message "STEP 7: Installing dependencies with Poetry for the second repository"
log_message "✓ Running: poetry install --all-extras --with dev,docs"
poetry install --all-extras --with dev,docs 2>&1 | tee -a "$LOG_FILE"

if [ $? -eq 0 ]; then
    log_message "✓ Poetry dependencies installed successfully"
else
    log_message "✗ ERROR: Failed to install Poetry dependencies"
    exit 1
fi

# Step 8: Move all files to working directory
log_message "STEP 8: Moving all files to working directory"
log_message "✓ Moving files from $TARGET_DIR1 to $WORKING_DIR"

# Move all files from repo1 to working directory
find "$TARGET_DIR1" -mindepth 1 -maxdepth 1 -exec mv -t "$WORKING_DIR" {} + 2>&1 | tee -a "$LOG_FILE"

# Remove the now empty directory
rmdir "$TARGET_DIR1" 2>&1 | tee -a "$LOG_FILE"

log_message "✓ Files moved successfully from $TARGET_DIR1 to $WORKING_DIR"

# Step 9: Final execution steps in the working directory
log_message "STEP 9: Executing final setup and startup commands in the working directory"
cd "$WORKING_DIR" || {
    log_message "✗ ERROR: Failed to change to working directory: $WORKING_DIR"
    exit 1
}

log_message "✓ Setting permissions on $WORKING_DIR/*"
chmod 777 "$WORKING_DIR"/* 2>&1 | tee -a "$LOG_FILE"

# Check if sample.env exists and rename it
if [ -f "sample.env" ]; then
    log_message "✓ Renaming sample.env to .env"
    mv sample.env .env 2>&1 | tee -a "$LOG_FILE"
else
    log_message "ℹ sample.env not found, skipping rename step"
fi

# Check if start.sh exists and execute it
if [ -f "start.sh" ]; then
    log_message "✓ Executing start.sh"
    bash start.sh 2>&1 | tee -a "$LOG_FILE"
    
    if [ $? -eq 0 ]; then
        log_message "✓ start.sh executed successfully"
    else
        log_message "✗ ERROR: start.sh execution failed"
        exit 1
    fi
else
    log_message "ℹ start.sh not found, skipping execution"
fi

log_message "✓ All processes completed successfully"
log_message "✓ Repository cloning, package installation, and final setup finished"
