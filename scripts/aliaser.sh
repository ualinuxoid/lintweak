#!/usr/bin/env bash

set -euo pipefail

API_BASE="https://quack.duckduckgo.com/api"
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36"
TOKEN_FILE="${HOME}/.qwacky_token"

zenity_msg() {
    local type="$1"
    local text="$2"
    local title="${3:-Qwacky}"
    case "$type" in
        info)   zenity --info --text="$text" --title="$title" 2>/dev/null ;;
        error)  zenity --error --text="$text" --title="$title" 2>/dev/null ;;
        question) zenity --question --text="$text" --title="$title" 2>/dev/null ;;
    esac
}

copy_to_clipboard() {
    local text="$1"
    if command -v xclip &>/dev/null; then
        echo -n "$text" | xclip -selection clipboard
    elif command -v xsel &>/dev/null; then
        echo -n "$text" | xsel --clipboard --input
    else
        return 1
    fi
    return 0
}

check_deps() {
    local missing=()
    for cmd in curl jq; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if ! command -v xclip &>/dev/null && ! command -v xsel &>/dev/null; then
        missing+=("xclip or xsel (clipboard)")
    fi
    if [[ ${#missing[@]} -gt 0 ]]; then
        zenity_msg error "Missing dependencies:\n${missing[*]}\n\nPlease install them and try again."
        exit 1
    fi
}

do_login() {
    # Step 1: get username
    local username
    username=$(zenity --entry --title="Qwacky — Login" \
        --text="Enter your DuckDuckGo username (without @duck.com):" 2>/dev/null)
    if [[ -z "$username" ]]; then
        zenity_msg info "Login cancelled."
        return
    fi

    local url="${API_BASE}/auth/loginlink?user=${username}"
    local response
    response=$(curl -s -w "%{http_code}" -A "$USER_AGENT" "$url")
    local http_code="${response: -3}"
    local body="${response%???}"

    if [[ "$http_code" -eq 429 ]]; then
        zenity_msg error "Too many requests. Please wait a moment."
        return
    elif [[ "$http_code" -ne 200 ]]; then
        zenity_msg error "Failed to request OTP (HTTP $http_code).\n$body"
        return
    fi

    if ! echo "$body" | jq -e '.needs_otp == true' >/dev/null 2>&1; then
        zenity_msg error "Unexpected server response:\n$(echo "$body" | jq -r '.message // "unknown"')"
        return
    fi

    zenity_msg info "OTP sent to ${username}@duck.com\n\nPlease check your email and enter OTP in the next step."

    local otp_input
    otp_input=$(zenity --entry --title="Login" \
        --text="OTP passphrase:" 2>/dev/null)
    if [[ -z "$otp_input" ]]; then
        zenity_msg info "OTP entry cancelled."
        return
    fi

    local otp="$otp_input"
    if [[ "$otp_input" =~ otp=([^&]+) ]]; then
        otp="${BASH_REMATCH[1]}"
    fi
    
    otp=$(echo "$otp" | sed 's/ /-/g')

    # Verify OTP
    local verify_url="${API_BASE}/auth/login?otp=${otp}&user=${username}"
    local verify_response
    verify_response=$(curl -s -w "%{http_code}" -A "$USER_AGENT" "$verify_url")
    local verify_http="${verify_response: -3}"
    local verify_body="${verify_response%???}"

    if [[ "$verify_http" -eq 429 ]]; then
        zenity_msg error "Too many requests. Please wait a moment."
        return
    elif [[ "$verify_http" -ne 200 ]]; then
        zenity_msg error "Login failed (HTTP $verify_http).\n$verify_body"
        return
    fi

    local token
    token=$(echo "$verify_body" | jq -r '.token // empty')
    if [[ -z "$token" || "$token" == "null" ]]; then
        zenity_msg error "Invalid passphrase. Try again."
        return
    fi

    local dashboard
    dashboard=$(curl -s -A "$USER_AGENT" \
        -H "Authorization: Bearer ${token}" \
        "${API_BASE}/email/dashboard" 2>/dev/null)

    if ! echo "$dashboard" | jq -e '.user' >/dev/null 2>&1; then
        zenity_msg error "Authentication failed. Strange. Maybe your token is invalid."
        return
    fi

    echo "$token" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"

    local user_email
    user_email=$(echo "$dashboard" | jq -r '.user.email // "unknown"')
    zenity_msg info "Login successful!\nLogged in as: $user_email\n\nToken saved."
}

do_generate() {
    local token
    token=$(cat "$TOKEN_FILE" 2>/dev/null || echo "")
    if [[ -z "$token" ]]; then
        zenity_msg question "You are not logged in.\nDo you want to log in now?" || return
        do_login
        # after login, try again
        token=$(cat "$TOKEN_FILE" 2>/dev/null || echo "")
        if [[ -z "$token" ]]; then
            zenity_msg error "Login failed. Cannot generate alias."
            return
        fi
    fi

    local response
    response=$(curl -s -X POST -A "$USER_AGENT" \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json" \
        "${API_BASE}/email/addresses")

    local address
    address=$(echo "$response" | jq -r '.address // empty')
    if [[ -z "$address" || "$address" == "null" ]]; then
        local err_msg
        err_msg=$(echo "$response" | jq -r '.message // "unknown error"')
        zenity_msg error "Failed to generate alias.\n$err_msg"
        return
    fi

    if copy_to_clipboard "$address"; then
        zenity_msg info "New alias generated:\n\n$address\n\nCopied to clipboard!"
    else
        zenity_msg info "New alias generated:\n\n$address\n\nCould not copy to clipboard (xclip/xsel missing)."
    fi
}

do_logout() {
    if [[ -f "$TOKEN_FILE" ]]; then
        if zenity_msg question "Are you sure you want to log out?\nYour session token will be deleted."; then
            rm -f "$TOKEN_FILE"
            zenity_msg info "Logged out successfully."
        fi
    else
        zenity_msg info "No active session found."
    fi
}

do_status() {
    if [[ ! -f "$TOKEN_FILE" ]]; then
        zenity_msg info "No active session.\nPlease log in first."
        return
    fi

    local token
    token=$(cat "$TOKEN_FILE")
    local dashboard
    dashboard=$(curl -s -A "$USER_AGENT" \
        -H "Authorization: Bearer ${token}" \
        "${API_BASE}/email/dashboard" 2>/dev/null)

    if ! echo "$dashboard" | jq -e '.user' >/dev/null 2>&1; then
        zenity_msg error "Session token is invalid or expired.\nPlease log in again."
        rm -f "$TOKEN_FILE"
        return
    fi

    local email count
    email=$(echo "$dashboard" | jq -r '.user.email // "unknown"')
    count=$(echo "$dashboard" | jq -r '.stats.addresses_generated // 0')
    zenity_msg info "Active session\n\nUser: $email\nAliases generated: $count"
}

main_menu() {
    while true; do
        local choice
        choice=$(zenity --list --title="Aliaser" --width=400 --height=300 \
            --column="Action" \
            --text="Choose an action:" \
            "Login" \
            "Generate Alias" \
            "Status" \
            "Logout" \
            "Exit" 2>/dev/null)

        case "$choice" in
            "Login")        do_login ;;
            "Generate Alias") do_generate ;;
            "Status")       do_status ;;
            "Logout")       do_logout ;;
            "Exit"|"")      break ;;
            *)              zenity_msg error "Unknown option." ;;
        esac
    done
}

check_deps
main_menu