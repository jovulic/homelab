# shellcheck shell=bash
set -euo pipefail

DATASET="@dataset@/container-registry"
MOUNTPOINT="/var/lib/registry"

# Create ands mount the dataset if it does not exist.
if ! zfs list "$DATASET" -Ho name >/dev/null 2>&1; then
	echo "Creating ZFS dataset $DATASET..."
	zfs create -o mountpoint="$MOUNTPOINT" "$DATASET"
fi

# Ensure it's mounted
if [[ $(zfs list -H -o mounted "$DATASET") != "yes" ]]; then
	echo "Mounting $DATASET..."
	zfs mount "$DATASET"
fi

# Ensure the directory exists and has correct ownership.
echo "Ensuring correct ownership for $MOUNTPOINT..."
chown -R docker-registry:docker-registry "$MOUNTPOINT"
chmod 750 "$MOUNTPOINT"
