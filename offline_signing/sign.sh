#!/bin/bash

set -ex
DATA_DIR="$(readlink -f "$1")"
KEYS_DIR="$(readlink -f "$(dirname "$0")")"

gpg2 --verify "${DATA_DIR}/coreos_production_update.bin.bz2.sig"
gpg2 --verify "${DATA_DIR}/coreos_production_update.zip.sig"
bunzip2 --keep "${DATA_DIR}/coreos_production_update.bin.bz2"
unzip "${DATA_DIR}/coreos_production_update.zip" -d "${DATA_DIR}"

export PATH="${DATA_DIR}:${PATH}"
cd "${DATA_DIR}"

# Sign UEFI binaries for Secure Boot.
for bin in vmlinuz grub shim
do
        [ -e "coreos_production_image.$bin" ] || continue
        gpg2 --verify "coreos_production_image.$bin.sig"
        mv "coreos_production_image.$bin" "$bin.unsigned"
        pesign --in="$bin.unsigned" \
               --out="coreos_production_image.$bin" \
               --certdir="${KEYS_DIR}" \
               --certificate='CoreOS Secure Boot Certificate' \
               --sign
done

# Sign the delta, with the Secure Boot signed kernel.
./core_sign_update \
    --image "${DATA_DIR}/coreos_production_update.bin" \
    --kernel "${DATA_DIR}/coreos_production_image.vmlinuz" \
    --output "${DATA_DIR}/coreos_production_update.gz" \
    --private_keys "${KEYS_DIR}/devel.key.pem:${KEYS_DIR}/prod-2.key.pem" \
    --public_keys  "${KEYS_DIR}/devel.pub.pem:${KEYS_DIR}/prod-2.pub.pem"
