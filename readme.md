# Ansible Playbooks — SkyPlan Dev Environment Setup

Automated macOS developer environment setup for the **SkyPlan / SkyHop** project. One command clones, installs, and configures everything needed to run the full stack locally.

---

## Requirements

- macOS (Darwin) — the playbook is macOS-only
- An interactive shell (not piped)
- A non-root user account with `sudo` privileges
- Internet access

---

## Quick Start

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ChaosTheoryCubed/ansible-playbooks/main/scripts/install.sh)"
```

**Options:**

| Flag | Description |
|------|-------------|
| `--yes` | Skip confirmation prompts and auto-run the playbook |
| `--dry-run` | Print every step without executing anything |
| `--help` | Show usage |

**Manual run (after bootstrap):**

```sh
cd ~/work/ansible-playbooks/ansible-playbooks/skyplan
ansible-playbook -i inventory/hosts.ini skyplan.yml --ask-become-pass
```

---

## What the Bootstrap Script Does (`scripts/install.sh`)

1. Validates it is running interactively and not as root
2. Detects the OS
3. Installs **Homebrew** (macOS) if not present and adds `brew shellenv` to `~/.zprofile`
4. Installs **Python 3** if not present (via `brew`, `apt`, or `yum`)
5. Installs **Ansible** if not present (via `brew`, `apt`, or `yum`)
6. Clones this repo to `~/work/ansible-playbooks` (skips if it already exists)
7. Prompts to run the Skyplan Ansible playbook

---

## Playbook Overview (`skyplan.yml`)

Targets `localhost` via a local connection. Runs the following roles in order:

| # | Role | Purpose |
|---|------|---------|
| 1 | `download_zsh` | Install ZSH via Homebrew; write `SKYHOME`, `PATH`, `DYLD_LIBRARY_PATH`, and `PKG_CONFIG_PATH` into `~/.zshrc` |
| 2 | `setup_ssh` | Generate an ED25519 SSH key if absent; add `github.com` to `known_hosts`; test auth; pause and prompt the user to upload the key if unauthenticated |
| 3 | `download_repos` | Create `~/work/`; clone `go-sky` and `portal-spa` (skyhop-tech org, `develop` branch) with retry logic |
| 4 | `download_node` | Install NVM via Homebrew; add NVM init block to `.zshrc`; install Node.js 24.12.0 and set it as default |
| 5 | `setup_portal_spa` | Run `make install-git-hooks`; copy `.env` and `config/local.js`; run `npm install` in `portal-spa` |
| 6 | `update_hosts` | Append SkyHop service host aliases (`mysql`, `redis`, `aws`, `kibana`, `graph-api`, etc.) pointing to `127.0.0.1` in `/etc/hosts` (requires sudo) |
| 7 | `download_golang` | Remove any Homebrew-managed Go; download Go 1.24.12 tarball (arm64 or amd64); extract to `/usr/local`; add Go and `$GOPATH/bin` to `.zshrc` |
| 8 | `download_docker` | Install Docker Desktop via `brew install --cask docker` if `/Applications/Docker.app` is not present |
| 9 | `download_proto` | Tap `bufbuild/buf`; install `protobuf`, `buf`, and `grpcurl` via Homebrew |
| 10 | `download_atlas` | Install [Atlas CLI](https://atlasgo.io) via the official installer script if `atlas` is not on PATH |
| 11 | `download_pkgconfig` | Install `pkg-config` via Homebrew |
| 12 | `download_imagemagick` | Install build dependencies via Homebrew; download ImageMagick 7.1.1-23 source; compile and install to `/opt` |
| 13 | `download_helm` | Install Helm via Homebrew |
| 14 | `download_go_tools` | Install Go CLI tools via `go install`: `protoc-gen-grpc-gateway`, `protoc-gen-openapiv2`, `protoc-gen-go`, `protoc-gen-go-grpc`, `air`, `gopls`, `dlv`, `staticcheck`, `json2tmux` |
| 15 | `download_devtools` | Install VS Code, Sequel Ace, MySQL, Tmux, CTOP, and Postman via Homebrew (skips each if already installed) |
| 16 | `setup_go_sky_scripts` | Run `make install-git-hooks` in `go-sky`; run `make create-grafana-persistent-volume` in `go-sky/docker` |
| 17 | `setup_go_sky_code_gen` | Run `make gen` in `go-sky/provision` and `go-sky/proto` to generate protobuf and provision code |

---

## Project Structure

```
ansible-playbooks/
  skyplan/
    ansible.cfg           # Ansible config (local connection, optional pretty output plugin)
    skyplan.yml           # Main playbook
    inventory/
      hosts.ini           # Defines [local] group → localhost
    plugins/
      pretty_output.py    # Optional custom stdout callback
    roles/
      download_zsh/       # ZSH install + .zshrc env var setup
      setup_ssh/          # SSH key generation + GitHub auth check
      download_repos/     # Clone go-sky and portal-spa
      download_node/      # NVM + Node.js 24
      setup_portal_spa/   # portal-spa git hooks, .env, config, npm install
      update_hosts/       # /etc/hosts SkyHop service aliases
      download_golang/    # Go 1.24.12 from source tarball
      download_docker/    # Docker Desktop cask
      download_proto/     # protobuf, buf, grpcurl
      download_atlas/     # Atlas CLI
      download_pkgconfig/ # pkg-config
      download_imagemagick/ # ImageMagick 7.1.1-23 built from source
      download_helm/      # Helm via Homebrew
      download_go_tools/  # Go development CLI tools
      download_devtools/  # VS Code, Sequel Ace, MySQL, Tmux, CTOP, Postman
      setup_go_sky_scripts/    # go-sky git hooks + Grafana volume
      setup_go_sky_code_gen/   # Protobuf + provision code generation
scripts/
  install.sh              # Bootstrap: installs Homebrew, Python, Ansible, clones repo, runs playbook
```

---

## Notes

- The playbook targets **macOS only**. Roles that require a specific OS will fail with a clear error on unsupported platforms.
- Roles that install large tools (Go, ImageMagick, Docker) check for existing installations first and skip if already present.
- Git repos are cloned with `update: false` — they will not be pulled if the directory already exists.
- The SSH setup flow pauses and waits for the user to add the generated public key to GitHub before continuing.
- Several roles auto-install Homebrew if it is missing, making each role independently runnable.
- `/etc/hosts` modifications require `sudo` (`become: true`). The playbook will prompt for your password via `--ask-become-pass`.
