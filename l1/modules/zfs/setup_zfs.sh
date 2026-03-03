# shellcheck shell=bash

set -veuo pipefail

SSD_ENABLE="@ssd_enable@"
SSD_FASTPOOL_NAME="@ssd_fastpool_name@"
SSD_DEVICE="@ssd_device@"
SSD_SLOG_SIZE="@ssd_slog_size@"
SSD_CACHE_SIZE="@ssd_cache_size@"
POOL_NAME="@pool_name@"
VDEV="@vdev@"

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

if ! zfs list "$POOL_NAME/default" -Ho name >/dev/null 2>&1; then
  mkdir -p /var/lib/zfs/
  dd if=/dev/urandom of=/var/lib/zfs/default.key bs=32 count=1
  zfs create \
    -o mountpoint=none \
    -o recordsize=128KB \
    -o compression=lz4 \
    -o encryption=on -o keyformat=raw -o keylocation=file:///var/lib/zfs/default.key \
    -o atime=off \
    -o dnodesize=auto \
    -o xattr=sa \
    "$POOL_NAME/default"
fi

if ! zfs list "$POOL_NAME/block" -Ho name >/dev/null 2>&1; then
  mkdir -p /var/lib/zfs/
  dd if=/dev/urandom of=/var/lib/zfs/block.key bs=32 count=1
  zfs create \
    -o mountpoint=none \
    -o compression=lz4 \
    -o encryption=on -o keyformat=raw -o keylocation=file:///var/lib/zfs/block.key \
    "$POOL_NAME/block"
fi

if ! zfs list "$POOL_NAME/postgres" -Ho name >/dev/null 2>&1; then
  mkdir -p /var/lib/zfs/
  dd if=/dev/urandom of=/var/lib/zfs/postgres.key bs=32 count=1
  zfs create \
    -o mountpoint=none \
    -o recordsize=8k \
    -o compression=lz4 \
    -o encryption=on -o keyformat=raw -o keylocation=file:///var/lib/zfs/postgres.key \
    -o atime=off \
    -o dnodesize=auto \
    -o xattr=sa \
    "$POOL_NAME/postgres"
fi
