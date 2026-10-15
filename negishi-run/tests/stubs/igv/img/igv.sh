#!/bin/bash
# fake IGV: reads the batch, writes a PNG for each snapshot line; needs DISPLAY like the real one
echo "igv.sh $*" >> "$STUB_LOG"
[ "$1" = -b ] || exit 2
echo "INFO [2026-10-14 10:00:00] [Main] IGV Version 2.19.2 02/28/2025"
[ -n "${DISPLAY:-}" ] || { echo "SEVERE: java.awt.HeadlessException: No X11 DISPLAY variable was set"; exit 1; }
if [ "${STUB_HANG:-0}" = 1 ]; then sleep 30; fi
dir=.
while read -r c a b; do
  case $c in
    snapshotDirectory) dir=$a;;
    load)
      case "$b" in
        index=*) [ -e "${b#index=}" ] || echo "SEVERE: index not found ${b#index=}";;
        *) if [ "${STUB_CSI_ERROR:-0}" = 1 ]; then case $a in *.bam) echo "ERROR: Error loading index file $a.csi: unsupported index";; esac; fi;;
      esac;;
    snapshot) { printf '\211PNG\r\n\032\n'; head -c 20000 /dev/zero; } > "$dir/$a";;
    exit) exit 0;;
  esac
done < "$2"
