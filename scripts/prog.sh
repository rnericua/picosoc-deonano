#!/bin/sh
# Program a DE0-Nano SOF over the onboard USB-Blaster.
# Usage: scripts/prog.sh [path/to/file.sof]
set -e
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
SOF=${1:-$ROOT/quartus/output_files/de0nano.sof}
if [ ! -f "$SOF" ]; then
	echo "missing SOF: $SOF" >&2
	echo "build with: make quartus   or   make quartus-blink" >&2
	exit 1
fi
if ! command -v quartus_pgm >/dev/null 2>&1; then
	echo "quartus_pgm not on PATH (need Quartus Prime Lite)" >&2
	exit 1
fi
exec quartus_pgm -m jtag -o "p;$SOF"
