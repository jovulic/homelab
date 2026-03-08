#!/usr/bin/env bash
set -e

DATASETS_JSON=$1

echo "$DATASETS_JSON" | jq -c '.[]' | while read -r ds; do
  dataset=$(echo "$ds" | jq -r '.dataset')
  mount=$(echo "$ds" | jq -r '.mount')
  user=$(echo "$ds" | jq -r '.user // empty')

  is_new="false"
  if ! zfs list "$dataset" >/dev/null 2>&1; then
    echo "Creating dataset $dataset..."
    if [ "$mount" = "true" ]; then
      zfs create -o mountpoint="/$dataset" "$dataset"
    else
      zfs create "$dataset"
    fi
    is_new="true"
  else
    echo "Dataset $dataset already exists."
  fi

  if [ "$mount" = "true" ]; then
    # Ensure the dataset is mounted.
    mounted=$(zfs get -H -o value mounted "$dataset")
    if [ "$mounted" = "no" ]; then
      echo "Mounting $dataset..."
      zfs mount "$dataset" || true
    fi

    if [ -n "$user" ] && [ "$user" != "null" ]; then
      mountpoint=$(zfs get -H -o value mountpoint "$dataset")
      if [ -n "$mountpoint" ] && [ "$mountpoint" != "none" ] && [ "$mountpoint" != "legacy" ]; then
        if [ "$is_new" = "true" ]; then
          echo "Changing ownership of $mountpoint recursively to $user:users..."
          chown -R "$user:users" "$mountpoint"
        fi
      fi
    fi
  fi
done
