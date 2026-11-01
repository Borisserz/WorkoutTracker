#!/usr/bin/env bash
# Creates a $1 USD budget alert for the WorkoutTracker Firebase/GCP project.
# Run AFTER Blaze billing is linked and the billing account is OPEN.
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-serzhanovich-ecosystem-ce700}"
PROJECT_NUMBER="${PROJECT_NUMBER:-667537183554}"
BUDGET_AMOUNT="${BUDGET_AMOUNT:-1}"
CURRENCY="${CURRENCY:-USD}"

echo "Project: $PROJECT_ID ($PROJECT_NUMBER)"

BILLING_ACCOUNT=$(gcloud billing projects describe "$PROJECT_ID" --format='value(billingAccountName)' | sed 's#billingAccounts/##')
if [[ -z "$BILLING_ACCOUNT" ]]; then
  echo "ERROR: No billing account linked to $PROJECT_ID yet. Finish Blaze setup in Firebase Console first."
  exit 1
fi

OPEN=$(gcloud billing accounts describe "$BILLING_ACCOUNT" --format='value(open)')
echo "Billing account: $BILLING_ACCOUNT (open=$OPEN)"
if [[ "$OPEN" != "True" ]]; then
  echo "ERROR: Billing account is not open yet. Finish card verification, then re-run."
  exit 1
fi

gcloud services enable billingbudgets.googleapis.com --project="$PROJECT_ID"

# Threshold emails go to billing admins / billing account users.
gcloud billing budgets create \
  --billing-account="$BILLING_ACCOUNT" \
  --display-name="Ecosystem hard alert \$${BUDGET_AMOUNT}" \
  --budget-amount="${BUDGET_AMOUNT}" \
  --filter-projects="projects/${PROJECT_NUMBER}" \
  --threshold-rule=percent=1 \
  --threshold-rule=percent=50 \
  --threshold-rule=percent=90 \
  --threshold-rule=percent=100 \
  --calendar-period=month

echo "OK — budget created. You will get email at thresholds (1/50/90/100%)."
echo "Tip: also set a Pub/Sub kill-switch later if you want auto-disable of billing."
