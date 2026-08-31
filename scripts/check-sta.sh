#!/bin/sh
# PR-2 merge gate: Slow 1200mV 85C Fmax of CLOCK_50 must be >= 50 MHz.
# Usage: scripts/check-sta.sh [path/to/de0nano.sta.rpt]
set -e
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
RPT=${1:-$ROOT/quartus/output_files/de0nano.sta.rpt}
if [ ! -f "$RPT" ]; then
	echo "missing STA report: $RPT" >&2
	echo "run: make quartus && make sta" >&2
	exit 1
fi

python3 - "$RPT" <<'PY'
import re, sys

rpt = sys.argv[1]
text = open(rpt, errors="replace").read()
# Quartus TimeQuest Slow 85C Fmax table. Restricted Fmax is the one that matters.
# Example:
# ; Slow 1200mV 85C Model Fmax Summary
# ; Fmax ; Restricted Fmax ; Clock Name ; Note
# ; 62.31 MHz ; 62.31 MHz ; CLOCK_50 ;
pat = re.compile(
    r"Slow 1200mV 85C Model Fmax Summary.*?CLOCK_50",
    re.S | re.I,
)
m = pat.search(text)
if not m:
    # Fall back: any CLOCK_50 Fmax line near a Slow 85C heading.
    print("could not find 'Slow 1200mV 85C Model Fmax Summary' / CLOCK_50 in", rpt, file=sys.stderr)
    sys.exit(2)

block = m.group(0)
nums = re.findall(r"([0-9]+(?:\.[0-9]+)?)\s*MHz", block)
if len(nums) < 2:
    print("could not parse Fmax numbers for CLOCK_50:\n", block, file=sys.stderr)
    sys.exit(2)

restricted = float(nums[1] if len(nums) >= 2 else nums[0])
print("Slow 1200mV 85C Restricted Fmax (CLOCK_50) = %.2f MHz" % restricted)
if restricted + 1e-9 < 50.0:
    print(
        "FAIL: need >= 50 MHz. Set VERILOG_MACRO BARREL_SHIFTER_OFF=1 in "
        "quartus/de0nano.qsf, rebuild, stay at 50 MHz / UART 434. "
        "Do not add a 25 MHz PLL in PR-2.",
        file=sys.stderr,
    )
    sys.exit(1)
print("PASS: Fmax >= 50 MHz")
PY
