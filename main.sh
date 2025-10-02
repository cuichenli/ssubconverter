#!/bin/bash

# Vaultwarden CLI Airport Directory Password Search Script
# Searches for password items in the "机场" (Airport) directory using Bitwarden CLI with API key

set -e  # Exit on any error
# Configuration - MODIFY THESE VALUES
VAULTWARDEN_SERVER_URL=${VAULTWARDEN_SERVER_URL:?what are you doing? there is no VAULTWARDEN_SERVER_URL}  # Replace with your Vaultwarden server URL
API_CLIENT_ID=${API_CLIENT_ID:?what are you doing? there is no API_CLIENT_ID}                           # Your API client ID
API_CLIENT_SECRET=${API_CLIENT_SECRET:?what are you doing? there is no API_CLIENT_SECRET}                          # Your API client secret
FOLDER_NAME="机场"
MASTER_PASSWORD=${MASTER_PASSWORD:?what are you doing? there is no MASTER_PASSWORD}    
SUBSCRIPTION_URL=""

SUBCONVERTER_VERSION=${SUBCONVERTER_VERSION:-0.9.8}
EXTRACTED_DIRECTORY=subconverter_release
GIST_TOKEN=${GIST_TOKEN:?what are you doing? there is no GIST_TOKEN}
GIST_ID=${GIST_ID:?what are you doing? there is no GIST_ID}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Bitwarden CLI is installed
check_bw_cli() {
    if ! command -v bw &> /dev/null; then
        print_error "Bitwarden CLI is not installed. Please install it first:"
        echo "npm install -g @bitwarden/cli"
        echo "or visit: https://bitwarden.com/help/cli/"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        print_error "jq is not installed. Please install it first:"
        echo "On Ubuntu/Debian: sudo apt install jq"
        echo "On macOS: brew install jq"
        exit 1
    fi
    
    print_success "Bitwarden CLI and jq found"
}

# Validate configuration
validate_config() {
    if [[ "$VAULTWARDEN_SERVER_URL" == "https://your-vaultwarden-server.com" ]]; then
        print_error "Please configure your Vaultwarden server URL in the script"
        exit 1
    fi
    
    if [[ "$API_CLIENT_ID" == "your-client-id" ]] || [[ -z "$API_CLIENT_ID" ]]; then
        print_error "Please configure your API client ID in the script"
        exit 1
    fi
    
    if [[ "$API_CLIENT_SECRET" == "your-client-secret" ]] || [[ -z "$API_CLIENT_SECRET" ]]; then
        print_error "Please configure your API client secret in the script"
        exit 1
    fi
    
    print_success "Configuration validated"
}

# Configure CLI for Vaultwarden server
configure_cli() {
    print_status "Configuring Bitwarden CLI for Vaultwarden server..."
    
    # Set the server URL
    bw config server "$VAULTWARDEN_SERVER_URL" > /dev/null
    
    if [ $? -ne 0 ]; then
        print_error "Failed to configure server URL"
        exit 1
    fi
    
    print_success "CLI configured for server: $VAULTWARDEN_SERVER_URL"
}

# Check authentication status and handle API key login
check_and_login() {
    print_status "Checking authentication status..."
    
    local status=$(bw status 2>/dev/null | jq -r '.status' 2>/dev/null || echo "unauthenticated")
    
    case "$status" in
        "unlocked")
            print_success "Already authenticated and vault is unlocked"
            return 0
            ;;
        "locked")
            print_status "Authenticated but vault is locked. Unlocking..."
            unlock_vault
            return 0
            ;;
        "unauthenticated")
            print_status "Not authenticated. Logging in with API key..."
            login_with_api_key
            ;;
        *)
            print_warning "Unknown status: $status. Attempting to re-authenticate..."
            login_with_api_key
            ;;
    esac
}

# Login with API key
login_with_api_key() {
    print_status "Authenticating with API key..."
    
    # Set environment variables for API login
    export BW_CLIENTID="$API_CLIENT_ID"
    export BW_CLIENTSECRET="$API_CLIENT_SECRET"
    
    # Logout first to ensure clean state
    bw logout > /dev/null 2>&1 || true
    
    # Login using API key method
    if ! bw login --apikey > /dev/null 2>&1; then
        print_error "Failed to login with API key"
        print_error "Please verify:"
        print_error "1. Your API credentials are correct"
        print_error "2. Your Vaultwarden server is accessible"
        print_error "3. API access is enabled on your Vaultwarden instance"
        exit 1
    fi
    
    print_success "Successfully logged in with API key"
    
    # Now unlock the vault
    unlock_vault
}

# Unlock vault (for API key login, this usually requires master password)
unlock_vault() {
    local status=$(bw status 2>/dev/null | jq -r '.status' 2>/dev/null || echo "unknown")
    
    if [ "$status" = "unlocked" ]; then
        print_success "Vault is already unlocked"
        return 0
    fi
    
    print_status "Vault needs to be unlocked"
    print_status "Enter your master password (this won't be stored):"
    
    # Read master password securely
        
    if [ -z "$MASTER_PASSWORD" ]; then
        print_error "Master password cannot be empty"
        exit 1
    fi
    
    # Unlock vault and get session key
    local session_key
    session_key=$(bw unlock "$MASTER_PASSWORD" --raw 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$session_key" ]; then
        print_error "Failed to unlock vault. Please check your master password."
        exit 1
    fi
    
    # Export session key for subsequent commands
    export BW_SESSION="$session_key"
    
    print_success "Vault unlocked successfully"
    
    # Clear the password variable
    unset MASTER_PASSWORD
}

# Get folder ID for the specified folder name
get_folder_id() {
    # print_status "Searching for folder: $FOLDER_NAME"
    
    local folders_json
    folders_json=$(bw list folders 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        print_error "Failed to fetch folders. Please check your authentication."
        exit 1
    fi
    
    local folder_id
    folder_id=$(echo "$folders_json" | jq -r ".[] | select(.name == \"$FOLDER_NAME\") | .id")
    
    if [ -z "$folder_id" ] || [ "$folder_id" = "null" ]; then
        print_error "Folder '$FOLDER_NAME' not found in Vaultwarden vault"
        print_status "Available folders:"
        echo "$folders_json" | jq -r '.[].name' | sed 's/^/  - /'
        exit 1
    fi
    
    # print_success "Found folder '$FOLDER_NAME' with ID: $folder_id"
    echo "$folder_id"
}

# Search and extract password items with notes
search_and_extract() {
    local folder_id="$1"
    echo "folder id: $folder_id"
    print_status "Searching for password items in folder '$FOLDER_NAME'..."
    
    # Get all items in the specified folder (type 1 = login items)
    local items_json
    items_json=$(bw list items --folderid "$folder_id")
    
    if [ $? -ne 0 ]; then
        print_error "Failed to fetch items from folder"
        exit 1
    fi
    
    # Filter for login items only (type 1)
    local login_items
    login_items=$(echo "$items_json" | jq '.[] | select(.type == 1)')
    
    if [ -z "$login_items" ]; then
        print_warning "No password items found in folder '$FOLDER_NAME'"
        exit 0
    fi
    
    print_status "Extracting password items and notes..."
    
    local count=0
    
    # Process each item
    SUBSCRIPTION_URL=$(echo "$login_items" | jq -c '.' | while read -r item; do
        if [ -z "$item" ] || [ "$item" = "null" ]; then
            continue
        fi
        
        local notes=$(echo "$item" | jq -r '.notes // ""')
        if [ -n "$notes" ] && [ "$notes" != "null" ] && [ "$notes" != "" ]; then
            echo -n "$notes|"
        fi
        count=$((count + 1))
    done)


    print_success "Extraction complete! Found $count password items."    
    return $count
}

# Cleanup function
cleanup() {
    # Clear session if set
    if [ -n "$BW_SESSION" ]; then
        unset BW_SESSION
    fi
    
    # Clear API credentials
    if [ -n "$BW_CLIENTID" ]; then
        unset BW_CLIENTID
    fi
    
    if [ -n "$BW_CLIENTSECRET" ]; then
        unset BW_CLIENTSECRET
    fi
}

# Set trap for cleanup on exit
trap cleanup EXIT

# Main execution
main() {
    print_status "Starting Vaultwarden CLI Airport Directory Password Search"
    echo
    
    # Setup and validation
    check_bw_cli
    validate_config
    configure_cli
    
    # Authentication
    check_and_login
    
    # Get folder and extract data
    folder_id=$(get_folder_id)
    search_and_extract "$folder_id"
    bw logout
    
    wget -O subconverter_release.tar.gz "https://github.com/asdlokj1qpi233/subconverter/releases/download/v${SUBCONVERTER_VERSION}/subconverter_linux64.tar.gz"
    tar xvf ./subconverter_release.tar.gz 

    mv ./subconverter "./${EXTRACTED_DIRECTORY}"
    cp "./${EXTRACTED_DIRECTORY}/subconverter" .
    cp -r "./${EXTRACTED_DIRECTORY}/base" ./base

    cat <<EOF > generate.ini
[surfboard]
path=output.yaml
target=surfboard
url=${SUBSCRIPTION_URL}
upload=true
upload_path=surfboard
udp=true

[clash]
path=output.yaml
target=clash
url=${SUBSCRIPTION_URL}
upload=false
upload_path=clash
udp=true

[singbox]
path=output.yaml
target=singbox
url=${SUBSCRIPTION_URL}
upload=true
upload_path=singbox
udp=true
EOF

    cat <<EOF > gistconf.ini
[common]
token = ${GIST_TOKEN}
id = ${GIST_ID}
EOF

    git clone https://github.com/Toperlock/sing-box-subscribe.git
    ./subconverter -g --artifact surfboard --log out-surfboard.tmp 
    ./subconverter -g --artifact clash --log out-clash.tmp
    curl ${PROCESS_SCRIPTS_URL:?what are you doing? there is no PROCESS_SCRIPTS_URL} >> main.js
    node main.js
    ./subconverter -g --artifact singbox --log out-singbox.tmp 
    rm sing-box-subscribe/config_template/*
    cp sub.json sing-box-subscribe/config_template/
    jq --arg url "https://gist.githubusercontent.com/cuichenli/$GIST_ID/raw/clash" '.subscribes[0].url = $url' providers.json > tmp.json && mv tmp.json providers.json
    cp providers.json ./sing-box-subscribe/
    cd sing-box-subscribe 
    uv venv .venv
    uv pip install -r requirements.txt 
    uv run main.py --template_index=0
    cd ..
    node main-extra.js
}

# Run main function
main "$@"
