#!/usr/bin/env bash
set -e

DATASETS_JSON=$1

echo "$DATASETS_JSON" | jq -c '.[]' | while read -r ds; do
  dataset=$(echo "$ds" | jq -r '.dataset')
  mount=$(echo "$ds" | jq -r '.mount')

  if ! zfs list "$dataset" >/dev/null 2>&1; then
    echo "Creating dataset $dataset..."
    if [ "$mount" = "true" ]; then
      zfs create -o mountpoint="/$dataset" "$dataset"
    else
      zfs create "$dataset"
    fi
  fi
  echo "Dataset $dataset already exists."

  if [ "$mount" = "true" ]; then
    # Ensure the dataset is mounted.
    mounted=$(zfs get -H -o value mounted "$dataset")
    if [ "$mounted" = "no" ]; then
      echo "Mounting $dataset..."
      zfs mount "$dataset" || true
    fi
  fi
done
