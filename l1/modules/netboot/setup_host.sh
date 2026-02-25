# shellcheck shell=bash
MAC=$1
KERNEL=$2
INITRD=$3
IPXESCRIPT=$4
ROOT_DIR=$5

FILE_DIR="$ROOT_DIR/v1/file/$MAC"
BOOT_FILE="$ROOT_DIR/v1/boot/$MAC"

mkdir -p "$FILE_DIR"
ln -sf "$KERNEL" "$FILE_DIR/kernel"
ln -sf "$INITRD" "$FILE_DIR/initrd"

# Extract init=... from ipxe script.
# IPXESCRIPT is a directory containing netboot.ipxe.
CMDLINE=$(grep -ohP 'init=\S+' "$IPXESCRIPT/netboot.ipxe")

cat <<EOF >"$BOOT_FILE"
{
  "kernel": "/v1/file/$MAC/kernel",
  "initrd": ["/v1/file/$MAC/initrd"],
  "cmdline": "$CMDLINE loglevel=4"
}
EOF
