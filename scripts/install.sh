#!/bin/sh
set -eu

# -- Permissions & Sudo Validation --
if [ "$(id -u)" -eq 0 ]; then
  echo "❌ Do NOT run this script with sudo or as root."
  echo "   Instead, run it like this:"
  echo "   curl -sSfL https://raw.githubusercontent.com/ChaosTheoryCubed/dotfiles/main/scripts/install.sh | sh"
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  echo "❌ 'sudo' is required but not installed."
  exit 1
fi

if ! sudo -v; then
  echo "❌ You need sudo privileges to run this script."
  exit 1
fi

# -- Configuration --
REPO_URL="https://github.com/ChaosTheoryCubed/dotfiles.git"
DOTFILES_DIR="$HOME/work/dotfiles"
SKYPLAN_DIR="$DOTFILES_DIR/ansible-playbooks/skyplan"
AUTO_RUN=false
DRY_RUN=false

# -- Helpers --
info() {
  printf "\033[1;34m[INFO]\033[0m %s\n" "$@"
}

error() {
  printf "\033[1;31m[ERROR]\033[0m %s\n" "$@" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: install.sh [options]

Options:
  --yes       Auto-run the Skyplan playbook without prompting
  --dry-run   Simulate steps without installing or running anything
  --help      Show this help message
EOF
  exit 0
}

run() {
  if [ "$DRY_RUN" = true ]; then
    echo "DRY-RUN: $*"
  else
    eval "$@"
  fi
}

# -- Parse Arguments --
for arg in "$@"; do
  case "$arg" in
    --yes) AUTO_RUN=true ;;
    --dry-run) DRY_RUN=true ;;
    --help) usage ;;
    *) error "Unknown option: $arg" ;;
  esac
done

# -- Step 1: Detect OS --
OS="$(uname)"
info "Detected OS: $OS"

# -- Step 2: Install Homebrew (macOS only) --
if [ "$OS" = "Darwin" ]; then
  if ! command -v brew >/dev/null 2>&1; then
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  BREW_PREFIX="$(/opt/homebrew/bin/brew --prefix 2>/dev/null || /usr/local/bin/brew --prefix 2>/dev/null || true)"
  BREW_ENV_LINE='eval "$('"$BREW_PREFIX"'/bin/brew shellenv)"'
  ZSHENV_FILE="${ZDOTDIR:-$HOME/.config/zsh}/.zshenv"

  if [ -n "$BREW_PREFIX" ] && ! grep -Fq "$BREW_ENV_LINE" "$ZSHENV_FILE" 2>/dev/null; then
    echo "$BREW_ENV_LINE" >> "$ZSHENV_FILE"
    info "Added brew shellenv to $ZSHENV_FILE"
  fi

  eval "$("$BREW_PREFIX/bin/brew" shellenv)"
fi

# -- Step 3: Install Python --
if ! command -v python3 >/dev/null 2>&1; then
  info "Installing Python..."
  if [ "$OS" = "Darwin" ]; then
    run "brew install python"
  elif command -v apt >/dev/null 2>&1; then
    run "sudo apt update"
    run "sudo apt install -y python3 python3-pip"
  elif command -v yum >/dev/null 2>&1; then
    run "sudo yum install -y python3"
  else
    error "Unsupported platform for auto-installing Python"
  fi
fi

# -- Step 4: Install Ansible --
if ! command -v ansible >/dev/null 2>&1; then
  info "Installing Ansible..."
  if [ "$OS" = "Darwin" ]; then
    run "brew install ansible"
  elif command -v apt >/dev/null 2>&1; then
    run "sudo apt install -y ansible"
  elif command -v yum >/dev/null 2>&1; then
    run "sudo yum install -y ansible"
  else
    error "Cannot install Ansible automatically on this system."
  fi
fi

# -- Step 5: Clone dotfiles repo --
if [ ! -d "$DOTFILES_DIR" ]; then
  info "Cloning dotfiles to $DOTFILES_DIR..."
  DOTFILES_PARENT="$(dirname "$DOTFILES_DIR")"
  if [ "$DRY_RUN" = true ]; then
    echo "DRY-RUN: mkdir -p \"$DOTFILES_PARENT\""
    echo "DRY-RUN: git clone \"$REPO_URL\" \"$DOTFILES_DIR\""
  else
    mkdir -p "$DOTFILES_PARENT"
    git clone "$REPO_URL" "$DOTFILES_DIR"
  fi
else
  info "Dotfiles already exist at $DOTFILES_DIR"
fi

# -- Step 6: Prompt to run Ansible playbook --
cd "$SKYPLAN_DIR"
info "Moved into $SKYPLAN_DIR"

if [ "$AUTO_RUN" = true ]; then
  RUN_PLAYBOOK="y"
elif [ "$DRY_RUN" = true ]; then
  RUN_PLAYBOOK="n"
else
  printf "\n❓ Do you want to run the Skyplan Ansible playbook now? [y/N]: "
  read -r RUN_PLAYBOOK
fi

if [ "$RUN_PLAYBOOK" = "y" ] || [ "$RUN_PLAYBOOK" = "Y" ]; then
  info "Running Skyplan Ansible playbook..."
  run "ansible-playbook -i inventory/hosts.ini skyplan.yml --ask-become-pass"
else
  info "Skipping playbook run. You can run it later with:"
  echo "    cd \"$SKYPLAN_DIR\" && ansible-playbook -i inventory/hosts.ini skyplan.yml --ask-become-pass"
fi

info "✅ Setup complete!"

