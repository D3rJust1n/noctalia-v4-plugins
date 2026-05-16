# Noctalia Battery & Power Management Widget

An elegant, low-overhead battery monitoring and hardware optimization widget built for the **Noctalia** environment via Quickshell (Qt6/QML). 

It reads battery diagnostics directly from kernel structures, updates platform power rules using `power-profiles-ctl`, and sets real-time hardware charging thresholds without requiring root wrapping at run time.

## Key Features

- **Status Bar Integration**: Displays raw percentage, live draw/charge rate in Watts (`W`), and contextual charging geometry.
- **ACPI Performance Profiles**: Switches execution environments smoothly between `power-saver`, `balanced`, and `performance` via DBus tools.
- **Battery Threshold Regulation**: A robust, lightweight custom slider constraining maximum charge levels from `50%` to `100%` (processed in steps of 5) to expand lithium-ion operational lifespan.

## Device Node Access & Security Policies

To bypass interactive security barriers or elevated execution wrappers when altering kernel sysfs states, write permissions are offloaded directly to device node rules.

### Configuring the Udev Layer

Ensure your environment populates `/etc/udev/rules.d/99-battery-threshold.rules` with policies that transfer target group permissions upon system initialization:

```udev
ACTION=="add", SUBSYSTEM=="power_supply", KERNEL=="BAT0", RUN+="/bin/chgrp battery_ctl /sys/class/power_supply/BAT0/charge_control_end_threshold", RUN+="/bin/chmod g+w /sys/class/power_supply/BAT0/charge_control_end_threshold"
