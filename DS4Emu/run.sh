#!/bin/bash

DYLD_FORCE_FLAT_NAMESPACE=1 DYLD_INSERT_LIBRARIES=../Debug/libDS4Emu.dylib /Applications/RemotePlay.app/Contents/MacOS/RemotePlay
