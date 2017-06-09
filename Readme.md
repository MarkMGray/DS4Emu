Setup
=====

DS4Emu requires the OS X command line development tools to be installed.  Installation steps:

	git clone https://github.com/MarkMGray/DS4Emu.git
	./build.sh <filename>.se
	./run.sh

It depends on your system having a DS4 controller connected to your Mac and PS4 Remote Play installed at `/Applications/RemotePlay.app`.  If this is not the case, you'll need to modify `run.sh` accordingly.

SE file format
==============

SE files are, generally speaking, a mapping between an input key, mouse button, or mouse movement to a DualShock 4 input.  See the example file (`destiny.se`) for a breakdown of the format.

How it works
============

DS4Emu works by intercepting the parseInputReport method of the PS4 Remote Play application and presents an emulated DualShock controller.  It also hooks into the input routines of the application, to catch keyboard and mouse inputs, which then get mapped according to your SE file.
