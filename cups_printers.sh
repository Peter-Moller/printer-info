#!/bin/sh

# cups-printers.sh
#
# Display CUPS printer queues and printer options without requiring root.
#
# Usage:
#
#   cups-printers.sh
#       Compact overview of all configured queues.
#
#   cups-printers.sh PRINTER
#       Detailed information plus selected interesting defaults.
#
#   cups-printers.sh PRINTER --options
#       Detailed information plus ALL printer-specific options
#       and their currently selected/default values.
#
# Examples:
#
#   ./cups-printers.sh
#   ./cups-printers.sh color_cs_lth_se
#   ./cups-printers.sh color_cs_lth_se --options
#
# Uses only:
#   lpstat
#   lpoptions
#   awk
#   sed
#
# No administrator privileges are required.

LC_ALL=C
export LC_ALL


get_default_printer()
{
    lpstat -d 2>/dev/null |
        sed 's/^system default destination: //'
}


get_device()
{
    printer=$1

    lpstat -v "$printer" 2>/dev/null |
        sed "s/^device for ${printer}: //"
}


get_longinfo()
{
    printer=$1
    lpstat -l -p "$printer" 2>/dev/null
}


get_field()
{
    field=$1

    awk -v field="$field" '
        {
            line=$0
            sub(/^[ \t]*/, "", line)

            prefix=field ":"

            if (index(line, prefix) == 1) {
                sub("^[^:]*:[ \t]*", "", line)
                print line
                exit
            }
        }
    '
}


get_status()
{
    printer=$1

    line=$(lpstat -p "$printer" 2>/dev/null | head -1)

    case "$line" in
        *" is idle"*)
            echo "idle"
            ;;
        *" printing "*)
            echo "printing"
            ;;
        *" disabled "*)
            echo "disabled"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}


show_summary()
{
    default_printer=$(get_default_printer)

    printf "%-24s %-3s %-10s %-28s %-42s %s\n" \
        "QUEUE" \
        "DEF" \
        "STATUS" \
        "DESCRIPTION" \
        "DEVICE" \
        "PPD"

    printf "%-24s %-3s %-10s %-28s %-42s %s\n" \
        "------------------------" \
        "---" \
        "----------" \
        "----------------------------" \
        "------------------------------------------" \
        "---------------------------------------------"

    lpstat -p 2>/dev/null |
    while IFS= read -r line
    do
        printer=$(printf '%s\n' "$line" | awk '{print $2}')

        [ -n "$printer" ] || continue

        status=$(get_status "$printer")

        if [ "$printer" = "$default_printer" ]; then
            def="yes"
        else
            def=""
        fi

        device=$(get_device "$printer")

        longinfo=$(get_longinfo "$printer")

        description=$(
            printf '%s\n' "$longinfo" |
                get_field "Description"
        )

        interface=$(
            printf '%s\n' "$longinfo" |
                get_field "Interface"
        )

        if [ -n "$interface" ]; then
            ppd=$interface
        else
            ppd="-"
        fi

        printf "%-24.24s %-3s %-10.10s %-28.28s %-42.42s %s\n" \
            "$printer" \
            "$def" \
            "$status" \
            "$description" \
            "$device" \
            "$ppd"
    done
}


#
# Convert some rather cryptic CUPS/PPD values to something
# easier to understand.
#
pretty_value()
{
    keyword=$1
    value=$2

    case "$keyword:$value" in

        Duplex:DuplexNoTumble)
            printf "%s" "DuplexNoTumble (long-edge)"
            ;;

        Duplex:DuplexTumble)
            printf "%s" "DuplexTumble (short-edge)"
            ;;

        Duplex:None)
            printf "%s" "None (one-sided)"
            ;;

        sides:two-sided-long-edge)
            printf "%s" "two-sided-long-edge"
            ;;

        sides:two-sided-short-edge)
            printf "%s" "two-sided-short-edge"
            ;;

        sides:one-sided)
            printf "%s" "one-sided"
            ;;

        *)
            printf "%s" "$value"
            ;;
    esac
}


#
# Parse lpoptions -l.
#
# Input examples:
#
#   PageSize/Media Size: Letter Legal *A4 A5
#   Duplex/Two-Sided: None *DuplexNoTumble DuplexTumble
#
# Produces:
#
#   PageSize    A4
#   Duplex      DuplexNoTumble
#
print_options()
{
    printer=$1
    mode=$2

    lpoptions -p "$printer" -l 2>/dev/null |
    awk -v mode="$mode" '
        {
            colon=index($0, ":")

            if (!colon)
                next

            left=substr($0, 1, colon-1)
            right=substr($0, colon+1)

            keyword=left
            sub(/\/.*/, "", keyword)

            #
            # In normal detail mode, show only the options
            # that are generally interesting.
            #
            if (mode != "all") {
                if (keyword != "PageSize" &&
                    keyword != "Duplex" &&
                    keyword != "ColorModel" &&
                    keyword != "ColorMode" &&
                    keyword != "sides" &&
                    keyword != "media")
                    next
            }

            n=split(right, choices, /[ \t]+/)

            selected=""

            for (i=1; i<=n; i++) {
                if (choices[i] ~ /^\*/) {
                    selected=choices[i]
                    sub(/^\*/, "", selected)
                    break
                }
            }

            if (selected != "")
                print keyword "\t" selected
        }
    ' |
    while IFS='	' read -r keyword value
    do
        value=$(pretty_value "$keyword" "$value")
        printf "  %-24s %s\n" "$keyword:" "$value"
    done
}


show_details()
{
    printer=$1
    option_mode=$2

    if ! lpstat -p "$printer" >/dev/null 2>&1; then
        echo "No such CUPS printer: $printer" >&2
        exit 1
    fi

    default_printer=$(get_default_printer)
    status=$(get_status "$printer")
    device=$(get_device "$printer")
    longinfo=$(get_longinfo "$printer")

    description=$(
        printf '%s\n' "$longinfo" |
            get_field "Description"
    )

    location=$(
        printf '%s\n' "$longinfo" |
            get_field "Location"
    )

    interface=$(
        printf '%s\n' "$longinfo" |
            get_field "Interface"
    )

    if [ "$printer" = "$default_printer" ]; then
        is_default="yes"
    else
        is_default="no"
    fi

    printf "%-14s %s\n" "Queue:" "$printer"
    printf "%-14s %s\n" "Default:" "$is_default"
    printf "%-14s %s\n" "Status:" "$status"

    if [ -n "$description" ]; then
        printf "%-14s %s\n" "Description:" "$description"
    fi

    if [ -n "$location" ]; then
        printf "%-14s %s\n" "Location:" "$location"
    fi

    printf "%-14s %s\n" "Device URI:" "$device"

    if [ -n "$interface" ]; then
        printf "%-14s %s\n" "PPD:" "$interface"
    else
        printf "%-14s %s\n" "PPD:" "-"
    fi

    echo

    if [ "$option_mode" = "all" ]; then
        echo "Printer options:"
    else
        echo "Selected defaults:"
    fi

    echo

    print_options "$printer" "$option_mode"
}


usage()
{
    echo "Usage:" >&2
    echo "  $0" >&2
    echo "  $0 PRINTER" >&2
    echo "  $0 PRINTER --options" >&2
    exit 1
}


case $# in

    0)
        show_summary
        ;;

    1)
        show_details "$1" "selected"
        ;;

    2)
        if [ "$2" = "--options" ]; then
            show_details "$1" "all"
        else
            usage
        fi
        ;;

    *)
        usage
        ;;
esac
