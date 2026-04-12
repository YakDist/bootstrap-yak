#!/bin/bash
set -e

SCRIPT_DIR="$(dirname "$0")"
SCRIPT_DIR="${SCRIPT_DIR:-.}"

SOURCE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd -P)"

ARCH=""
ISO=""
OVMF_FILE=""

QEMU_ARGS="${QEMU_OPTARGS:-}"
ENABLE_KVM=0
DEBUG=0

PRINT_COMMAND="${PRINT_COMMAND:-0}"

QEMU_MEM="${QEMU_MEM:-512M}"
QEMU_CORES="${QEMU_CORES:-2}"
QEMU_NUMA="${QEMU_NUMA:-1}"

usage() {
cat <<EOF
Usage: $0 [options] <arch> <ovmf-file> <iso>

Options:
  -s    Enable serial output
  -d    Enable debug console
  -k    Enable KVM acceleration
  -P    Pause CPU at startup
  -n    Add network device
  -G    Disable graphics (nographic)
  -D    Enable QEMU debug logging
  -V    Print QEMU command without running
EOF
exit 1
}

try_enable_kvm() {
    if [[ "${QEMU_NO_KVM:-0}" -eq 1 ]]; then
        return
    fi

    if [[ "$ENABLE_KVM" -eq 1 && "$(uname -m)" == "$ARCH" ]]; then
        QEMU_ARGS+=" -accel kvm"

        if [[ "$ARCH" == "x86_64" ]]; then
            QEMU_ARGS+=" -cpu host,+invtsc,+x2apic"
        fi
    fi
}

setup_arch() {
    case "$ARCH" in
        x86_64)
            QEMU_CMD="qemu-system-x86_64"
            QEMU_ARGS+=" -M q35"
            QEMU_ARGS+=" -vga virtio"
            QEMU_ARGS+=" -rtc base=utc"

            if [[ "$DEBUG" -eq 1 ]]; then
                QEMU_ARGS+=" -M smm=off"
            fi
            ;;
        *)
            echo "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
}

while getopts "sdkPnGVD" opt; do
    case "$opt" in
        s) QEMU_ARGS+=" -serial stdio" ;;
        d) QEMU_ARGS+=" -debugcon stdio" ;;
        k) ENABLE_KVM=1 ;;
        P) QEMU_ARGS+=" -S" ;;
        n) QEMU_ARGS+=" -netdev user,id=n1 -device e1000,netdev=n1" ;;
        G)
            QEMU_ARGS+=" -nographic"
            echo "Exit QEMU with Ctrl+A then X"
            ;;
        D)
            DEBUG=1
            QEMU_ARGS+=" -d int -D qemulog.txt"
            ;;
        V) PRINT_COMMAND=1 ;;
        *) usage ;;
    esac
done

shift $((OPTIND - 1))

if [[ $# -ne 3 ]]; then
	usage
fi

ARCH="$1"
OVMF_FILE="$2"
ISO="$3"

setup_arch
try_enable_kvm

if [[ "${QEMU_NO_UEFI:-0}" -ne 1 ]]; then
    QEMU_ARGS+=" -drive if=pflash,unit=0,format=raw,file=${OVMF_FILE},readonly=on"
fi

QEMU_ARGS+=" -cdrom ${ISO}"
if [[ "${QEMU_NUMA}" -eq 1 ]]; then
    QEMU_ARGS+=" -smp ${QEMU_CORES}"
    QEMU_ARGS+=" -m ${QEMU_MEM}"
else
    # Strip trailing G/M suffix, divide, re-attach suffix
    mem_unit="${QEMU_MEM//[0-9]/}"
    mem_value="${QEMU_MEM//[^0-9]/}"
    mem_per_node=$(( mem_value / QEMU_NUMA ))
    cpus_per_node=$(( QEMU_CORES / QEMU_NUMA ))

    QEMU_ARGS+=" -smp cpus=${QEMU_CORES}"
    QEMU_ARGS+=" -m ${QEMU_MEM}"

    for (( i=0; i<QEMU_NUMA; i++ )); do
        cpu_start=$(( i * cpus_per_node ))
        cpu_end=$(( cpu_start + cpus_per_node - 1 ))

        QEMU_ARGS+=" -object memory-backend-ram,size=${mem_per_node}${mem_unit},id=m${i}"
        QEMU_ARGS+=" -numa node,memdev=m${i},cpus=${cpu_start}-${cpu_end},nodeid=${i}"
    done

    # Add inter-node distances
    for (( i=0; i<QEMU_NUMA; i++ )); do
        for (( j=i+1; j<QEMU_NUMA; j++ )); do
            QEMU_ARGS+=" -numa dist,src=${i},dst=${j},val=20"
        done
    done
fi
QEMU_ARGS+=" -s -no-shutdown -no-reboot"

if [[ "$PRINT_COMMAND" -eq 1 ]]; then
    echo "${QEMU_CMD} ${QEMU_ARGS}"
    exit 0
fi

exec ${QEMU_CMD} ${QEMU_ARGS}
