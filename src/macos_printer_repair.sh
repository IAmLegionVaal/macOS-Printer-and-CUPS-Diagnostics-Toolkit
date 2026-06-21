#!/bin/bash
set -u

RESTART_CUPS=false
PRINTER=""
RESUME=false
ENABLE=false
CANCEL_ALL=false
SET_DEFAULT=false
DRY_RUN=false
ASSUME_YES=false
OUTPUT_DIR=""
FAILURES=0
ACTIONS=0

usage() {
  cat <<'EOF'
Usage: macos_printer_repair.sh [options]

  --restart-cups          Restart the CUPS printing service.
  --printer NAME          Target printer queue.
  --resume                Resume the selected printer queue.
  --enable                Enable the selected printer queue.
  --cancel-all            Cancel all jobs for the selected printer.
  --set-default           Set the selected printer as default.
  --dry-run               Show commands without changing the Mac.
  --yes                   Skip confirmation prompts.
  --output DIR            Save logs and verification output in DIR.
  -h, --help              Show help.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --restart-cups) RESTART_CUPS=true; shift ;;
    --printer) PRINTER="${2:-}"; shift 2 ;;
    --resume) RESUME=true; shift ;;
    --enable) ENABLE=true; shift ;;
    --cancel-all) CANCEL_ALL=true; shift ;;
    --set-default) SET_DEFAULT=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --yes) ASSUME_YES=true; shift ;;
    --output) OUTPUT_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

[ "$(uname -s)" = "Darwin" ] || { echo "This tool must run on macOS." >&2; exit 3; }
if ! $RESTART_CUPS && ! $RESUME && ! $ENABLE && ! $CANCEL_ALL && ! $SET_DEFAULT; then echo "Choose at least one repair action." >&2; exit 2; fi
if { $RESUME || $ENABLE || $CANCEL_ALL || $SET_DEFAULT; } && [ -z "$PRINTER" ]; then echo "--printer is required for queue actions." >&2; exit 2; fi
if [ -n "$PRINTER" ]; then
  /usr/bin/lpstat -p "$PRINTER" >/dev/null 2>&1 || { echo "Printer queue not found: $PRINTER" >&2; exit 2; }
fi

STAMP="$(date +%Y%m%d_%H%M%S)"
OUTPUT_DIR="${OUTPUT_DIR:-./printer-repair-$STAMP}"
mkdir -p "$OUTPUT_DIR"
LOG="$OUTPUT_DIR/repair.log"
VERIFY="$OUTPUT_DIR/verification.txt"
: > "$LOG"

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG"; }
confirm() {
  $ASSUME_YES && return 0
  printf '%s [y/N]: ' "$1"
  read -r answer
  case "$answer" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}
run_action() {
  description="$1"; shift
  ACTIONS=$((ACTIONS + 1)); log "$description"
  if $DRY_RUN; then
    printf 'DRY-RUN:' >> "$LOG"; for arg in "$@"; do printf ' %q' "$arg" >> "$LOG"; done; printf '\n' >> "$LOG"; return 0
  fi
  if "$@" >> "$LOG" 2>&1; then log "SUCCESS: $description"; return 0; fi
  FAILURES=$((FAILURES + 1)); log "WARNING: $description failed"; return 1
}
run_admin() {
  description="$1"; shift
  if [ "$(id -u)" -eq 0 ]; then run_action "$description" "$@"; else run_action "$description" /usr/bin/sudo "$@"; fi
}
verify() {
  {
    echo "Collected: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "CUPS process:"
    ps -Ao pid,user,etime,comm,args | grep -E '[c]upsd' || true
    echo
    echo "Printers:"
    /usr/bin/lpstat -p -d 2>&1 || true
    echo
    echo "Jobs:"
    /usr/bin/lpstat -o 2>&1 || true
    if [ -n "$PRINTER" ]; then
      echo
      echo "Target printer:"
      /usr/bin/lpstat -p "$PRINTER" -l 2>&1 || true
      /usr/bin/lpoptions -p "$PRINTER" 2>&1 || true
    fi
  } > "$VERIFY" 2>&1
}

verify
if ! confirm "Apply the selected printer repairs?"; then log "Repair cancelled."; exit 10; fi

if $RESTART_CUPS; then
  run_admin "Restarting CUPS" /bin/launchctl kickstart -k system/org.cups.cupsd || \
    run_admin "Requesting CUPS process restart" /usr/bin/killall cupsd || true
fi
if $ENABLE; then run_admin "Enabling printer $PRINTER" /usr/sbin/cupsenable "$PRINTER" || true; fi
if $RESUME; then run_admin "Resuming printer $PRINTER" /usr/sbin/cupsaccept "$PRINTER" || true; fi
if $CANCEL_ALL && confirm "Cancel all jobs for $PRINTER?"; then run_admin "Cancelling all jobs for $PRINTER" /usr/bin/cancel -a "$PRINTER" || true; fi
if $SET_DEFAULT; then run_action "Setting default printer to $PRINTER" /usr/bin/lpoptions -d "$PRINTER" || true; fi

if ! $DRY_RUN; then sleep 4; fi
verify
if [ "$FAILURES" -gt 0 ]; then log "Repair completed with $FAILURES warning(s)."; exit 20; fi
log "Repair completed successfully. Actions performed: $ACTIONS"
exit 0
