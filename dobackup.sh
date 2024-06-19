#!/usr/bin/env sh

set -e

source .env

# Encryption public key file
KEY_FILE=/opt/PublicKey.pem

# Default storage class to standard if not provided
S3_STORAGE_CLASS=${S3_STORAGE_CLASS:-STANDARD}

# Generate file name for tar
BACKUP_DATE=$(date "+%Y-%m-%d_%H-%M-%S")
FILE_NAME=/tmp/${BACKUP_NAME}-${BACKUP_DATE}.tar.gz
SYMKEY_NAME=/tmp/${BACKUP_NAME}-${BACKUP_DATE}.key.enc
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

echo "🔑 Generating Symmetric Key..."
openssl rand -base64 64 > /tmp/SymKey.key

echo "🔑 Encrypting Archive..."
openssl enc -aes-256-cbc \
  -pbkdf2 \
  -salt \
  -in "${FILE_NAME}" \
  -out "${ENCRYPTED_FILE_NAME}" \
  -pass file:/tmp/SymKey.key

echo "🔐 Encrypting Symetric Key..."
openssl pkeyutl -encrypt \
  -inkey "${KEY_FILE}" -pubin \
  -in /tmp/SymKey.key \
  -out "${SYMKEY_NAME}"

echo "📤 Uploading to Amazon S3..."
aws s3 ${AWS_ARGS} cp --storage-class "${S3_STORAGE_CLASS}" "${ENCRYPTED_FILE_NAME}" "${S3_BUCKET_URL}"
aws s3 ${AWS_ARGS} cp --storage-class "${S3_STORAGE_CLASS}" "${SYMKEY_NAME}" "${S3_BUCKET_URL}"

echo "🧹 Cleaning up..."
echo "Removing Unencrypted Archive..."
rm -rf "${FILE_NAME}"
echo "Removing Encrypted Archive..."
rm -rf "${ENCRYPTED_FILE_NAME}"
echo "Removing Symmetric Key..."
rm -rf "/tmp/SymKey.key"
echo "Removing Encrypted Symmetric Key..."
rm -rf "${SYMKEY_NAME}"

echo "✅ Backup Completed!"

if [ -n "${WEBHOOK_URL}" ]; then
    echo "🌐 Notifying Webhook..."
    curl -m 10 --retry 5 "${WEBHOOK_URL}"
fi