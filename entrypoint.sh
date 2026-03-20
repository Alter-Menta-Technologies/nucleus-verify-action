#!/bin/bash
set -e

API_BASE="https://altermenta.com/api/v1"

# Determine repo URL
if [ -z "$NUCLEUS_REPO_URL" ]; then
  REPO_URL="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}"
else
  REPO_URL="$NUCLEUS_REPO_URL"
fi

echo "::group::Nucleus Verify"
echo "Submitting: $REPO_URL"

# Submit scan
RESPONSE=$(curl -sf -X POST "$API_BASE/verify" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $NUCLEUS_API_KEY" \
  -d "{\"repo_url\": \"$REPO_URL\"}" 2>&1) || {
  echo "::error::Failed to submit scan"
  echo "Response: $RESPONSE"
  exit 1
}

JOB_ID=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('job_id',''))" 2>/dev/null)

if [ -z "$JOB_ID" ]; then
  echo "::error::No job_id in response"
  echo "Response: $RESPONSE"
  exit 1
fi

echo "Job ID: $JOB_ID"

# Poll for completion (max 10 minutes)
MAX_WAIT=600
WAITED=0
INTERVAL=15
STATE=""

while [ $WAITED -lt $MAX_WAIT ]; do
  sleep $INTERVAL
  WAITED=$((WAITED + INTERVAL))

  STATUS=$(curl -sf "$API_BASE/jobs/$JOB_ID" \
    -H "X-API-Key: $NUCLEUS_API_KEY" 2>/dev/null) || continue

  STATE=$(echo "$STATUS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null)

  echo "Status: $STATE (${WAITED}s)"

  if [ "$STATE" = "complete" ]; then
    break
  fi

  if [ "$STATE" = "failed" ]; then
    echo "::error::Scan failed"
    exit 1
  fi
done

if [ "$STATE" != "complete" ]; then
  echo "::error::Scan timed out after ${MAX_WAIT}s"
  exit 1
fi

# Extract results
VERDICT=$(echo "$STATUS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('verdict','UNKNOWN'))" 2>/dev/null)
SCORE=$(echo "$STATUS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('trust_score',0))" 2>/dev/null)
CERT_URL=$(echo "$STATUS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('certificate_url',''))" 2>/dev/null)
FINDINGS=$(echo "$STATUS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('finding_count',0))" 2>/dev/null)
HIGH=$(echo "$STATUS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('high_count',0))" 2>/dev/null)
CRITICAL=$(echo "$STATUS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('critical_count',0))" 2>/dev/null)
PROOF_URL="$API_BASE/results/$JOB_ID/proof_pack"

# Set outputs
{
  echo "verdict=$VERDICT"
  echo "trust_score=$SCORE"
  echo "certificate_url=$CERT_URL"
  echo "findings_count=$FINDINGS"
  echo "high_count=$HIGH"
  echo "critical_count=$CRITICAL"
  echo "proof_pack_url=$PROOF_URL"
} >> "$GITHUB_OUTPUT"

# Print summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  NUCLEUS VERIFY RESULT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Verdict:     $VERDICT"
echo "  Trust score: $SCORE/100"
echo "  Findings:    $FINDINGS total, $HIGH HIGH, $CRITICAL CRITICAL"
echo "  Certificate: $CERT_URL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "::endgroup::"

# Write GitHub Actions job summary
cat >> "$GITHUB_STEP_SUMMARY" << EOF
## ⚛ Nucleus Verify — $VERDICT

| | |
|---|---|
| **Verdict** | $VERDICT |
| **Trust Score** | $SCORE / 100 |
| **Findings** | $FINDINGS total ($CRITICAL critical, $HIGH high) |
| **Certificate** | [View →]($CERT_URL) |
| **Proof Pack** | [Download →]($PROOF_URL) |

*681 deterministic operators · Independently verifiable · [altermenta.com](https://altermenta.com)*
EOF

# Apply failure conditions
if [ "$FAIL_ON_UNVERIFIED" = "true" ] && [ "$VERDICT" = "UNVERIFIED" ]; then
  echo "::error::Verdict is UNVERIFIED — failing workflow"
  exit 1
fi

if [ "$FAIL_ON_FINDINGS" = "true" ]; then
  TOTAL_SEVERE=$((${CRITICAL:-0} + ${HIGH:-0}))
  if [ "$TOTAL_SEVERE" -gt "0" ] 2>/dev/null; then
    echo "::error::$CRITICAL CRITICAL and $HIGH HIGH findings — failing workflow"
    exit 1
  fi
fi
