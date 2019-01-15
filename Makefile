include config.make

# Warning options will vary significantly between projects, depending both
# on design and on code quality. As a rule, try to enable as many as you
# can - GCC has hundreds, many poorly documented. This is what I start with.
#
# I use `-Werror=foo -Werror=bar` rather than using `-Werror -Wfoo -Wbar`,
# to make it possible to add (non-fatal) warnings as well, although this
# usually doesn't happen in release code.
#
# Alternatively, don't use any `-W` options, and use
# `CFLAGS += -include warnings.h` to add a header full of
# `#pragma GCC diagnostic error` lines.
#
# If only a small amount of code needs an exception and there isn't a better
# way to suppress it, use `#pragma GCC diagnostic push ... ignore ... pop`.
# Note that `_Pragma` can be generated from a macro.
WARNINGS =

# Any sensible source can usually survive both of these.
WARNINGS += -Werror=all -Werror=extra

# Use `__attribute__((format))` and `__attribute__((format_arg))`.
WARNINGS += -Werror=format=2

# Specify __attribute__((unused)) as needed.
WARNINGS += -Werror=unused -Werror=unused-result

# These help enforce "every non-static function must be declared exactly
# once, usually in a header", which is extremely useful for enforcing good
# design. Most in-the-wild code doesn't quite match this, but can be
# converted easily.
WARNINGS += -Werror=missing-declarations -Werror=redundant-decls

# Usually a bug.
WARNINGS += -Werror=undef

# You can specify language-specific warnings too.
C_WARNINGS = ${WARNINGS}
CXX_WARNINGS = ${WARNINGS}

# Let's make this one non-fatal. Maybe you're vendoring code (ugh).
C_WARNINGS += -Wc++-compat

# Use `const`, people!
C_WARNINGS += -Werror=write-strings

# Use an explicit case
C_WARNINGS += -Werror=int-conversion


# Force the warnings even when CFLAGS is specified on the command line.
# Distros might hate this, but I'd rather have the potential bugs be caught
# and reported.
override CFLAGS += ${C_WARNINGS}
override CXXFLAGS += ${CXX_WARNINGS}

# Multiply-defined symbols are usually a bug.
override CFLAGS += -fno-common

# Mandatory for well-behaved shared libraries; harmless for executables.
# Use `__attribute__((visibility))` to override for a single function, or
# `#pragma GCC visibility push(default) ... pop` to override for many.
# Normally a single pragma pair around each installed header is all you need.
override CFLAGS += -fvisibility=hidden

# Emit dependency fragments automatically, as we go, named obj/whatever.c.d
# -MP is needed so you can safely remove header files.
override CFLAGS += -MMD -MP
override CXXFLAGS += -MMD -MP

# These are our to-be-installed headers.
override CPPFLAGS += -I ${include}


## The heart of the makefile
# Things make has trouble with. Also remember dollar signs.
empty =
space = ${empty} ${empty}
comma = ,


define source-to-object
$(patsubst ${src}/%,obj/%.o,$1)
endef

# Likely point of customization, depending on what the filenames of your
# `main()`-containing sources look like, compared to the binary names.
#
# Reading a dynamically-computed variable name is a perfectly valid option.
define source-to-binary
$(addprefix bin/,$(subst /,-,$(patsubst ${src}/%,%,$(basename $1))))
endef


# mumble mumble
define dir-of
$(dir $(patsubst %/,%,$1))
endef
# This $(foreach) is just to define a named variable.
# Recursive programming languages are annoying.
# Note that this function expands to $d!
define create-one-dir-rule
$(foreach d,$(filter-out ./,$(call dir-of,$1)),$d$(eval $1: | $d))
endef

# Arguments:
#   $1 = files or directories to create a rule for
#   $2 = files or directories we have already created rules for (optional)
#
# Explanation of this function:
#   $(if $1,$(call create-dir-rules,...))
#     This is the basic structure of recursion.
#
#   $(sort $(foreach f,...))
#     For each file/directory $f that is in $1 but not in $2:
#       Get $d, the directory of $f, unless that would be `./`.
#       Create a rule, `$f: | $d`.
#       Collect the values of $d.
#     The collected values of $d are passed as $1 for the next level.
#
#   $(sort $(filter ...) ...)
#     This adds any directories in $1 to $2 for the next level.
define create-dir-rules
$(if $1,$(call create-dir-rules,$(sort $(foreach f,$(filter-out $2,$1),$(call create-one-dir-rule,$f))),$(sort $(filter %/,$1) $2)))
endef

src = ${configure-dir}/src
include = ${configure-dir}/include
all-sources := $(shell find ${src} -name '*.c' -o -name '*.cpp')
# Maybe write a $(filter) if they're predictably named.
# We do NOT want to do something like `rgrep -l 'main('`, reading all files
# can be slow, but just directories is fine.
# Mumble mumble, if only make supported adding rules from within a rule ...
main-sources := ${src}/toplevel-main.c ${src}/nested/c-main.c ${src}/nested/cxx-main.cpp
common-sources := $(filter-out ${main-sources},${all-sources})
main-objects := $(call source-to-object,${main-sources})
common-objects := $(call source-to-object,${common-sources})
all-objects := ${main-objects} ${common-objects}
all-depfiles := $(patsubst %.o,%.d,${all-objects})
binaries := $(call source-to-binary,${main-sources})

all: ${binaries}
$(foreach m,${main-sources},$(eval $(call source-to-binary,$m): $(call source-to-object,$m)))
$(call create-dir-rules,${binaries})
$(call create-dir-rules,${all-objects})
${binaries}: ${common-objects}

%/:
	mkdir $@
test:
clean:
	rm -rf bin/ lib/ obj/
# TODO: if you add generated files, delete them in `distclean`.
distclean: clean


## Rules
cxx-or-cc = $(if $(filter %.cpp.o,$^),${CXX},${CC})
bin/%:
	${cxx-or-cc} ${LDFLAGS} $^ ${LDLIBS} -o $@
lib/%.a:
	rm -f $@
	ar cr $@ $^
lib/%.so: lib/%.a
	rm -f $@
	${cxx-or-cc} -Wl,-soname,%*.so.0 -shared ${LDFLAGS} -Wl,--push-state -Wl,-whole-archive $^ -Wl,--pop-state ${LDLIBS} -o $@.0
	chmod -x $@.0
	ln -s $*.so.0 $@
# force -fPIC for shared libraries
obj/%.c.o: ${src}/%.c
	${CC} -fPIC ${CPPFLAGS} ${CFLAGS} -c -o $@ $<
obj/%.cpp.o: ${src}/%.cpp
	${CXX} -fPIC ${CPPFLAGS} ${CXXFLAGS} -c -o $@ $<

-include ${all-depfiles}
