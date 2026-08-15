#!/bin/bash
# Model artifact integrity verification.
#
# WHY THIS EXISTS SEPARATELY FROM CONTAINER SECURITY:
# Cosign proves the CONTAINER image wasn't tampered with. It says
# nothing about the MODEL WEIGHTS downloaded at runtime from
# HuggingFace or another registry. A compromised or corrupted model
# file is a completely separate supply-chain risk - this script
# closes that gap.
#
# Usage: ./verify-model-integrity.sh <model-file> <expected-sha256>

set -euo pipefail

MODEL_FILE="${1:?Usage: $0 <model-file> <expected-sha256>}"
EXPECTED_SHA256="${2:?Usage: $0 <model-file> <expected-sha256>}"

if [ ! -f "$MODEL_FILE" ]; then
  echo "FATAL: Model file not found: $MODEL_FILE"
  exit 1
fi

echo "Verifying integrity of: $MODEL_FILE"
ACTUAL_SHA256=$(sha256sum "$MODEL_FILE" | awk '{print $1}')

echo "Expected: $EXPECTED_SHA256"
echo "Actual:   $ACTUAL_SHA256"

if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
  echo ""
  echo "FATAL: Checksum mismatch. Model integrity verification FAILED."
  echo "This model file does not match its recorded, trusted checksum."
  echo "Refusing to load. This could indicate corruption or tampering."
  exit 1
fi

echo ""
echo "OK: Model integrity verified successfully."
exit 0
