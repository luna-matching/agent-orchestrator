#!/bin/bash
set -euo pipefail

# ============================================================================
# EC2 CLI Wrapper
# ============================================================================
# Usage:
#   ec2 run <command>        # EC2上でコマンド実行（tmux バックグラウンド）
#   ec2 ssh                  # EC2にSSH接続
#   ec2 status               # インスタンス状態 + tmux セッション一覧
#   ec2 start                # インスタンス起動
#   ec2 stop                 # インスタンス停止（課金停止）
#   ec2 list                 # tmux セッション（ジョブ）一覧
#   ec2 logs <session> [-f]  # ジョブログ表示
#   ec2 help                 # ヘルプ
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
fi

EC2_HOST="${EC2_HOST:-}"
EC2_USER="${EC2_USER:-ec2-user}"
EC2_KEY="${EC2_KEY:-}"
EC2_WORK_DIR="${EC2_WORK_DIR:-/home/ec2-user/work}"
EC2_LOG_DIR="${EC2_LOG_DIR:-/home/ec2-user/logs}"
EC2_INSTANCE_ID="${EC2_INSTANCE_ID:-}"
EC2_REGION="${EC2_REGION:-ap-northeast-1}"
AWS_PROFILE="${AWS_PROFILE:-}"

# --- Helper: build SSH command ---
build_ssh_cmd() {
  local cmd="ssh"
  if [ -n "$EC2_KEY" ]; then
    cmd="$cmd -i $EC2_KEY"
  fi
  cmd="$cmd -o StrictHostKeyChecking=no -o ConnectTimeout=10"
  cmd="$cmd ${EC2_USER}@${EC2_HOST}"
  echo "$cmd"
}

# --- Helper: build AWS CLI base ---
build_aws_cmd() {
  local cmd="aws"
  if [ -n "$AWS_PROFILE" ]; then
    cmd="$cmd --profile $AWS_PROFILE"
  fi
  cmd="$cmd --region $EC2_REGION"
  echo "$cmd"
}

# --- Checks ---
check_host() {
  if [ -z "$EC2_HOST" ]; then
    echo -e "${RED}エラー: EC2_HOST が設定されていません${NC}"
    echo "  scripts/cloud/.env に EC2_HOST を設定してください"
    exit 1
  fi
}

check_instance_id() {
  if [ -z "$EC2_INSTANCE_ID" ]; then
    echo -e "${RED}エラー: EC2_INSTANCE_ID が設定されていません${NC}"
    echo "  scripts/cloud/.env に EC2_INSTANCE_ID を設定してください"
    exit 1
  fi
}

check_aws_cli() {
  if ! command -v aws &>/dev/null; then
    echo -e "${RED}エラー: AWS CLI がインストールされていません${NC}"
    echo "  brew install awscli"
    exit 1
  fi
}

# --- Commands ---

cmd_run() {
  check_host

  if [ $# -lt 1 ]; then
    echo -e "${RED}エラー: 実行するコマンドが必要です${NC}"
    echo "  ec2 run <command>"
    echo "  例: ec2 run \"cd /workspaces/project && npm run build\""
    exit 1
  fi

  local user_cmd="$*"
  local session_name="job-$(date +%Y%m%d-%H%M%S)"
  local log_file="${EC2_LOG_DIR}/${session_name}.log"
  local ssh_cmd
  ssh_cmd=$(build_ssh_cmd)

  echo -e "${CYAN}EC2 でコマンド実行: ${BOLD}${user_cmd}${NC}"
  echo -e "  Host: ${EC2_HOST}"
  echo -e "  Session: ${session_name}"
  echo -e "  Log: ${log_file}"
  echo ""

  # リモートでログディレクトリ作成 + tmux バックグラウンド実行
  $ssh_cmd bash -c "
    mkdir -p '${EC2_LOG_DIR}'
    cd '${EC2_WORK_DIR}' 2>/dev/null || true
    tmux new-session -d -s '${session_name}' \"bash -c '( ${user_cmd} ) 2>&1 | tee ${log_file}; echo \\\"\\n[exit: \\\$?]\\\" >> ${log_file}'\"
  "

  local exit_code=$?
  if [ $exit_code -eq 0 ]; then
    echo -e "${GREEN}ジョブを開始しました${NC}"
    echo -e "  ${CYAN}ec2 logs ${session_name}${NC}      # ログ確認"
    echo -e "  ${CYAN}ec2 logs ${session_name} -f${NC}   # リアルタイムログ"
    echo -e "  ${CYAN}ec2 list${NC}                      # ジョブ一覧"
  else
    echo -e "${RED}ジョブの開始に失敗しました (exit: ${exit_code})${NC}"
    exit $exit_code
  fi
}

cmd_ssh() {
  check_host

  echo -e "${CYAN}EC2 にSSH接続: ${BOLD}${EC2_USER}@${EC2_HOST}${NC}"

  local ssh_cmd
  ssh_cmd=$(build_ssh_cmd)
  $ssh_cmd
}

cmd_status() {
  echo -e "${BOLD}=== EC2 Status ===${NC}"
  echo ""

  # --- インスタンス情報 ---
  if [ -n "$EC2_INSTANCE_ID" ]; then
    check_aws_cli

    local aws_cmd
    aws_cmd=$(build_aws_cmd)

    local instance_info
    instance_info=$($aws_cmd ec2 describe-instances \
      --instance-ids "$EC2_INSTANCE_ID" \
      --query 'Reservations[0].Instances[0].{State:State.Name,Type:InstanceType,PublicIp:PublicIpAddress,LaunchTime:LaunchTime}' \
      --output json 2>/dev/null || echo '{}')

    if [ "$instance_info" != "{}" ] && [ -n "$instance_info" ]; then
      local state type public_ip launch_time
      state=$(echo "$instance_info" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('State','unknown'))" 2>/dev/null || echo "unknown")
      type=$(echo "$instance_info" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('Type','unknown'))" 2>/dev/null || echo "unknown")
      public_ip=$(echo "$instance_info" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('PublicIp','N/A') or 'N/A')" 2>/dev/null || echo "N/A")
      launch_time=$(echo "$instance_info" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('LaunchTime','N/A') or 'N/A')" 2>/dev/null || echo "N/A")

      local state_color="$CYAN"
      case "$state" in
        running) state_color="$GREEN" ;;
        stopped) state_color="$YELLOW" ;;
        terminated) state_color="$RED" ;;
      esac

      printf "${BOLD}%-18s${NC} %s\n" "Instance ID:" "$EC2_INSTANCE_ID"
      printf "${BOLD}%-18s${NC} ${state_color}%s${NC}\n" "State:" "$state"
      printf "${BOLD}%-18s${NC} %s\n" "Type:" "$type"
      printf "${BOLD}%-18s${NC} %s\n" "Public IP:" "$public_ip"
      printf "${BOLD}%-18s${NC} %s\n" "Launch Time:" "$launch_time"
      printf "${BOLD}%-18s${NC} %s\n" "Region:" "$EC2_REGION"
    else
      echo -e "${YELLOW}インスタンス情報を取得できませんでした${NC}"
    fi
  else
    echo -e "${YELLOW}EC2_INSTANCE_ID が未設定（インスタンス情報をスキップ）${NC}"
  fi

  echo ""

  # --- tmux セッション ---
  if [ -n "$EC2_HOST" ]; then
    echo -e "${BOLD}--- Active Jobs (tmux sessions) ---${NC}"
    echo ""

    local ssh_cmd
    ssh_cmd=$(build_ssh_cmd)
    local sessions
    sessions=$($ssh_cmd "tmux list-sessions 2>/dev/null" 2>/dev/null || true)

    if [ -n "$sessions" ]; then
      echo "$sessions"
    else
      echo -e "${YELLOW}実行中のジョブはありません${NC}"
    fi
  fi
}

cmd_start() {
  check_instance_id
  check_aws_cli

  local aws_cmd
  aws_cmd=$(build_aws_cmd)

  echo -e "${CYAN}EC2 インスタンスを起動中: ${BOLD}${EC2_INSTANCE_ID}${NC}"

  $aws_cmd ec2 start-instances --instance-ids "$EC2_INSTANCE_ID" > /dev/null 2>&1
  echo -e "${YELLOW}起動リクエスト送信済み。状態確認中...${NC}"

  $aws_cmd ec2 wait instance-running --instance-ids "$EC2_INSTANCE_ID" 2>/dev/null || true

  # 新しい Public IP を取得
  local new_ip
  new_ip=$($aws_cmd ec2 describe-instances \
    --instance-ids "$EC2_INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text 2>/dev/null || echo "N/A")

  echo ""
  echo -e "${GREEN}EC2 インスタンスが起動しました${NC}"
  echo -e "  Instance: ${EC2_INSTANCE_ID}"
  echo -e "  Public IP: ${BOLD}${new_ip}${NC}"
  echo ""
  echo -e "  ${CYAN}ec2 ssh${NC}       # SSH接続"
  echo -e "  ${CYAN}ec2 run <cmd>${NC}  # コマンド実行"
  echo -e "  ${CYAN}ec2 stop${NC}      # 停止（課金停止）"
}

cmd_stop() {
  check_instance_id
  check_aws_cli

  local aws_cmd
  aws_cmd=$(build_aws_cmd)

  echo -e "${CYAN}EC2 インスタンスを停止中: ${BOLD}${EC2_INSTANCE_ID}${NC}"

  $aws_cmd ec2 stop-instances --instance-ids "$EC2_INSTANCE_ID" > /dev/null 2>&1

  echo -e "${GREEN}EC2 インスタンス '${EC2_INSTANCE_ID}' を停止しました（課金停止）${NC}"
}

cmd_delete() {
  check_instance_id
  check_aws_cli

  local aws_cmd
  aws_cmd=$(build_aws_cmd)

  echo -e "${RED}EC2 インスタンスを終了（terminate）します: ${BOLD}${EC2_INSTANCE_ID}${NC}"
  echo -e "${YELLOW}警告: この操作は取り消せません。インスタンスは完全に削除されます。${NC}"
  echo ""

  read -r -p "本当に実行しますか？ (yes/no): " confirm
  if [ "$confirm" != "yes" ]; then
    echo -e "${YELLOW}キャンセルしました${NC}"
    exit 0
  fi

  $aws_cmd ec2 terminate-instances --instance-ids "$EC2_INSTANCE_ID" > /dev/null 2>&1

  echo -e "${GREEN}EC2 インスタンス '${EC2_INSTANCE_ID}' を終了しました${NC}"
}

cmd_list() {
  check_host

  echo -e "${BOLD}=== EC2 Jobs (tmux sessions) ===${NC}"
  echo ""

  local ssh_cmd
  ssh_cmd=$(build_ssh_cmd)
  local sessions
  sessions=$($ssh_cmd "tmux list-sessions 2>/dev/null" 2>/dev/null || true)

  if [ -z "$sessions" ]; then
    echo -e "${YELLOW}実行中のジョブはありません${NC}"
    return
  fi

  echo "$sessions"
  echo ""
  echo -e "  ${CYAN}ec2 logs <session>${NC}      # ログ確認"
  echo -e "  ${CYAN}ec2 logs <session> -f${NC}   # リアルタイムログ"
}

cmd_logs() {
  check_host

  if [ $# -lt 1 ]; then
    echo -e "${RED}エラー: セッション名が必要です${NC}"
    echo "  ec2 logs <session> [-f]"
    echo "  ec2 list  # セッション一覧を確認"
    exit 1
  fi

  local session_name="$1"
  local follow="${2:-}"
  local log_file="${EC2_LOG_DIR}/${session_name}.log"
  local ssh_cmd
  ssh_cmd=$(build_ssh_cmd)

  if [ "$follow" = "-f" ]; then
    echo -e "${CYAN}ログをリアルタイム表示: ${BOLD}${log_file}${NC}"
    echo -e "  Ctrl+C で終了"
    echo ""
    $ssh_cmd "tail -f '${log_file}'"
  else
    echo -e "${CYAN}ログ表示: ${BOLD}${log_file}${NC}"
    echo ""
    $ssh_cmd "cat '${log_file}'" 2>/dev/null || echo -e "${RED}ログファイルが見つかりません: ${log_file}${NC}"
  fi
}

cmd_help() {
  cat << 'HELP'
EC2 CLI Wrapper - Amazon EC2 管理CLI

Usage:
  ec2 <command> [arguments]

Commands:
  run <command>          EC2上でコマンド実行（tmux バックグラウンド）
  ssh                    EC2にSSH接続
  status                 インスタンス状態 + ジョブ一覧
  start                  インスタンス起動
  stop                   インスタンス停止（課金停止）
  delete                 インスタンス終了（完全削除）
  list                   ジョブ（tmux セッション）一覧
  logs <session> [-f]    ジョブログ表示（-f: リアルタイム）
  help                   このヘルプを表示

Job Management:
  run でコマンドを実行すると tmux セッションとしてバックグラウンド実行。
  ログは EC2_LOG_DIR/<session>.log に保存。

  ec2 run "npm run build"         # ジョブ実行
  ec2 list                        # ジョブ一覧
  ec2 logs job-20260216-123456    # ログ確認
  ec2 logs job-20260216-123456 -f # リアルタイムログ

AWS Operations:
  start/stop/status/delete は AWS CLI + EC2_INSTANCE_ID が必要。

Examples:
  ec2 start                       # インスタンス起動
  ec2 run "cd /workspaces/lros && npm run build"
  ec2 ssh
  ec2 status
  ec2 stop

Configuration:
  Edit scripts/cloud/.env (copy from .env.example)

  EC2_HOST              EC2のホスト名またはIP
  EC2_USER              SSHユーザー名（デフォルト: ec2-user）
  EC2_KEY               SSH秘密鍵パス（未設定なら -i なし）
  EC2_WORK_DIR          作業ディレクトリ
  EC2_LOG_DIR           ログディレクトリ
  EC2_INSTANCE_ID       インスタンスID（start/stop/statusに必要）
  EC2_REGION            AWSリージョン（デフォルト: ap-northeast-1）
  AWS_PROFILE           AWSプロファイル（未設定ならデフォルト）

HELP
}

# --- Main ---
COMMAND="${1:-help}"
shift 2>/dev/null || true

case "$COMMAND" in
  run)     cmd_run "$@" ;;
  ssh)     cmd_ssh ;;
  status)  cmd_status ;;
  start)   cmd_start ;;
  stop)    cmd_stop ;;
  delete)  cmd_delete "$@" ;;
  list)    cmd_list ;;
  logs)    cmd_logs "$@" ;;
  help|--help|-h) cmd_help ;;
  *)
    echo -e "${RED}不明なコマンド: ${COMMAND}${NC}"
    cmd_help
    exit 1
    ;;
esac
