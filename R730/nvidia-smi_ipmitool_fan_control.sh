#!/bin/bash

USER=root
PASS=CHANGE_ME
IP=CHANGE_ME
MIN_TEMP=55
MAX_TEMP=75

# Set the fan speed controller into fixed speed mode
ipmitool -I lanplus -U $USER -P $PASS -H $IP raw 0x30 0x30 0x01 0x00

# Get the current fan speed from ipmi
current_speed=$(ipmitool -I lanplus -U $USER -P $PASS -H $IP sensor reading "Fan1" | awk -F'|' '{print $2}' | tr -d ' ')

# Get the (average) GPU temperature using nvidia-smi
temperature=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader | awk '{sum += $1} END {print int(sum/NR + 0.5)}')

# Convert current_speed into levels and set the corresponding current_speed_level
if [ $current_speed -lt 4000 ]; then
    current_speed_level="0xa"  # Hexadecimal for 10
    level=1
elif [ $current_speed -lt 6800 ]; then
    current_speed_level="0x1e" # Hexadecimal for 30
    level=2
elif [ $current_speed -lt 10000 ]; then
    current_speed_level="0x32" # Hexadecimal for 50
    level=3
elif [ $current_speed -lt 13000 ]; then
    current_speed_level="0x50" # Hexadecimal for 80
    level=4
else
    current_speed_level="0x64" # Hexadecimal for 100
    level=5
fi

# Set adjust_speed_level based on temperature range
adjust_speed_level=$current_speed_level

if [ $temperature -lt $MIN_TEMP ]; then
    # Decrease the level, if possible
    if [ $level -gt 1 ]; then
        case $level in
            2) adjust_speed_level="0xa";;
            3) adjust_speed_level="0x1e";;
            4) adjust_speed_level="0x32";;
            5) adjust_speed_level="0x50";;
        esac
    fi
elif [ $temperature -gt $MAX_TEMP ]; then
    # Increase the level, if possible
    if [ $level -lt 5 ]; then
        case $level in
            1) adjust_speed_level="0x1e";;
            2) adjust_speed_level="0x32";;
            3) adjust_speed_level="0x50";;
            4) adjust_speed_level="0x64";;
        esac
    fi
fi

# Print debug information
echo "Temperature: $temperature"
echo "Current Speed: $current_speed"
echo "Current Speed Level: $current_speed_level (Level $level)"
echo "Adjusted Speed Level: $adjust_speed_level"

# Change the fan speed with ipmitool
ipmitool -I lanplus -U $USER -P $PASS -H $IP raw 0x30 0x30 0x02 0xff $adjust_speed_level