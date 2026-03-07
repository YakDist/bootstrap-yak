#!/bin/bash
set -e

if [[ $# -ne 3 ]]; then
    exit 1
fi

BUILD_DIR="$1"
ARCH="$2"
ISO_NAME="$3"

case "$ARCH" in
    x86_64) ;;
    *)
        echo "unsupported arch: $ARCH"
        exit 1
esac

ISO_ROOT="$(mktemp -d)"

LIMINE_DIR="${BUILD_DIR}/tools/host-limine/share/limine"
YAK_DIR="${BUILD_DIR}/packages/yak/usr/share/yak"

mkdir -p "${ISO_ROOT}/boot"
mkdir -p "${ISO_ROOT}/boot/limine"
mkdir -p "${ISO_ROOT}/EFI/BOOT/"

cp -v "${YAK_DIR}/yak" "${ISO_ROOT}/boot/yak"
cp -v "${YAK_DIR}/yak.sym" "${ISO_ROOT}/boot/yak.sym"
# TODO: copy initrd

cat <<EOF > "${ISO_ROOT}/boot/limine/limine.conf"
timeout: 3

/Yak (${ARCH})
protocol: limine
kernel_path: boot():/boot/yak
module_path: boot():/boot/yak.sym
EOF

if [[ $ARCH == "x86_64" ]]; then
    cp -v "${LIMINE_DIR}/limine-bios.sys" \
          "${LIMINE_DIR}/limine-bios-cd.bin" \
          "${LIMINE_DIR}/limine-uefi-cd.bin" \
          "${ISO_ROOT}/boot/limine/"

    cp -v "${LIMINE_DIR}/BOOTX64.EFI" "${ISO_ROOT}/EFI/BOOT/"
    cp -v "${LIMINE_DIR}/BOOTIA32.EFI" "${ISO_ROOT}/EFI/BOOT/"

    xorriso -as mkisofs -R -r -J -b boot/limine/limine-bios-cd.bin \
        -no-emul-boot -boot-load-size 4 -boot-info-table -hfsplus \
        -apm-block-size 2048 --efi-boot boot/limine/limine-uefi-cd.bin \
        -efi-boot-part --efi-boot-image --protective-msdos-label \
        "${ISO_ROOT}" -o "${ISO_NAME}"

    "${LIMINE_DIR}/limine" bios-install "${ISO_NAME}"
fi

rm -rf "${ISO_ROOT}"
