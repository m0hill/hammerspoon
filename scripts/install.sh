#!/bin/bash
# Power Spoons One-liner Installer
# Usage: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/<user>/power-spoons/main/scripts/install.sh)"

set -e

REPO_URL="https://github.com/<user>/power-spoons.git"
INSTALL_DIR="$HOME/.power-spoons"
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                       ║${NC}"
echo -e "${BLUE}║      Power Spoons Installer 🚀        ║${NC}"
echo -e "${BLUE}║   Hammerspoon Package Manager         ║${NC}"
echo -e "${BLUE}║                                       ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"
echo ""

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}✗ This installer only works on macOS${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Running on macOS"

# Check if Homebrew is installed (needed for some spoon dependencies like sox)
if ! command -v brew &> /dev/null; then
    echo -e "${YELLOW}⚠${NC} Homebrew not found"
    echo -e "${BLUE}ℹ${NC} Installing Homebrew (needed for some spoon dependencies)..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for Apple Silicon Macs
    if [[ $(uname -m) == "arm64" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
fi

echo -e "${GREEN}✓${NC} Homebrew is installed"

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo -e "${YELLOW}⚠${NC} Python 3 not found"
    echo -e "${BLUE}ℹ${NC} Installing Python 3..."
    brew install python3
fi

echo -e "${GREEN}✓${NC} Python 3 is installed"

# Clone or update the repository
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}⚠${NC} Power Spoons already installed at $INSTALL_DIR"
    echo -e "${BLUE}ℹ${NC} Updating repository..."
    cd "$INSTALL_DIR"
    git pull
else
    echo -e "${BLUE}ℹ${NC} Cloning power-spoons repository..."
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

echo -e "${GREEN}✓${NC} Repository ready at $INSTALL_DIR"

# Add hs-pm to PATH
SHELL_RC=""
if [[ "$SHELL" == *"zsh"* ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ "$SHELL" == *"bash"* ]]; then
    SHELL_RC="$HOME/.bashrc"
fi

if [ -n "$SHELL_RC" ]; then
    if ! grep -q "power-spoons/scripts" "$SHELL_RC" 2>/dev/null; then
        echo "" >> "$SHELL_RC"
        echo "# Power Spoons Package Manager" >> "$SHELL_RC"
        echo "export PATH=\"\$HOME/.power-spoons/scripts:\$PATH\"" >> "$SHELL_RC"
        echo -e "${GREEN}✓${NC} Added hs-pm to PATH in $SHELL_RC"
        echo -e "${YELLOW}⚠${NC} Run 'source $SHELL_RC' or restart your terminal to use hs-pm"
    else
        echo -e "${GREEN}✓${NC} hs-pm already in PATH"
    fi
fi

# Export for current session
export PATH="$HOME/.power-spoons/scripts:$PATH"

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                       ║${NC}"
echo -e "${GREEN}║   Installation Complete! ✨           ║${NC}"
echo -e "${GREEN}║                                       ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "  1. Run: ${YELLOW}hs-pm init${NC} to configure Hammerspoon"
echo -e "  2. Or reload your shell first: ${YELLOW}source $SHELL_RC${NC}"
echo ""
echo -e "${BLUE}Other commands:${NC}"
echo -e "  ${YELLOW}hs-pm list${NC}       - List installed spoons"
echo -e "  ${YELLOW}hs-pm available${NC}  - Show all available spoons"
echo -e "  ${YELLOW}hs-pm add <name>${NC} - Install a spoon"
echo -e "  ${YELLOW}hs-pm remove <name>${NC} - Remove a spoon"
echo -e "  ${YELLOW}hs-pm update${NC}     - Update to latest version"
echo ""
