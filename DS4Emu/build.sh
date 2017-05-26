#!/bin/bash

python DS4Emu/shockemu.py $1
#clang -dynamiclib -std=gnu99 iohid_wrap.m  -current_version 1.0 -compatibility_version 1.0 -lobjc -framework UIKit -framework Quartz -framework Foundation -framework AppKit -framework CoreFoundation  -o iohid_wrap.dylib
