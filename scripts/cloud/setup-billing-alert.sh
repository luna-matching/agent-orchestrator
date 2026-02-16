#!/bin/bash
set -euo pipefail

# ============================================================================
# AWS Billing Alert Setup
# ============================================================================
# CloudWatch で月額課金アラートを設定する。
#
# 前提:
#   - AWS CLI がインストール済み
#   - Billing metrics は us-east-1 のみで利用可能
#   - AWSアカウントで Billing Alerts が有効化済み
#     (コンソール > Billing > Preferences > Receive Billing Alerts)
#
# Usage:
#   ./setup-billing-alert.sh
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

BILLING_ALERT_EMAIL="${BILLING_ALERT_EMAIL:-}"
BILLING_THRESHOLD="${BILLING_THRESHOLD:-100}"
AWS_PROFILE="${AWS_PROFILE:-}"

# Billing metrics は us-east-1 のみ
BILLING_REGION="us-east-1"

# --- Helper: build AWS CLI base ---
build_aws_cmd() {
  local cmd="aws"
  if [ -n "$AWS_PROFILE" ]; then
    cmd="$cmd --profile $AWS_PROFILE"
  fi
  cmd="$cmd --region $BILLING_REGION"
  echo "$cmd"
}

# --- Checks ---
if ! command -v aws &>/dev/null; then
  echo -e "${RED}エラー: AWS CLI がインストールされていません${NC}"
  echo "  brew install awscli"
  exit 1
fi

if [ -z "$BILLING_ALERT_EMAIL" ]; then
  echo -e "${RED}エラー: BILLING_ALERT_EMAIL が設定されていません${NC}"
  echo "  scripts/cloud/.env に BILLING_ALERT_EMAIL を設定してください"
  exit 1
fi

AWS_CMD=$(build_aws_cmd)
TOPIC_NAME="billing-alert-topic"
ALARM_NAME="monthly-billing-alarm-${BILLING_THRESHOLD}usd"

echo -e "${BOLD}=== AWS Billing Alert Setup ===${NC}"
echo ""
echo -e "  通知先: ${BOLD}${BILLING_ALERT_EMAIL}${NC}"
echo -e "  閾値:   ${BOLD}\$${BILLING_THRESHOLD} USD/月${NC}"
echo -e "  リージョン: ${BILLING_REGION}（Billing metrics 固定）"
echo ""

# --- Step 1: SNS Topic 作成 ---
echo -e "${CYAN}[1/3] SNS Topic を作成中...${NC}"

TOPIC_ARN=$($AWS_CMD sns create-topic --name "$TOPIC_NAME" --query 'TopicArn' --output text 2>&1)

if [ $? -ne 0 ] || [ -z "$TOPIC_ARN" ]; then
  echo -e "${RED}エラー: SNS Topic の作成に失敗しました${NC}"
  echo "$TOPIC_ARN"
  exit 1
fi

echo -e "  Topic ARN: ${TOPIC_ARN}"

# --- Step 2: メール購読登録 ---
echo -e "${CYAN}[2/3] メール通知を登録中...${NC}"

# 既存の購読を確認
EXISTING_SUB=$($AWS_CMD sns list-subscriptions-by-topic \
  --topic-arn "$TOPIC_ARN" \
  --query "Subscriptions[?Endpoint=='${BILLING_ALERT_EMAIL}'].SubscriptionArn" \
  --output text 2>/dev/null || echo "")

if [ -n "$EXISTING_SUB" ] && [ "$EXISTING_SUB" != "None" ] && [ "$EXISTING_SUB" != "PendingConfirmation" ]; then
  echo -e "  ${GREEN}既に登録済み${NC}: ${BILLING_ALERT_EMAIL}"
else
  $AWS_CMD sns subscribe \
    --topic-arn "$TOPIC_ARN" \
    --protocol email \
    --notification-endpoint "$BILLING_ALERT_EMAIL" > /dev/null 2>&1

  echo -e "  ${YELLOW}確認メールを送信しました${NC}: ${BILLING_ALERT_EMAIL}"
  echo -e "  ${YELLOW}メール内のリンクをクリックして購読を確認してください${NC}"
fi

# --- Step 3: CloudWatch Billing Alarm 作成 ---
echo -e "${CYAN}[3/3] CloudWatch Billing Alarm を作成中...${NC}"

$AWS_CMD cloudwatch put-metric-alarm \
  --alarm-name "$ALARM_NAME" \
  --alarm-description "月額課金が \$${BILLING_THRESHOLD} USD を超えた場合にアラート" \
  --metric-name EstimatedCharges \
  --namespace "AWS/Billing" \
  --statistic Maximum \
  --period 21600 \
  --threshold "$BILLING_THRESHOLD" \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --evaluation-periods 1 \
  --alarm-actions "$TOPIC_ARN" \
  --dimensions Name=Currency,Value=USD \
  --treat-missing-data notBreaching

echo -e "  Alarm: ${ALARM_NAME}"

# --- Done ---
echo ""
echo -e "${GREEN}Billing Alert のセットアップが完了しました${NC}"
echo ""
echo -e "${BOLD}設定内容:${NC}"
echo -e "  SNS Topic:  ${TOPIC_NAME}"
echo -e "  Alarm:      ${ALARM_NAME}"
echo -e "  閾値:       \$${BILLING_THRESHOLD} USD/月"
echo -e "  通知先:     ${BILLING_ALERT_EMAIL}"
echo ""
echo -e "${YELLOW}注意:${NC}"
echo "  1. 確認メールが届いたらリンクをクリックして購読を有効化してください"
echo "  2. AWSコンソール > Billing > Preferences で 'Receive Billing Alerts' が有効か確認してください"
echo "  3. Billing metrics の反映には最大数時間かかる場合があります"
