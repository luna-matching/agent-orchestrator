#!/bin/bash
set -euo pipefail

# ============================================================================
# Cloud Job Orchestrator CLI
# ============================================================================
# Usage:
#   orch run <name> <command>      # Start cloud job
#   orch logs <name> [-f|--follow] # View logs
#   orch attach <name>             # Attach to tmux session
#   orch stop <name>               # Stop job
#   orch status                    # List running jobs
#   orch list                      # All job history
#   orch ssh                       # Open SSH session to cloud
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# --- Load config ---
if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
else
  echo -e "${RED}エラー: ${ENV_FILE} が見つかりません${NC}"
  echo "  cp ${SCRIPT_DIR}/.env.example ${ENV_FILE}"
  echo "  # CLOUD_HOST 等を設定してください"
  exit 1
fi

CLOUD_HOST="${CLOUD_HOST:?CLOUD_HOST が未設定です。.env を確認してください}"
CLOUD_USER="${CLOUD_USER:-ec2-user}"
CLOUD_WORK_DIR="${CLOUD_WORK_DIR:-~/work}"
CLOUD_LOG_DIR="${CLOUD_LOG_DIR:-~/logs}"

# --- SSH command builder ---
build_ssh_cmd() {
  local cmd="ssh"
  [ -n "${CLOUD_KEY:-}" ] && cmd="$cmd -i $CLOUD_KEY"
  [ -n "${SSH_OPTIONS:-}" ] && cmd="$cmd $SSH_OPTIONS"
  cmd="$cmd ${CLOUD_USER}@${CLOUD_HOST}"
  echo "$cmd"
}

SSH_CMD="$(build_ssh_cmd)"

remote() {
  $SSH_CMD "$@"
}

remote_tty() {
  local cmd="ssh -t"
  [ -n "${CLOUD_KEY:-}" ] && cmd="$cmd -i $CLOUD_KEY"
  [ -n "${SSH_OPTIONS:-}" ] && cmd="$cmd $SSH_OPTIONS"
  $cmd "${CLOUD_USER}@${CLOUD_HOST}" "$@"
}

# --- Commands ---

cmd_run() {
  if [ $# -lt 2 ]; then
    echo -e "${RED}エラー: ジョブ名とコマンドが必要です${NC}"
    echo "  orch run <name> <command>"
    echo "  例: orch run my-build \"cd ~/work/project && npm run build\""
    exit 1
  fi

  local name="$1"; shift
  local cmd="$*"
  local log_dir="${CLOUD_LOG_DIR}/${name}"
  local log_file="${log_dir}/run.log"
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

  # Check if session already exists
  if remote "tmux has-session -t '${name}' 2>/dev/null"; then
    echo -e "${YELLOW}警告: セッション '${name}' は既に存在します${NC}"
    echo "  orch attach ${name}  # アタッチ"
    echo "  orch stop ${name}    # 停止してから再実行"
    exit 1
  fi

  echo -e "${CYAN}Cloud job starting: ${BOLD}${name}${NC}"
  echo -e "  Host: ${CLOUD_HOST}"
  echo -e "  Command: ${cmd}"

  # Create log directory and start tmux session
  remote "mkdir -p '${log_dir}'"
  remote "echo '[START: ${timestamp}]' > '${log_file}' && \
    echo '[COMMAND: ${cmd}]' >> '${log_file}' && \
    echo '---' >> '${log_file}' && \
    tmux new-session -d -s '${name}' \
      \"cd ${CLOUD_WORK_DIR} 2>/dev/null; { ${cmd}; } 2>&1 | tee -a '${log_file}'; EXIT_CODE=\\\$?; echo '' >> '${log_file}'; echo '[EXIT: '\\\$EXIT_CODE']' >> '${log_file}'; exec bash\""

  echo ""
  echo -e "${GREEN}Job '${name}' started${NC}"
  echo -e "  ${CYAN}orch logs ${name} -f${NC}   # ログをフォロー"
  echo -e "  ${CYAN}orch attach ${name}${NC}    # セッションにアタッチ"
  echo -e "  ${CYAN}orch stop ${name}${NC}      # 停止"
}

cmd_logs() {
  if [ $# -lt 1 ]; then
    echo -e "${RED}エラー: ジョブ名が必要です${NC}"
    echo "  orch logs <name> [-f|--follow]"
    exit 1
  fi

  local name="$1"; shift
  local follow=false
  for arg in "$@"; do
    case "$arg" in
      -f|--follow) follow=true ;;
    esac
  done

  local log_file="${CLOUD_LOG_DIR}/${name}/run.log"

  if [ "$follow" = true ]; then
    echo -e "${CYAN}Streaming logs for: ${BOLD}${name}${NC} (Ctrl+C to stop)"
    remote "tail -f '${log_file}' 2>/dev/null || echo 'ログファイルが見つかりません: ${log_file}'"
  else
    remote "cat '${log_file}' 2>/dev/null || echo 'ログファイルが見つかりません: ${log_file}'"
  fi
}

cmd_attach() {
  if [ $# -lt 1 ]; then
    echo -e "${RED}エラー: ジョブ名が必要です${NC}"
    echo "  orch attach <name>"
    exit 1
  fi

  local name="$1"

  if ! remote "tmux has-session -t '${name}' 2>/dev/null"; then
    echo -e "${RED}エラー: セッション '${name}' が見つかりません${NC}"
    echo "  orch status  # 稼働中のジョブを確認"
    exit 1
  fi

  echo -e "${CYAN}Attaching to: ${BOLD}${name}${NC} (detach: Ctrl+B, D)"
  remote_tty "tmux attach -t '${name}'"
}

cmd_stop() {
  if [ $# -lt 1 ]; then
    echo -e "${RED}エラー: ジョブ名が必要です${NC}"
    echo "  orch stop <name>"
    exit 1
  fi

  local name="$1"

  if remote "tmux has-session -t '${name}' 2>/dev/null"; then
    remote "tmux kill-session -t '${name}'"
    echo -e "${GREEN}Job '${name}' stopped${NC}"

    # Record stop in log
    local log_file="${CLOUD_LOG_DIR}/${name}/run.log"
    remote "echo '[STOPPED: $(date '+%Y-%m-%d %H:%M:%S')]' >> '${log_file}' 2>/dev/null" || true
  else
    echo -e "${YELLOW}セッション '${name}' は存在しません（既に停止済み）${NC}"
  fi
}

cmd_status() {
  echo -e "${BOLD}=== Cloud Jobs ===${NC}"
  echo -e "Host: ${CYAN}${CLOUD_HOST}${NC}"
  echo ""

  local sessions
  sessions=$(remote "tmux list-sessions -F '#{session_name}|#{session_created}|#{session_activity}' 2>/dev/null" || true)

  if [ -z "$sessions" ]; then
    echo -e "${YELLOW}稼働中のジョブはありません${NC}"
    return
  fi

  printf "${BOLD}%-25s %-8s %-20s %s${NC}\n" "NAME" "STATE" "STARTED" "LAST ACTIVITY"
  echo "─────────────────────────────────────────────────────────────────────"

  while IFS='|' read -r name created activity; do
    local started_fmt
    started_fmt=$(remote "date -d @${created} '+%Y-%m-%d %H:%M:%S' 2>/dev/null" || echo "$created")
    local activity_fmt
    activity_fmt=$(remote "date -d @${activity} '+%H:%M:%S' 2>/dev/null" || echo "$activity")
    printf "${GREEN}%-25s${NC} %-8s %-20s %s\n" "$name" "RUNNING" "$started_fmt" "$activity_fmt"
  done <<< "$sessions"

  echo ""

  # Memory usage
  echo -e "${BOLD}System:${NC}"
  remote "free -h | head -2" 2>/dev/null || true
}

cmd_list() {
  echo -e "${BOLD}=== Job History ===${NC}"
  echo ""

  local dirs
  dirs=$(remote "ls -dt ${CLOUD_LOG_DIR}/*/ 2>/dev/null | head -20" || true)

  if [ -z "$dirs" ]; then
    echo -e "${YELLOW}ジョブ履歴がありません${NC}"
    return
  fi

  printf "${BOLD}%-25s %-10s %-20s %s${NC}\n" "NAME" "STATUS" "LAST MODIFIED" "LOG SIZE"
  echo "─────────────────────────────────────────────────────────────────────"

  while IFS= read -r dir; do
    local name
    name=$(basename "$dir")
    local log_file="${dir}run.log"

    local status="UNKNOWN"
    local last_line
    last_line=$(remote "tail -1 '${log_file}' 2>/dev/null" || echo "")
    if echo "$last_line" | grep -q '\[EXIT: 0\]'; then
      status="${GREEN}DONE${NC}"
    elif echo "$last_line" | grep -q '\[EXIT:'; then
      status="${RED}FAILED${NC}"
    elif echo "$last_line" | grep -q '\[STOPPED'; then
      status="${YELLOW}STOPPED${NC}"
    elif remote "tmux has-session -t '${name}' 2>/dev/null"; then
      status="${GREEN}RUNNING${NC}"
    fi

    local modified
    modified=$(remote "stat -c '%y' '${log_file}' 2>/dev/null | cut -d. -f1" || echo "unknown")
    local size
    size=$(remote "du -sh '${log_file}' 2>/dev/null | cut -f1" || echo "?")

    printf "%-25s ${status}%-$(( 10 - 9 ))s %-20s %s\n" "$name" "" "$modified" "$size"
  done <<< "$dirs"
}

cmd_ssh() {
  echo -e "${CYAN}Opening SSH session to: ${BOLD}${CLOUD_HOST}${NC}"
  remote_tty "cd ${CLOUD_WORK_DIR} 2>/dev/null; exec bash -l"
}

cmd_help() {
  cat << 'HELP'
Cloud Job Orchestrator - クラウドジョブ管理CLI

Usage:
  orch <command> [arguments]

Commands:
  run <name> <cmd>      ジョブを起動（tmux detached）
  logs <name> [-f]      ログを表示（-f: follow）
  attach <name>         tmuxセッションにアタッチ
  stop <name>           ジョブを停止
  status                稼働中のジョブ一覧
  list                  全ジョブ履歴
  ssh                   EC2にSSH接続
  help                  このヘルプを表示

Examples:
  orch run my-build "cd ~/work/project && npm run build"
  orch run lros-train "cd ~/work/lros && python train.py"
  orch logs my-build -f
  orch attach my-build
  orch status
  orch stop my-build

Configuration:
  Edit scripts/cloud/.env (copy from .env.example)

HELP
}

# --- Main ---
COMMAND="${1:-help}"
shift 2>/dev/null || true

case "$COMMAND" in
  run)    cmd_run "$@" ;;
  logs)   cmd_logs "$@" ;;
  attach) cmd_attach "$@" ;;
  stop)   cmd_stop "$@" ;;
  status) cmd_status ;;
  list)   cmd_list ;;
  ssh)    cmd_ssh ;;
  help|--help|-h) cmd_help ;;
  *)
    echo -e "${RED}不明なコマンド: ${COMMAND}${NC}"
    cmd_help
    exit 1
    ;;
esac
