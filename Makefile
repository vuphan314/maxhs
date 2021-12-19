###################################################################################################
#  make			 "for release version"
#  make d		 "debug version"
#  make p		 "profiling version"
#  make clean   	 "remove object files and executable"
###################################################################################################
.PHONY:	r d p lr ld lp all install install-bin clean distclean
all: r

## Configurable options ###########################################################################

## Cplex library location (configure these variables)
LINUX_CPLEXLIBDIR   ?= /opt/ibm/ILOG/CPLEX_Studio201/cplex/lib/x86-64_linux/static_pic
LINUX_CPLEXINCDIR   ?= /opt/ibm/ILOG/CPLEX_Studio201/cplex/include
#
#If you want to build on macos
DARWIN_CPLEXLIBDIR   ?= /Users/fbacchus/Applications/IBM/ILOG/CPLEX_Studio128/cplex/lib/x86-64_osx/static_pic/
DARWIN_CPLEXINCDIR   ?= /Users/fbacchus/Applications/IBM/ILOG/CPLEX_Studio128/cplex/include

ifeq "$(shell uname)" "Linux"
CPLEXLIBDIR   =$(LINUX_CPLEXLIBDIR)
CPLEXINCDIR   =$(LINUX_CPLEXINCDIR)
endif
ifeq "$(shell uname)" "Darwin"
CPLEXLIBDIR   =$(DARWIN_CPLEXLIBDIR)
CPLEXINCDIR   =$(DARWIN_CPLEXINCDIR)
endif

# Directory to store object files, libraries, executables, and dependencies:
BUILD_DIR      ?= build

# Include debug-symbols in release builds?
MAXHS_RELSYM ?= -g

# Sat solver you can use minisat of glucose. minisat is faster.for maxhs
SATSOLVER = minisat
#SATSOLVER = glucose

MAXHS_REL    ?= -O3 -flto -D NDEBUG
MAXHS_DEB    ?= -O0 -D DEBUG -D_GLIBCXX_DEBUG -ggdb
MAXHS_PRF    ?= -O3 -D NDEBUG

ifeq "$(SATSOLVER)" "glucose"
MAXHS_REL    += -D GLUCOSE
MAXHS_DEB    += -D GLUCOSE
MAXHS_PRF    += -D GLUCOSE
endif

# Target file names
MAXHS      = maxhs#       Name of Maxhs main executable.
MAXHS_SLIB = lib$(MAXHS).a#  Name of Maxhs static library.

#-DIL_STD is a IBM/CPLEX issue

MAXHS_CXXFLAGS = -DIL_STD -I. -I$(CPLEXINCDIR)
MAXHS_CXXFLAGS += -D __STDC_LIMIT_MACROS -D __STDC_FORMAT_MACROS
MAXHS_CXXFLAGS += -Wall -Wno-parentheses -Wextra -Wno-deprecated
MAXHS_CXXFLAGS += -std=c++14

MAXHS_LDFLAGS  = -Wall -lz -L$(CPLEXLIBDIR) -lcplex -lpthread -ldl

ECHO=@echo

ifeq ($(VERB),)
VERB=@
else
VERB=
endif

SRCS = $(wildcard $(SATSOLVER)/core/*.cc) $(wildcard $(SATSOLVER)/simp/*.cc) $(wildcard $(SATSOLVER)/utils/*.cc) \
       $(wildcard maxhs/core/*.cc) $(wildcard maxhs/ifaces/*.cc) \
       $(wildcard maxhs/utils/*.cc)

ALLSRCS = $(wildcard minisat/core/*.cc) $(wildcard minisat/simp/*.cc) $(wildcard minisat/utils/*.cc) \
$(wildcard glucose/core/*.cc) $(wildcard glucose/simp/*.cc) $(wildcard glucose/utils/*.cc) \
$(wildcard maxhs/core/*.cc) $(wildcard maxhs/ifaces/*.cc) \
$(wildcard maxhs/utils/*.cc)

SATSOLVER_HDRS = $(wildcard $(SATSOLVER)/mtl/*.h) $(wildcard $(SATSOLVER)/core/*.h) \
       $(wildcard $(SATSOLVER)/utils/*.h) $(wildcard $(SATSOLVER)/simp/*.h)
MAXHS_HDRS = $(wildcard maxhs/core/*.h) $(wildcard maxhs/ifaces/*.h) \
       $(wildcard maxhs/ds/*.h) $(wildcard maxhs/utils/*.h)

OBJS = $(filter-out %Main.o, $(SRCS:.cc=.o))

r:	$(BUILD_DIR)/release/bin/$(MAXHS)
d:	$(BUILD_DIR)/debug/bin/$(MAXHS)
p:	$(BUILD_DIR)/profile/bin/$(MAXHS)

lr:	$(BUILD_DIR)/release/lib/$(MAXHS_SLIB)
ld:	$(BUILD_DIR)/debug/lib/$(MAXHS_SLIB)
lp:	$(BUILD_DIR)/profile/lib/$(MAXHS_SLIB)


## Build-type Compile-flags:
$(BUILD_DIR)/release/%.o:			MAXHS_CXXFLAGS +=$(MAXHS_REL) $(MAXHS_RELSYM)
$(BUILD_DIR)/debug/%.o:				MAXHS_CXXFLAGS +=$(MAXHS_DEB) -ggdb
$(BUILD_DIR)/profile/%.o:			MAXHS_CXXFLAGS +=$(MAXHS_PRF) -pg

## Build-type Link-flags:
$(BUILD_DIR)/profile/bin/$(MAXHS):		MAXHS_LDFLAGS += -pg
ifeq "$(shell uname)" "Linux"
$(BUILD_DIR)/release/bin/$(MAXHS):		MAXHS_LDFLAGS += -z muldefs
endif
$(BUILD_DIR)/release/bin/$(MAXHS):		MAXHS_LDFLAGS += $(MAXHS_RELSYM)

## Executable dependencies
$(BUILD_DIR)/release/bin/$(MAXHS):	 	$(BUILD_DIR)/release/maxhs/core/Main.o $(foreach o,$(OBJS),$(BUILD_DIR)/release/$(o))
$(BUILD_DIR)/debug/bin/$(MAXHS):	 	$(BUILD_DIR)/debug/maxhs/core/Main.o $(BUILD_DIR)/debug/lib/$(MAXHS_SLIB)
$(BUILD_DIR)/profile/bin/$(MAXHS):	 	$(BUILD_DIR)/profile/maxhs/core/Main.o $(BUILD_DIR)/profile/lib/$(MAXHS_SLIB)

## Library dependencies
$(BUILD_DIR)/release/lib/$(MAXHS_SLIB):	$(foreach o,$(OBJS),$(BUILD_DIR)/release/$(o))
$(BUILD_DIR)/debug/lib/$(MAXHS_SLIB):		$(foreach o,$(OBJS),$(BUILD_DIR)/debug/$(o))
$(BUILD_DIR)/profile/lib/$(MAXHS_SLIB):	$(foreach o,$(OBJS),$(BUILD_DIR)/profile/$(o))

## Compile rules
$(BUILD_DIR)/release/%.o:	%.cc
	$(ECHO) Compiling: $@
	$(VERB) mkdir -p $(dir $@)
	$(VERB) $(CXX) $(MAXHS_CXXFLAGS) $(CXXFLAGS) -c -o $@ $< -MMD -MF $(BUILD_DIR)/release/$*.d

$(BUILD_DIR)/profile/%.o:	%.cc
	$(ECHO) Compiling: $@
	$(VERB) mkdir -p $(dir $@)
	$(VERB) $(CXX) $(MAXHS_CXXFLAGS) $(CXXFLAGS) -c -o $@ $< -MMD -MF $(BUILD_DIR)/profile/$*.d

$(BUILD_DIR)/debug/%.o:	%.cc
	$(ECHO) Compiling: $@
	$(VERB) mkdir -p $(dir $@)
	$(VERB) $(CXX) $(MAXHS_CXXFLAGS) $(CXXFLAGS) -c -o $@ $< -MMD -MF $(BUILD_DIR)/debug/$*.d

## Linking rule
$(BUILD_DIR)/release/bin/$(MAXHS) $(BUILD_DIR)/debug/bin/$(MAXHS) $(BUILD_DIR)/profile/bin/$(MAXHS):
	$(ECHO) Linking Binary: $@
	$(VERB) mkdir -p $(dir $@)
	$(VERB) $(CXX) $^ $(MAXHS_LDFLAGS) $(LDFLAGS) -o $@

## Static Library rule
%/lib/$(MAXHS_SLIB):
	$(ECHO) Linking Static Library: $@
	$(VERB) mkdir -p $(dir $@)
	$(VERB) $(AR) -rcs $@ $^
clean:
	rm -f $(foreach t, release debug profile, $(foreach o, $(ALLSRCS:.cc=.o), $(BUILD_DIR)/$t/$o)) \
          $(foreach t, release debug profile, $(foreach d, $(ALLSRCS:.cc=.d), $(BUILD_DIR)/$t/$d)) \
	  $(foreach t, release debug profile, $(BUILD_DIR)/$t/bin/$(MAXHS)) \
	  $(foreach t, release debug profile, $(BUILD_DIR)/$t/lib/$(MAXHS_SLIB))

## Include generated dependencies
-include $(foreach s, $(SRCS:.cc=.d), $(BUILD_DIR)/release/$s)
-include $(foreach s, $(SRCS:.cc=.d), $(BUILD_DIR)/debug/$s)
-include $(foreach s, $(SRCS:.cc=.d), $(BUILD_DIR)/profile/$s)
