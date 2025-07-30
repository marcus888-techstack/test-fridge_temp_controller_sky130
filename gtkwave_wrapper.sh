#!/bin/bash
# GTKWave wrapper script for macOS
# This avoids the Perl dependency issue

if [ $# -eq 0 ]; then
    echo "Usage: $0 <vcd_file>"
    exit 1
fi

# Use the GTKWave application directly
open -a gtkwave "$@"