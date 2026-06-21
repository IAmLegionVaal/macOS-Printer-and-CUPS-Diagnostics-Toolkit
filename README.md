# macOS Printer and CUPS Diagnostics Toolkit

A macOS support toolkit for auditing and repairing common CUPS, printer queue and print-job problems.

## Diagnostic script

```bash
chmod +x src/macos_printer_diagnostics.sh
sudo ./src/macos_printer_diagnostics.sh
```

Test a printer host:

```bash
sudo ./src/macos_printer_diagnostics.sh --printer-host 192.168.1.217 --port 9100
```

## Repair script

Restart CUPS:

```bash
chmod +x src/macos_printer_repair.sh
sudo ./src/macos_printer_repair.sh --restart-cups
```

Enable and resume one printer queue:

```bash
sudo ./src/macos_printer_repair.sh \
  --printer Printer_Name \
  --enable \
  --resume
```

Cancel all jobs for one queue:

```bash
sudo ./src/macos_printer_repair.sh \
  --printer Printer_Name \
  --cancel-all
```

Set the default printer:

```bash
./src/macos_printer_repair.sh \
  --printer Printer_Name \
  --set-default
```

Use `--dry-run` to preview changes.

## What the repair does

- Restarts the CUPS printing service.
- Enables a selected printer queue.
- Resumes a selected queue.
- Can cancel all jobs for one selected printer after confirmation.
- Can set the default printer.
- Writes logs and performs post-repair queue verification.

## Safety and limitations

The repair does not add or remove printers, change drivers or edit PPD files automatically. Cancelling jobs requires explicit confirmation. Driver, firmware, network and hardware faults may still require separate repair.

## Author

Dewald Pretorius — L2 IT Support Engineer
