#!/bin/bash
set -u

PRINTER_HOST=""
PORT=9100
HOURS=24
OUTPUT_DIR=""
usage(){ echo "Usage: macos_printer_diagnostics.sh [--printer-host HOST] [--port N] [--hours N] [--output DIR]"; }
while [ "$#" -gt 0 ]; do case "$1" in
  --printer-host) PRINTER_HOST="${2:-}"; shift 2;; --port) PORT="${2:-9100}"; shift 2;; --hours) HOURS="${2:-24}"; shift 2;; --output) OUTPUT_DIR="${2:-}"; shift 2;; -h|--help) usage; exit 0;; *) echo "Unknown argument: $1" >&2; exit 2;; esac; done
[ "$(uname -s)" = Darwin ] || { echo "This tool must run on macOS." >&2; exit 1; }
STAMP=$(date +%Y%m%d_%H%M%S); OUTPUT_DIR="${OUTPUT_DIR:-./printer-diagnostics-$STAMP}"; mkdir -p "$OUTPUT_DIR"
REPORT="$OUTPUT_DIR/printer-report.txt"; CSV="$OUTPUT_DIR/printers.csv"; JSON="$OUTPUT_DIR/summary.json"; ERRORS="$OUTPUT_DIR/command-errors.log"; :>"$REPORT"; :>"$ERRORS"
echo 'printer,device_uri,state,accepting,default' > "$CSV"
section(){ t="$1"; shift; { printf '\n===== %s =====\n' "$t"; "$@"; } >>"$REPORT" 2>>"$ERRORS" || true; }
section "Metadata" /bin/bash -c 'date -u +%Y-%m-%dT%H:%M:%SZ; hostname; sw_vers; id'
section "CUPS status" /bin/launchctl print system/org.cups.cupsd
section "Printers" /usr/bin/lpstat -t
section "Printer devices" /usr/sbin/lpinfo -v
section "Drivers" /usr/sbin/lpinfo -m
section "Jobs" /usr/bin/lpstat -W all -o
section "CUPS configuration" /bin/bash -c 'grep -Ev "^[[:space:]]*(#|$)" /etc/cups/cupsd.conf 2>/dev/null || true'
section "PPD inventory" /bin/bash -c 'find /etc/cups/ppd /Library/Printers -maxdepth 3 -type f -print 2>/dev/null | head -n 1000'
section "Recent print events" /bin/bash -c "/usr/bin/log show --last ${HOURS}h --style compact --predicate '(process == \"cupsd\") OR (subsystem CONTAINS[c] \"print\") OR (eventMessage CONTAINS[c] \"printer\")' 2>/dev/null | tail -n 3000"
DEFAULT=$(/usr/bin/lpstat -d 2>/dev/null | sed 's/.*: //')
/usr/bin/lpstat -v 2>/dev/null | while read -r _ printer _ uri; do
  printer=${printer%:}; state=$(/usr/bin/lpstat -p "$printer" 2>/dev/null | head -n1); accepting=$(/usr/bin/lpstat -a "$printer" 2>/dev/null | head -n1)
  is_default=false; [ "$printer" = "$DEFAULT" ] && is_default=true
  printf '"%s","%s","%s","%s","%s"\n' "$printer" "$uri" "${state//\"/\"\"}" "${accepting//\"/\"\"}" "$is_default" >> "$CSV"
done
HOST_REACHABLE=false; PORT_REACHABLE=false
if [ -n "$PRINTER_HOST" ]; then
  section "Printer host ping" /sbin/ping -c 4 "$PRINTER_HOST"
  ping -c 1 "$PRINTER_HOST" >/dev/null 2>&1 && HOST_REACHABLE=true
  if command -v nc >/dev/null 2>&1; then nc -z -w 5 "$PRINTER_HOST" "$PORT" >/dev/null 2>&1 && PORT_REACHABLE=true; fi
fi
PRINTERS=$(awk 'END{print NR-1}' "$CSV"); QUEUED=$(/usr/bin/lpstat -o 2>/dev/null | wc -l | tr -d ' ')
cat > "$JSON" <<EOF
{"collected_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","hostname":"$(hostname)","printers":$PRINTERS,"queued_jobs":$QUEUED,"default_printer":"$DEFAULT","tested_host":"$PRINTER_HOST","host_reachable":$HOST_REACHABLE,"port":$PORT,"port_reachable":$PORT_REACHABLE}
EOF
printf '\nPrinter diagnostics completed: %s\n' "$OUTPUT_DIR" | tee -a "$REPORT"
