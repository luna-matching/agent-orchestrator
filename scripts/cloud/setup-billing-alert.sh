#!/bin/bash
set -euo pipefail

# ============================================================================
# CloudWatch Billing Alert Setup
# ============================================================================
# AWS月額課金が閾値を超えたらメール通知するアラームを作成。
#
# 前提:
#   - AWS CLIが設定済み（ローカル or EC2 IAMロール）
#   - IAMポリシー: cloudwatch:PutMetricAlarm, sns:CreateTopic, sns:Subscribe
#   - Billing alertsはus-east-1でのみ利用可能
#
# Usage:
#   bash setup-billing-alert.sh                    # .envから読み込み
#   bash setup-billing-alert.sh user@example.com 100  # 直接指定
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

# Load .env if available
if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

EMAIL="${1:-${BILLING_ALERT_EMAIL:-}}"
THRESHOLD="${2:-${BILLING_THRESHOLD:-100}}"
ALARM_NAME="orchestrator-billing-${THRESHOLD}usd"
TOPIC_NAME="orchestrator-billing-alert"
REGION="us-east-1"  # Billing metrics are only in us-east-1

# --- Validation ---
if [ -z "$EMAIL" ]; then
  echo "エラー: メールアドレスが未設定です"
  echo ""
  echo "Usage:"
  echo "  bash setup-billing-alert.sh user@example.com 100"
  echo ""
  echo "  または .env に BILLING_ALERT_EMAIL を設定してください"
  exit 1
fi

echo "=== CloudWatch Billing Alert Setup ==="
echo "  通知先: ${EMAIL}"
echo "  閾値:   \$${THRESHOLD}/月"
echo ""

# --- 1. SNS Topic ---
echo "[1/3] SNS Topic を作成中..."
TOPIC_ARN=$(aws sns create-topic \
  --name "$TOPIC_NAME" \
  --region "$REGION" \
  --query 'TopicArn' \
  --output text)
echo "  Topic: ${TOPIC_ARN}"

# --- 2. Subscribe email ---
echo "[2/3] メール通知を登録中..."
aws sns subscribe \
  --topic-arn "$TOPIC_ARN" \
  --protocol email \
  --notification-endpoint "$EMAIL" \
  --region "$REGION" \
  --output text > /dev/null
echo "  ${EMAIL} に確認メールを送信しました"
echo "  ※ メール内の Confirm subscription リンクをクリックしてください"

# --- 3. CloudWatch Alarm ---
echo "[3/3] CloudWatch Alarm を作成中..."
aws cloudwatch put-metric-alarm \
  --alarm-name "$ALARM_NAME" \
  --alarm-description "AWS月額課金が \$${THRESHOLD} を超えた場合に通知" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 21600 \
  --threshold "$THRESHOLD" \
  --comparison-operator GreaterThanThreshold \
  --dimensions "Name=Currency,Value=USD" \
  --evaluation-periods 1 \
  --alarm-actions "$TOPIC_ARN" \
  --treat-missing-data notBreaching \
  --region "$REGION"
echo "  Alarm: ${ALARM_NAME}"

echo ""
echo "=== セットアップ完了 ==="
echo "  月額 \$${THRESHOLD} を超えると ${EMAIL} に通知されます"
echo ""
echo "確認:"
echo "  aws cloudwatch describe-alarms --alarm-names ${ALARM_NAME} --region ${REGION} --query 'MetricAlarms[0].StateValue' --output text"
echo ""
echo "削除:"
echo "  aws cloudwatch delete-alarms --alarm-names ${ALARM_NAME} --region ${REGION}"
echo "  aws sns delete-topic --topic-arn ${TOPIC_ARN} --region ${REGION}"
