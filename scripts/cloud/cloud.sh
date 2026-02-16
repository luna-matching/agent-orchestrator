#!/bin/bash
set -euo pipefail

# ============================================================================
# Cloud CLI Router
# ============================================================================
# 統一インターフェースで Codespaces / EC2 を切り替え。
# .env の CLOUD_PROVIDER で制御。
#
# Usage:
#   cloud run <command>     # コマンド実行
#   cloud ssh               # SSH接続
#   cloud status            # 状態確認
#   cloud start [args...]   # リソース起動
#   cloud stop [name]       # リソース停止
#   cloud delete [name]     # リソース削除
#   cloud list              # ジョブ一覧
#   cloud logs <name> [-f]  # ログ表示（EC2のみ）
#   cloud provider          # 現在のプロバイダ表示
#   cloud help
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

CLOUD_PROVIDER="${CLOUD_PROVIDER:-codespaces}"

CODESPACE_SCRIPT="${SCRIPT_DIR}/codespace.sh"
EC2_SCRIPT="${SCRIPT_DIR}/ec2.sh"

check_provider_script() {
  local provider="$1"
  local script=""
  case "$provider" in
    codespaces) script="$CODESPACE_SCRIPT" ;;
    ec2) script="$EC2_SCRIPT" ;;
    *)
      echo -e "${RED}不明なプロバイダ: ${provider}${NC}"
      echo "  CLOUD_PROVIDER は 'codespaces' または 'ec2' を設定してください"
      exit 1
      ;;
  esac
  if [ ! -f "$script" ]; then
    echo -e "${RED}プロバイダスクリプトが見つかりません: ${script}${NC}"
    exit 1
  fi
  echo "$script"
}

delegate() {
  local command="$1"
  shift
  local script
  script=$(check_provider_script "$CLOUD_PROVIDER")

  local mapped_command="$command"
  if [ "$CLOUD_PROVIDER" = "codespaces" ]; then
    case "$command" in
      start) mapped_command="create" ;;
    esac
  fi

  bash "$script" "$mapped_command" "$@"
}

cmd_provider() {
  echo -e "${BOLD}=== Cloud Provider ===${NC}"
  echo ""
  echo -e "  現在のプロバイダ: ${GREEN}${BOLD}${CLOUD_PROVIDER}${NC}"
  echo ""
  echo -e "${BOLD}切り替え方法:${NC}"
  echo "  scripts/cloud/.env の CLOUD_PROVIDER を編集"
  echo ""
  echo -e "${BOLD}利用可能なプロバイダ:${NC}"
  printf "  ${CYAN}%-15s${NC} %s\n" "codespaces" "GitHub Codespaces（ゼロ運用、自動サスペンド）"
  printf "  ${CYAN}%-15s${NC} %s\n" "ec2" "Amazon EC2（長時間実行、GPU、カスタム環境）"
}

cmd_help() {
  cat << 'HELP'
Cloud CLI Router - クラウド実行基盤の統一インターフェース

Usage:
  cloud <command> [arguments]

Commands:
  run <command>      クラウドでコマンド実行
  ssh                クラウドにSSH接続
  status             リソースの状態確認
  start [args...]    リソース起動（EC2: start / Codespaces: create）
  stop [name]        リソース停止（課金停止）
  delete [name]      リソース削除
  list               ジョブ一覧
  logs <name> [-f]   ログ表示（EC2のみ）
  provider           現在のプロバイダを表示
  help               このヘルプを表示

Provider:
  scripts/cloud/.env の CLOUD_PROVIDER で切り替え

  codespaces    GitHub Codespaces（デフォルト）
                - ゼロ運用、自動サスペンド、GitHub連携
                - $0.36-1.44/hr + storage

  ec2           Amazon EC2
                - 長時間実行、GPU、カスタム環境
                - インスタンス時間課金

Examples:
  cloud start --repo luna-matching/lros
  cloud run "npm run build"
  cloud status
  cloud stop

Configuration:
  cp scripts/cloud/.env.example scripts/cloud/.env

HELP
}

COMMAND="${1:-help}"
shift 2>/dev/null || true

case "$COMMAND" in
  run)      delegate run "$@" ;;
  ssh)      delegate ssh "$@" ;;
  status)   delegate status "$@" ;;
  start)    delegate start "$@" ;;
  stop)     delegate stop "$@" ;;
  delete)   delegate delete "$@" ;;
  list)     delegate list "$@" ;;
  logs)     delegate logs "$@" ;;
  provider) cmd_provider ;;
  help|--help|-h) cmd_help ;;
  *)
    echo -e "${RED}不明なコマンド: ${COMMAND}${NC}"
    cmd_help
    exit 1
    ;;
esac
