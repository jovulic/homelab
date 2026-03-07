# shellcheck shell=bash

set -veuo pipefail

SSD_ENABLE="@ssd_enable@"
SSD_FASTPOOL_NAME="@ssd_fastpool_name@"
SSD_DEVICE="@ssd_device@"
SSD_SLOG_SIZE="@ssd_slog_size@"
SSD_CACHE_SIZE="@ssd_cache_size@"
POOL_NAME="@pool_name@"
VDEV="@vdev@"

setup_encryption_key() {
  local key_file="/var/lib/zfs/encryption.key"
  if [ ! -f "$key_file" ]; then
    mkdir -p /var/lib/zfs/
    dd if=/dev/urandom of="$key_file" bs=32 count=1
    chmod 600 "$key_file"
  fi
}

setup_default_dataset() {
  local pool="$1"
  local key_file="/var/lib/zfs/encryption.key"

  if ! zfs list "$pool/default" -Ho name >/dev/null 2>&1; then
    zfs create \
      -o mountpoint=none \
      -o recordsize=128KB \
      -o compression=lz4 \
      -o encryption=on -o keyformat=raw -o keylocation="file://$key_file" \
      -o atime=off \
      -o dnodesize=auto \
      -o xattr=sa \
      "$pool/default"
  fi
}

setup_block_dataset() {
  local pool="$1"
  local key_file="/var/lib/zfs/encryption.key"

  if ! zfs list "$pool/block" -Ho name >/dev/null 2>&1; then
    zfs create \
      -o mountpoint=none \
      -o compression=lz4 \
      -o encryption=on -o keyformat=raw -o keylocation="file://$key_file" \
      "$pool/block"
  fi
}

setup_postgres_dataset() {
  local pool="$1"
  local key_file="/var/lib/zfs/encryption.key"

  if ! zfs list "$pool/postgres" -Ho name >/dev/null 2>&1; then
    zfs create \
      -o mountpoint=none \
      -o recordsize=8k \
      -o compression=lz4 \
      -o encryption=on -o keyformat=raw -o keylocation="file://$key_file" \
      -o atime=off \
      -o dnodesize=auto \
      -o xattr=sa \
      "$pool/postgres"
  fi
}

setup_encryption_key

if [ "$SSD_ENABLE" = "1" ]; then
  if ! zpool list "$SSD_FASTPOOL_NAME" -Ho name >/dev/null 2>&1; then
    echo "Partitioning SSD $SSD_DEVICE..."

    # Wipe existing partitions.
    sgdisk -Z "$SSD_DEVICE"

    # SLOG (BF01 is ZFS partition type).
    sgdisk -n 1:0:+"$SSD_SLOG_SIZE" -t 1:BF01 -c 1:zfs_slog "$SSD_DEVICE"

    # L2ARC.
    sgdisk -n 2:0:+"$SSD_CACHE_SIZE" -t 2:BF01 -c 2:zfs_cache "$SSD_DEVICE"

    # Fastpool.
    sgdisk -n 3:0:0 -t 3:BF01 -c 3:zfs_"$SSD_FASTPOOL_NAME" "$SSD_DEVICE"

    # Inform OS of partition changes and wait for them to populate.
    partprobe "$SSD_DEVICE"
    udevadm settle

    # Create fastpool.
    zpool create \
      -f \
      -o ashift=12 \
      -m none \
      "$SSD_FASTPOOL_NAME" \
      "/dev/disk/by-partlabel/zfs_$SSD_FASTPOOL_NAME"
  fi

  setup_default_dataset "$SSD_FASTPOOL_NAME"
  setup_block_dataset "$SSD_FASTPOOL_NAME"
  setup_postgres_dataset "$SSD_FASTPOOL_NAME"
fi

if ! zpool list "$POOL_NAME" -Ho name >/dev/null 2>&1; then
  ssd_args=""
  if [ "$SSD_ENABLE" = "1" ]; then
    ssd_args="log /dev/disk/by-partlabel/zfs_slog cache /dev/disk/by-partlabel/zfs_cache"
  fi

  # shellcheck disable=SC2086
  zpool create \
    -f \
    -o ashift=12 \
    -m none \
    "$POOL_NAME" \
    $VDEV $ssd_args
fi

setup_default_dataset "$POOL_NAME"
setup_block_dataset "$POOL_NAME"
setup_postgres_dataset "$POOL_NAME"
