## sensible defaults, slightly changed from Make's hardcoded ones

# If you have a real ./configure script, it should replace this file, or else
# generate a file with this name in another directory and copy the Makefile.

CC = gcc
CXX = g++
# Put `pkg-config --cflags-only-other` in both of these,
# but that is usually empty and not necessarily well-behaved if it isn't.
CFLAGS = -g -O2
CXXFLAGS = -g -O2
# Put `pkg-config --cflags-only-I` here. However, you should probably change
# them to `-isystem` to avoid picking up warnings from them.
CPPFLAGS =
# Put `pkg-config --libs-only-other --libs-only-L` here.
LDFLAGS = -O1 -Wl,-rpath,'$${ORIGIN}/../lib'
# Put `pkg-config --libs-only-l` here.
LDLIBS =

configure-dir = .
