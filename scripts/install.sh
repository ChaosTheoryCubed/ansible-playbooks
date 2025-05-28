#!/bin/sh
set -eu

REPO_URL="https://github.com/ChaosTheoryCubed/dotfiles.git"
DOTFILES_DIR="$HOME/work/dotfiles"

info() {
  printf "\033[1;34m[INFO]\033[0m %s\n" "$@"
}

error() {
  printf "\033[1;31m[ERROR]\033[0m %s\n" "$@" >&2
  exit 1
}

# 1. Detect OS
OS="$(uname)"
info "Detected OS: $OS"

# 2. Install Homebrew (if on macOS)
if [ "$OS" = "Darwin" ]; then
  if ! command -v brew >/dev/null 2>&1; then
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
  fi
fi

# 3. Install Python
if ! command -v python3 >/dev/null 2>&1; then
  info "Installing Python..."

  if [ "$OS" = "Darwin" ]; then
    brew install python
  elif command -v apt >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y python3 python3-pip
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y python3
  else
    error "Unsupported platform for auto-installing Python"
  fi
fi

# 4. Install Ansible
if ! command -v ansible >/dev/null 2>&1; then
  info "Installing Ansible..."

  if [ "$OS" = "Darwin" ]; then
    brew install ansible
  elif command -v apt >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y ansible
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y ansible
  else
    error "Cannot install Ansible automatically on this system."
  fi
fi

# 5. Clone dotfiles
if [ ! -d "$DOTFILES_DIR" ]; then
  info "Cloning dotfiles to $DOTFILES_DIR..."

  # Ensure parent directory exists
  mkdir -p "$(dirname "$DOTFILES_DIR")"

  git clone "$REPO_URL" "$DOTFILES_DIR"
else
  info "Dotfiles already exist at $DOTFILES_DIR"
fi

# 6. Prompt and optionally run Skyplan playbook
SKYPLAN_DIR="$DOTFILES_DIR/ansible-playbooks/skyplan"
cd "$SKYPLAN_DIR"
info "Moved into $SKYPLAN_DIR"

printf "\n❓ Do you want to run the Skyplan Ansible playbook now? [y/N]: "
read -r RUN_PLAYBOOK

if [ "${RUN_PLAYBOOK:-}" = "y" ] || [ "${RUN_PLAYBOOK:-}" = "Y" ]; then
  info "Running Skyplan Ansible playbook..."
  ansible-playbook -i inventory/hosts.ini skyplan.yml --ask-become-pass
else
  info "Skipping playbook run. You can run it later with:"
  echo "    cd \"$SKYPLAN_DIR\" && ansible-playbook -i inventory/hosts.ini skyplan.yml --ask-become-pass"
fi

info "✅ Setup complete!"

