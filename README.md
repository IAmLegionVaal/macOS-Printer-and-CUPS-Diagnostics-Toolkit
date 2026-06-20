# macOS Printer and CUPS Diagnostics Toolkit

A read-only Bash toolkit for auditing CUPS services, printer queues, jobs, drivers, PPDs, sharing, connectivity, and recent printing errors.

## Usage

```bash
chmod +x src/macos_printer_diagnostics.sh
sudo ./src/macos_printer_diagnostics.sh
```

Test a printer host:

```bash
sudo ./src/macos_printer_diagnostics.sh --printer-host 192.168.1.217 --port 9100
```

## Checks performed

- CUPS daemon and launchd state
- Configured printers, default printer, queues, and jobs
- Printer URIs, drivers, PPDs, and CUPS configuration
- Optional DNS, ping, IPP, and raw-print-port tests
- Recent CUPS and print-service events
- Text, CSV, and JSON reports

## Safety

The script never adds, removes, enables, disables, pauses, resumes, cancels, or modifies printers and jobs.

## Author

Dewald Pretorius — L2 IT Support Engineer
