This is a demo of how to manage reasonably-large projects with GNU make.

It is assumed that your sources have *some* kind of order, otherwise you'll
still have to specify a lot by yourself.

What is implemented:
* multiple executables
* multiple source directories
* mixed C and C++ sources

What is not implemented:
* shared and static libraries - just need to change $(main-objects) logic
* generated source files - needs to be handled carefully
* complicated cases of library dependencies
* installation - needs more variables in config.make
