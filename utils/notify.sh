#!/usr/bin/env bash
# =============================================================================
#  notify.sh — Slack / Discord webhook notifications
#  Sourced by recon.sh. Never executed directly.
# =============================================================================

_send_webhook() {
    local URL="$1"
    local PAYLOAD="$2"
    curl -s -X POST "$URL" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD" \
        --max-time 10 \
        > /dev/null 2>&1
}

notify_start() {
    local MSG="🚀 *Recon started*\nTarget: \`$DOMAIN\`\nModules: ${#SELECTED_MODULES[@]}\nRun ID: \`$RUN_ID\`"
    [[ -n "${DISCORD_WEBHOOK:-}" ]] && _send_webhook "$DISCORD_WEBHOOK" "{\"content\":\"$MSG\"}"
    [[ -n "${SLACK_WEBHOOK:-}" ]]   && _send_webhook "$SLACK_WEBHOOK"   "{\"text\":\"$MSG\"}"
}

notify_complete() {
    local MSG="✅ *Recon complete*\nTarget: \`$DOMAIN\`\nSubdomains: ${TOTAL_SUBS:-0} | Alive: ${TOTAL_ALIVE:-0} | URLs: ${TOTAL_URLS:-0}\nRun ID: \`$RUN_ID\`"
    [[ -n "${DISCORD_WEBHOOK:-}" ]] && _send_webhook "$DISCORD_WEBHOOK" "{\"content\":\"$MSG\"}"
    [[ -n "${SLACK_WEBHOOK:-}" ]]   && _send_webhook "$SLACK_WEBHOOK"   "{\"text\":\"$MSG\"}"
}

notify_critical() {
    local FINDING="$1"
    local MSG="🔴 *Critical finding*\nTarget: \`$DOMAIN\`\n\`\`\`$FINDING\`\`\`"
    [[ -n "${DISCORD_WEBHOOK:-}" ]] && _send_webhook "$DISCORD_WEBHOOK" "{\"content\":\"$MSG\"}"
    [[ -n "${SLACK_WEBHOOK:-}" ]]   && _send_webhook "$SLACK_WEBHOOK"   "{\"text\":\"$MSG\"}"
}

notify_stage_failed() {
    local STAGE="$1"
    local MSG="⚠️ *Stage failed*\nTarget: \`$DOMAIN\`\nStage: \`$STAGE\`"
    [[ -n "${DISCORD_WEBHOOK:-}" ]] && _send_webhook "$DISCORD_WEBHOOK" "{\"content\":\"$MSG\"}"
    [[ -n "${SLACK_WEBHOOK:-}" ]]   && _send_webhook "$SLACK_WEBHOOK"   "{\"text\":\"$MSG\"}"
}
