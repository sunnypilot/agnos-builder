#!/bin/bash
set -e

CMDLINE="$(cat /proc/cmdline)"
SLOT="$(echo "$CMDLINE" | sed -e 's/^.*androidboot.slot_suffix=//' -e 's/ .*$//')"
SERIAL="$(echo "$CMDLINE" | sed -e 's/^.*androidboot.serialno=//' -e 's/ .*$//')"
[[ "$SERIAL" =~ ^[0-9a-fA-F]{8}$ ]] || { echo "unexpected serial '$SERIAL'"; exit 1; }
# locally administered, unique per device
ADDR="02:00:${SERIAL:0:2}:${SERIAL:2:2}:${SERIAL:4:2}:${SERIAL:6:2}"

if ! mountpoint -q /bt_firmware; then
  UEVENT="$(grep -lx "PARTNAME=bluetooth$SLOT" /sys/class/block/sd*/uevent)"
  UEVENT="${UEVENT%/uevent}"
  mount -o ro "/dev/${UEVENT##*/}" /bt_firmware
fi
mkdir -p -m 700 /data/bluetooth
rfkill unblock bluetooth

btattach -B /dev/ttyHS1 -P qca &

# the controller stays unconfigured until it has an address; firmware loads first
for i in $(seq 1 30); do
  # btmgmt never sends the command when stdin is already at EOF (systemd gives /dev/null)
  sleep 1 | timeout 3 btmgmt --index 0 public-addr "$ADDR" && break
  [ "$i" -lt 30 ] || exit 1
  sleep 1
done

wait
