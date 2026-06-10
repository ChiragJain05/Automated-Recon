#!/usr/bin/env bash
# =============================================================================
#  10_cloud.sh — Cloud Asset Discovery
# =============================================================================
MODULE_NAME="10_cloud"

run_module() {
    stage "CLOUD ASSET DISCOVERY"

    local COMPANY
    COMPANY=$(echo "$DOMAIN" | cut -d. -f1)

    # S3 buckets
    safe_run s3scanner "S3 Bucket Scan" \
        bash -c "s3scanner scan --bucket $COMPANY > $CLOUD_DIR/s3.txt 2>/dev/null"

    # cloud_enum — S3, Azure, GCP
    safe_run cloud_enum "Cloud Enum" \
        cloud_enum -k "$COMPANY" \
        --disable-gcp --disable-azure \
        -l "$CLOUD_DIR/cloud_enum.txt" 2>/dev/null

    # GrayHatWarfare public buckets via API (if key set)
    if [[ -n "${GRAYHAT_KEY:-}" ]]; then
        info "Querying GrayHatWarfare buckets"
        curl -s "https://buckets.grayhatwarfare.com/api/v2/buckets/0/100?keywords=$COMPANY&access_token=$GRAYHAT_KEY" \
            | jq -r '.buckets[]?.url // empty' 2>/dev/null \
            > "$CLOUD_DIR/grayhat_buckets.txt" || true
    fi

    success "Cloud discovery completed"
    return 0
}
