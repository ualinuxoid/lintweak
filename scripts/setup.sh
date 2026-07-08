#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN} OK: $1${NC}"
}

print_info() {
    echo -e "${BLUE} INFO: $1${NC}"
}

print_warn() {
    echo -e "${YELLOW} WARN: $1${NC}"
}

print_error() {
    echo -e "${RED} ERR: $1${NC}"
}

ask_yes_no() {
    while true; do
        read -p "$1 [y/n]: " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer y or n.";;
        esac
    done
}

check_system() {
    if ! grep -qi "debian\|ubuntu\|mint\|zorin\|pop\|elementary\|kali" /etc/os-release 2>/dev/null; then
        print_warn "This script is designed for Debian-based systems."
        if ! ask_yes_no "Continue anyway"; then
            exit 1
        fi
    fi
}

clear
print_header "Welcome to Linux First-Time Setup!"
echo "This script will help you set up your new Linux system."
echo -e "${YELLOW}Note: You may be asked for your password during setup.${NC}"

if ! ask_yes_no "Start the setup"; then
    echo "Setup cancelled. Goodbye!"
    exit 0
fi

check_system

# Arrays to collect packages for batch installation
APT_PACKAGES=()
FLATPAK_PACKAGES=()

print_header "Step 1: System Update"
echo "This will update your package lists and upgrade installed packages."
echo "It's recommended to keep your system up to date for security and stability."

if ask_yes_no "Update system now"; then
    print_info "Updating package lists..."
    sudo apt update -qq
    
    print_info "Upgrading packages (this may take a while)..."
    sudo apt upgrade -y -qq
    
    print_info "Removing old packages..."
    sudo apt autoremove -y -qq
    
    print_success "System updated successfully!"
else
    print_warn "System update skipped."
fi

print_header "Step 2: Essentials..."
echo "Dependencies..."

print_info "Installing: curl, wget, git, software-properties-common, apt-transport-https"
sudo apt install -y -qq curl wget git software-properties-common apt-transport-https gnupg ca-certificates

print_info "Setting up Flatpak (for sandboxed apps)..."
sudo apt install -y -qq flatpak

print_info "Adding Flathub repository..."
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

print_success "Essential setup complete!"

print_header "Step 3: Choose Your Browser"
echo "Select a web browser to install:"
echo ""
echo -e "${GREEN}[RECOMMENDED]${NC} LibreWolf - Privacy-focused Firefox fork (no telemetry, built-in ad blocking)"
echo "Firefox - Standard Mozilla browser"
echo "Brave - Chromium-based with built-in ad blocking"
echo ""

BROWSER_CHOICE=""

while [ -z "$BROWSER_CHOICE" ]; do
    read -p "Enter choice (librewolf/firefox/brave/none): " choice
    case "$choice" in
        [Ll]ibrewolf|1)
            BROWSER_CHOICE="librewolf"
            print_info "LibreWolf selected - Great privacy choice!"
            ;;
        [Ff]irefox|2)
            BROWSER_CHOICE="firefox"
            print_info "Firefox selected - Classic and reliable!"
            ;;
        [Bb]rave|3)
            BROWSER_CHOICE="brave"
            print_info "Brave selected - Chromium with privacy features!"
            ;;
        [Nn]one|[Nn]o|skip)
            BROWSER_CHOICE="none"
            print_warn "No browser will be installed."
            ;;
        *)
            echo "Invalid choice. Please enter: librewolf, firefox, brave, or none"
            ;;
    esac
done

case "$BROWSER_CHOICE" in
    librewolf)
        print_info "Adding LibreWolf repository..."
        sudo curl -fsSL https://deb.librewolf.net/keyring.gpg | sudo gpg --dearmor -o /usr/share/keyrings/librewolf.gpg
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/librewolf.gpg] https://deb.librewolf.net $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/librewolf.list
        sudo apt update -qq
        APT_PACKAGES+=("librewolf")
        ;;
    firefox)
        APT_PACKAGES+=("firefox")
        ;;
    brave)
        print_info "Adding Brave repository..."
        sudo curl -fsSL https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg | sudo tee /usr/share/keyrings/brave-browser-archive-keyring.gpg
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list
        sudo apt update -qq
        APT_PACKAGES+=("brave-browser")
        ;;
esac

print_header "Step 4: Essential applications"
echo "I'll ask about each app. Selected apps will be installed together at the end."
echo "Now you will have to answer few questions. Don't worry."
echo ""

echo ""
echo "LibreOffice - Free office suite (Word, Excel, PowerPoint alternative)"
if ask_yes_no "Install LibreOffice"; then
    APT_PACKAGES+=("libreoffice")
    print_info "LibreOffice added to install list."
fi

echo ""
echo "Steam - Gaming platform by Valve"
if ask_yes_no "Install Steam"; then
    APT_PACKAGES+=("steam-installer")
    print_info "Steam added to install list."
fi

echo ""
echo "Lutris - Game launcher for Linux (helps run Windows games, GOG, Epic, etc.)"
if ask_yes_no "Install Lutris"; then
    APT_PACKAGES+=("lutris")
    print_info "Lutris added to install list."
fi

echo ""
echo "GIMP - Powerful image editor (like Photoshop, but free)"
if ask_yes_no "Install GIMP (Flatpak)"; then
    FLATPAK_PACKAGES+=("org.gimp.GIMP")
    print_info "GIMP added to install list."
fi

echo ""
echo "Kdenlive - Professional video editor"
echo "Alternative to Premiere Pro. Enough for semi-professional use."
if ask_yes_no "Install Kdenlive (Flatpak)"; then
    FLATPAK_PACKAGES+=("org.kde.kdenlive")
    print_info "Kdenlive added to install list."
fi

echo ""
echo "Metadata Cleaner - Removes hidden metadata from files (photos, docs)"
echo "Protects privacy by stripping location, device info, author data, etc."
echo "Strongly recommended."
if ask_yes_no "Install Metadata Cleaner (Flatpak)"; then
    FLATPAK_PACKAGES+=("io.gitlab.metadatacleaner.metadatacleaner")
    print_info "Metadata Cleaner added to install list."
fi

echo ""
echo "PicoCrypt - Simple and secure file encryption tool"
echo "Encrypt sensitive files with strong password protection."
if ask_yes_no "Install PicoCrypt (Flatpak)"; then
    FLATPAK_PACKAGES+=("io.github.picocrypt.Picocrypt")
    print_info "PicoCrypt added to install list."
fi

echo ""
echo "Prism Launcher - Minecraft launcher (mod support, multiple instances)"
if ask_yes_no "Install Prism Launcher (Flatpak)"; then
    FLATPAK_PACKAGES+=("org.prismlauncher.PrismLauncher")
    print_info "Prism Launcher added to install list."
fi

echo ""
echo "GNOME Snapshot - Take photos and videos with your webcam"
echo "Simple camera app from the GNOME project."
if ask_yes_no "Install Webcam app (GNOME Snapshot)"; then
    APT_PACKAGES+=("gnome-snapshot")
    print_info "GNOME Snapshot added to install list."
fi

print_header "Step 5: Installing Everything"
echo "This may take some time. Grab a coffee!"
echo ""

if [ ${#APT_PACKAGES[@]} -gt 0 ]; then
    print_info "Installing system packages: ${APT_PACKAGES[*]}"
    sudo apt install -y -qq "${APT_PACKAGES[@]}"
    print_success "System packages installed!"
else
    print_info "No system packages to install."
fi

if [ ${#FLATPAK_PACKAGES[@]} -gt 0 ]; then
    print_info "Installing Flatpak apps (may ask for confirmation)..."
    for pkg in "${FLATPAK_PACKAGES[@]}"; do
        print_info "Installing: $pkg"
        sudo flatpak install -y flathub "$pkg"
    done
    print_success "Flatpak apps installed!"
else
    print_info "No Flatpak apps to install."
fi

print_header "Step 6: Privacy & Ad Block Setup"
echo "I can help with few additional tweaks to enhance your user experience:"
echo ""
echo "Block ads via hosts"
echo "Harden system privacy settings"
echo ""

if ask_yes_no "Run privacy and ad blocking setup"; then
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    download_with_fallback() {
        local filename=$1
        local codeberg_url=$2
        local github_url=$3
        
        print_info "Downloading $filename..."
        
        if curl -fsSL --connect-timeout 10 "$codeberg_url" -o "$filename" 2>/dev/null; then
            return 0
        fi

        if curl -fsSL --connect-timeout 10 "$github_url" -o "$filename" 2>/dev/null; then
            return 0
        fi
        
        print_error "Fail..."
        return 1
    }
    
    if download_with_fallback "adblock.sh" \
        "https://codeberg.org/ualinuxoid/lintweak/raw/branch/main/scripts/adblock.sh" \
        "https://github.com/ualinuxoid/lintweak/raw/refs/heads/main/scripts/adblock.sh"; then
        
        chmod +x adblock.sh
        print_info "Running AdBlock script..."
        sudo bash adblock.sh
    fi
    
    echo ""
    
    if download_with_fallback "Privacy.sh" \
        "https://codeberg.org/ualinuxoid/lintweak/raw/branch/main/scripts/Privacy.sh" \
        "https://github.com/ualinuxoid/lintweak/raw/refs/heads/main/scripts/Privacy.sh"; then
        
        chmod +x Privacy.sh
        print_info "Running Privacy script..."
        sudo bash Privacy.sh
    fi
    
    cd ~
    rm -rf "$TEMP_DIR"
    
    print_success "DONE!"
else
    print_warn "SKIPPED!"
fi

print_header "Step 7: Final Touches"
echo "Adding some quality-of-life improvements..."

if command -v gsettings &> /dev/null; then
    # Show hidden files by default in file manager
    gsettings set org.gnome.nautilus.preferences show-hidden-files true 2>/dev/null || true
    print_info "File manager will show hidden files (dotfiles) by default."
fi

ALIAS_FILE="$HOME/.bash_aliases"
if [ ! -f "$ALIAS_FILE" ]; then
    cat > "$ALIAS_FILE" << 'EOF'
alias update='sudo apt update && sudo apt upgrade -y'
alias install='sudo apt install'
alias remove='sudo apt remove'
alias search='apt search'
alias ..='cd ..'
alias ...='cd ../..'
alias ll='ls -la'
EOF
    print_info "Created ~/.bash_aliases with useful shortcuts."
    print_info "Type 'update' to update your system anytime!"
fi

INFO_SCRIPT="$HOME/.local/bin/system-info"
mkdir -p "$HOME/.local/bin"
cat > "$INFO_SCRIPT" << 'EOF'
#!/bin/bash
echo "========== System Info =========="
echo "OS: $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"')"
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime -p 2>/dev/null || uptime)"
echo "Memory: $(free -h | grep Mem | awk '{print $3 \"/\" $2}')"
echo "Disk Usage:"
df -h / | tail -1 | awk '{print "  Used: " $3 " / " $2 " (" $5 ")"}'
echo "================================="
EOF
chmod +x "$INFO_SCRIPT"

if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    print_info "Added ~/.local/bin to your PATH."
fi

print_success "Final touches applied!"

print_header "Setup Complete!"
echo ""
echo "Here's what was done:"
[ ${#APT_PACKAGES[@]} -gt 0 ] && echo "  - Installed packages: ${APT_PACKAGES[*]}"
[ ${#FLATPAK_PACKAGES[@]} -gt 0 ] && echo "  - Installed Flatpak apps: ${FLATPAK_PACKAGES[*]}"
echo "  - Added useful command aliases (update, install, ll, etc.)"
echo "  - Created system-info command"
echo ""
echo -e "${YELLOW}Please restart your computer for all changes to take effect.${NC}"
echo ""
echo "Useful commands to remember:"
echo "  update    - Update your system"
echo "  ll        - List files with details"
echo "  system-info - Show system information"
echo ""

echo -e "${GREEN}Good luck on your Linux journey!${NC}"

SCRIPT_PATH="${BASH_SOURCE[0]}"
if [ -f "$SCRIPT_PATH" ]; then
    rm -f "$SCRIPT_PATH"
    print_success "Welcome to Linux!"
fi