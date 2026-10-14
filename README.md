# cups-printers

A small command-line utility for inspecting printers configured in CUPS.

The script is intended as a lightweight command-line alternative to parts of the traditional CUPS web interface. It lists configured printer queues and can show the PPD, device URI, and printer-specific default options.

It works without administrator privileges.

## Requirements

The script requires a system with CUPS client utilities installed:

- `lpstat`
- `lpoptions`

It also uses standard Unix tools such as `awk` and `sed`.

The script is written for POSIX `/bin/sh` and should work on both macOS and Linux systems using CUPS.

## Usage

Make the script executable:

```sh
chmod +x cups-printers.sh
```

### List printers

```sh
./cups-printers.sh
```

Example:

```text
QUEUE                    DEF STATUS     DESCRIPTION                  DEVICE                                     PPD
------------------------ --- ---------- ---------------------------- ------------------------------------------ ---------------------------------------------
color_cs_lth_se              idle       color.cs.lth.se              lpd://color.cs.lth.se/                     /etc/cups/ppd/color_cs_lth_se.ppd
LU-Canon                 yes idle       LU-Canon                     lpd://print.example.org/lu-canon           /etc/cups/ppd/LU-Canon.ppd
plotter_eit_lth_se           idle       plotter.eit.lth.se           lpd://plotter.eit.lth.se/                  /etc/cups/ppd/plotter_eit_lth_se.ppd
```

`DEF` indicates the default printer.

### Show details for a printer

```sh
./cups-printers.sh color_cs_lth_se
```

Example:

```text
Queue:         color_cs_lth_se
Default:       no
Status:        idle
Description:   color.cs.lth.se
Device URI:    lpd://color.cs.lth.se/
PPD:           /etc/cups/ppd/color_cs_lth_se.ppd

Selected defaults:

  PageSize:                A4
  Duplex:                  DuplexNoTumble (long-edge)
```

The normal detail view shows a small set of commonly useful printer options.

### Show all printer options

```sh
./cups-printers.sh color_cs_lth_se --options
```

This displays all printer-specific options reported by:

```sh
lpoptions -p color_cs_lth_se -l
```

For example:

```text
Printer options:

  PageSize:                A4
  InputSlot:               Auto
  MediaType:               Plain
  Duplex:                  DuplexNoTumble (long-edge)
  Resolution:              600dpi
  ColorModel:              Gray
```

## Duplex terminology

Traditional PPD files commonly use the following values:

| Value | Meaning |
|---|---|
| `None` | One-sided printing |
| `DuplexNoTumble` | Two-sided, long-edge binding |
| `DuplexTumble` | Two-sided, short-edge binding |

Long-edge binding is the usual book-style duplex mode.

## Changing printer defaults

`lpoptions` can be used to set defaults for the current user.

For example, to make A4 the default paper size:

```sh
lpoptions -p color_cs_lth_se -o PageSize=A4
```

Check the result with:

```sh
lpoptions -p color_cs_lth_se -l | grep '^PageSize/'
```

The selected value is marked with `*`, for example:

```text
PageSize/Media Size: Letter Legal *A4 A5
```

To remove the per-user override:

```sh
lpoptions -p color_cs_lth_se -r PageSize
```

### Per-user versus system defaults

When `lpoptions` is run as a normal user, settings are stored as per-user defaults, normally in:

```text
~/.cups/lpoptions
```

They override the defaults configured on the CUPS server for that user.

The script does not require administrator privileges and reports the effective printer options seen by the user running it.

Changing the system-wide or server-side defaults normally requires administrative privileges.

## Printing with a temporary option

An option can also be specified for a single print job without changing any defaults.

For example:

```sh
lp -d color_cs_lth_se -o media=A4 document.pdf
```

or for long-edge duplex printing:

```sh
lp -d color_cs_lth_se -o sides=two-sided-long-edge document.pdf
```

## PPD files and driverless printing

Traditional CUPS printer queues generally use a PPD file, commonly located under:

```text
/etc/cups/ppd/
```

On macOS the same directory may internally appear as:

```text
/private/etc/cups/ppd/
```

The script obtains the interface/PPD information reported by CUPS rather than reading the PPD directory directly, so administrator privileges are not required.

Modern CUPS installations increasingly use driverless IPP printing. Such queues may not have a traditional PPD file. In that case the script may display `-` for the PPD.

## Portability

The script uses standard CUPS command-line tools and POSIX shell syntax.

It should therefore work on:

- macOS with CUPS
- Linux distributions using CUPS

The most portable parts are the information obtained using:

```sh
lpstat -p
lpstat -v
lpstat -d
lpoptions -p PRINTER -l
```

Some details from the long `lpstat` output, particularly the reported PPD/interface path, can vary between CUPS versions and operating systems.

The script sets:

```sh
LC_ALL=C
```

to make parsing of CUPS command output independent of the user's locale.

## License

BSD 2-Clause "Simplified" License
