#!/bin/bash
set -euo pipefail

# ============================================================================
# EC2 Cloud Worker Setup Script
# ============================================================================
# Usage:
#   ssh ec2-instance "bash -s" < setup-ec2.sh
#   scp setup-ec2.sh ec2-instance:~/ && ssh ec2-instance ./setup-ec2.sh
#
# Target: Amazon Linux 2023 / t3.2xlarge (8 vCPU, 32GB RAM)
# Idempotent: Safe to re-run. Skips already-installed components.
# ============================================================================

readonly LOG_FILE="/tmp/setup-ec2-$(date +%Y%m%d-%H%M%S).log"

# --- Logging ---
log()      { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
log_ok()   { log "[OK]   $*"; }
log_skip() { log "[SKIP] $*"; }
log_err()  { log "[ERR]  $*"; }

trap 'log_err "Line $LINENO でエラー発生。ログ: $LOG_FILE"; exit 1' ERR

log "=== Cloud Worker Setup Start ==="
log "Host: $(hostname), User: $(whoami)"
log "OS: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"' || echo 'unknown')"

# --- 1. System update ---
log "System update..."
sudo dnf update -y >> "$LOG_FILE" 2>&1
log_ok "System updated"

# --- 2. Essential tools ---
install_if_missing() {
  local cmd="$1"
  local pkg="${2:-$1}"
  if command -v "$cmd" &>/dev/null; then
    log_skip "$cmd already installed"
  else
    log "Installing $pkg..."
    sudo dnf install -y "$pkg" >> "$LOG_FILE" 2>&1
    log_ok "$pkg installed"
  fi
}

install_if_missing tmux
install_if_missing git
install_if_missing htop
install_if_missing jq
install_if_missing tree
install_if_missing unzip

# --- 3. Node.js (LTS) ---
if command -v node &>/dev/null; then
  log_skip "Node.js already installed ($(node --version))"
else
  log "Installing Node.js LTS..."
  curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash - >> "$LOG_FILE" 2>&1
  sudo dnf install -y nodejs >> "$LOG_FILE" 2>&1
  log_ok "Node.js $(node --version) installed"
fi

# --- 4. Python 3.11+ ---
if python3 --version 2>/dev/null | grep -qE '3\.(1[1-9]|[2-9][0-9])'; then
  log_skip "Python 3.11+ already available ($(python3 --version))"
else
  log "Installing Python 3.11..."
  sudo dnf install -y python3.11 python3.11-pip >> "$LOG_FILE" 2>&1
  sudo alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 >> "$LOG_FILE" 2>&1 || true
  log_ok "Python installed"
fi

# --- 5. Docker ---
if command -v docker &>/dev/null; then
  log_skip "Docker already installed"
else
  log "Installing Docker..."
  sudo dnf install -y docker >> "$LOG_FILE" 2>&1
  log_ok "Docker installed"
fi
sudo systemctl enable docker >> "$LOG_FILE" 2>&1 || true
sudo systemctl start docker >> "$LOG_FILE" 2>&1 || true
if ! groups "$USER" | grep -q docker; then
  sudo usermod -aG docker "$USER"
  log_ok "User $USER added to docker group (re-login required)"
else
  log_skip "User $USER already in docker group"
fi

# --- 6. AWS CLI v2 ---
if command -v aws &>/dev/null; then
  log_skip "AWS CLI already installed"
else
  log "Installing AWS CLI v2..."
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
  unzip -qo /tmp/awscliv2.zip -d /tmp/aws-cli-install >> "$LOG_FILE" 2>&1
  sudo /tmp/aws-cli-install/aws/install >> "$LOG_FILE" 2>&1
  rm -rf /tmp/aws-cli-install /tmp/awscliv2.zip
  log_ok "AWS CLI installed"
fi

# --- 7. CloudWatch Agent (optional) ---
if rpm -q amazon-cloudwatch-agent &>/dev/null 2>&1; then
  log_skip "CloudWatch Agent already installed"
else
  log "Installing CloudWatch Agent..."
  sudo dnf install -y amazon-cloudwatch-agent >> "$LOG_FILE" 2>&1 && \
    log_ok "CloudWatch Agent installed" || \
    log_skip "CloudWatch Agent installation skipped (not critical)"
fi

# --- 8. Directory structure ---
mkdir -p ~/work ~/logs ~/bin
log_ok "Directories: ~/work, ~/logs, ~/bin"

# --- 9. tmux configuration ---
cat > ~/.tmux.conf << 'TMUX_EOF'
# Cloud Worker tmux config
set -g mouse on
set -g history-limit 50000
set -g status-interval 5
set -g status-left-length 40
set -g status-left '#[fg=green]#S #[fg=white]| '
set -g status-right '#[fg=yellow]%Y-%m-%d %H:%M'
set -g default-terminal "screen-256color"
set -g pane-border-style fg=colour240
set -g pane-active-border-style fg=colour51
setw -g window-status-current-style fg=colour81,bold
TMUX_EOF
log_ok "tmux config written"

# --- 10. Log rotation cron (30-day retention) ---
CRON_ENTRY="0 3 * * * find ~/logs -name '*.log' -mtime +30 -delete 2>/dev/null"
if crontab -l 2>/dev/null | grep -qF "find ~/logs"; then
  log_skip "Log rotation cron already configured"
else
  (crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -
  log_ok "Log rotation cron added (30-day retention)"
fi

# --- 11. Shell aliases ---
ALIAS_MARKER="# cloud-worker-aliases"
if grep -qF "$ALIAS_MARKER" ~/.bashrc 2>/dev/null; then
  log_skip "Shell aliases already configured"
else
  cat >> ~/.bashrc << 'ALIAS_EOF'

# cloud-worker-aliases
alias ll='ls -alF'
alias jobs-running='tmux list-sessions 2>/dev/null || echo "No tmux sessions"'
alias disk='df -h / | tail -1'
alias mem='free -h | grep Mem'
ALIAS_EOF
  log_ok "Shell aliases added to ~/.bashrc"
fi

# --- 12. GitHub SSH key check ---
if [ -f ~/.ssh/id_ed25519 ] || [ -f ~/.ssh/id_rsa ]; then
  log_ok "SSH key found"
else
  log "[INFO] SSH key not found. To set up GitHub access:"
  log "  ssh-keygen -t ed25519 -C 'cloud-worker'"
  log "  cat ~/.ssh/id_ed25519.pub  # Add to GitHub"
fi

# --- Summary ---
log ""
log "=== Setup Complete ==="
log "Installed: tmux, git, htop, jq, node, python3, docker, aws-cli"
log "Directories: ~/work, ~/logs, ~/bin"
log "Log rotation: 30-day retention (cron daily 03:00)"
log "Setup log: $LOG_FILE"
log ""
log "Next steps:"
log "  1. Clone repos to ~/work/"
log "  2. Configure AWS credentials: aws configure"
log "  3. (Optional) Set up GitHub SSH key"
