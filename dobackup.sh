#!/usr/bin/env sh

set -e

source .env

# Encryption public key file
KEY_FILE=/opt/PublicKey.pem

# Default storage class to standard if not provided
S3_STORAGE_CLASS=${S3_STORAGE_CLASS:-STANDARD}

# Generate file name for tar
FILE_NAME=/tmp/${BACKUP_NAME}-$(date "+%Y-%m-%d_%H-%M-%S").tar.gz
ENCRYPTED_FILE_NAME=${FILE_NAME}.enc

# Check if TARGET variable is set
if [ -z "${TARGET}" ]; then
    echo "TARGET Environment Variable Missing. Using Default! (/data)"
    TARGET=/data
else
    echo "TARGET Environment Variable Defined!"
fi

if [ -z "${S3_ENDPOINT}" ]; then
  AWS_ARGS=""
else
  AWS_ARGS="--endpoint-url ${S3_ENDPOINT}"
fi

echo "🗄️ Creating Archive..."
tar -zcvf "${FILE_NAME}" "${TARGET}"

echo "🔑 Encrypting Archive..."
openssl rsautl -encrypt -pubin -inkey "${KEY_FILE}" -in "${FILE_NAME}" -out "${ENCRYPTED_FILE_NAME}"

echo "📤 Uploading to Amazon S3..."
aws s3 ${AWS_ARGS} cp --storage-class "${S3_STORAGE_CLASS}" "${ENCRYPTED_FILE_NAME}" "${S3_BUCKET_URL}"

echo "🧹 Cleaning up..."
echo "Removing Unencrypted Archive..."
rm -rf "${FILE_NAME}"
echo "Removing Encrypted Archive..."
rm -rf "${ENCRYPTED_FILE_NAME}"

echo "✅ Backup Completed!"

if [ -n "${WEBHOOK_URL}" ]; then
    echo "🌐 Notifying Webhook..."
    curl -m 10 --retry 5 "${WEBHOOK_URL}"
fi