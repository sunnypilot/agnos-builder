#!/usr/bin/env bash
set -e

# Make sure we're in the correct directory
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
cd "$DIR"

# Constants
OTA_DIR="$DIR/../output/ota"
# expects AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY in environment

# Parse input
if [ $# -lt 2 ]; then
  echo "Usage: $0 <production|staging> <account_id>"
  exit 1
fi

TARGET=$1
ACCOUNT_ID=$2
FOUND=0

if [ "$TARGET" == "production" ]; then
  OTA_JSON="$OTA_DIR/all-partitions.json"
  DATA_BUCKET="sunnyos"
  FOUND=1
fi
if [ "$TARGET" == "staging" ]; then
  OTA_JSON="$OTA_DIR/all-partitions-staging.json"
  DATA_BUCKET="sunnyos-staging"
  FOUND=1
fi

if [ $FOUND == 0 ]; then
  echo "Supply either 'production' or 'staging' as first argument!"
  exit 1
fi

upload_file() {
  local FILE_NAME=$1
  local S3_PATH="s3://$DATA_BUCKET/$FILE_NAME"

  echo "Copying $FILE_NAME to R2..."
  aws s3 cp --endpoint-url "https://$ACCOUNT_ID.r2.cloudflarestorage.com" \
    "$OTA_DIR/$FILE_NAME" "$S3_PATH" --only-show-errors

  # Stock R2 URL
  local PUBLIC_URL="https://$DATA_BUCKET.$ACCOUNT_ID.r2.cloudflarestorage.com/$FILE_NAME"
  echo "  $PUBLIC_URL"
}

process_file() {
  local NAME=$1
  local HASH_RAW
  HASH_RAW=$(jq -r ".[] | select(.name == \"$NAME\") | .hash_raw" "$OTA_JSON")
  upload_file "$NAME-$HASH_RAW.img.xz"
  if [ -f "$OTA_DIR/$NAME-$HASH_RAW.img" ]; then
    upload_file "$NAME-$HASH_RAW.img"
  fi
}

# Liftoff!
for name in $(jq -r ".[] .name" "$OTA_JSON"); do
  process_file "$name"
done

echo "Done!"
