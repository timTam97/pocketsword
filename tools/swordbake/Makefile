# swordbake — offline content converter (PocketSword SWORD-removal, Phase 2)
#
# Builds a throwaway macOS CLI that links the vendored SWORD engine and bakes
# the five bundled modules into Resources/PSContent.sqlite plus
# Resources/Versification-KJV.json.
#
# This is deliberately NOT an Xcode target: the project has zero shell-script
# build phases and a project-level GCC_PREFIX_HEADER that imports UIKit, so a
# macOS target would need overrides everywhere plus 148 hand-added source refs
# in a pbxproj that has bitten this repo before. The tool is deleted in Phase 5
# along with externals/sword.
#
# Usage:
#   make                       # build build/swordbake
#   make run                   # unpack the shipped zips to a scratch dir and convert
#   make verify                # build, convert twice, assert byte-identical output
#   make clean

REPO_ROOT   := $(abspath ../..)
SWORD_ROOT  := $(REPO_ROOT)/externals/sword
BUILD_DIR   := build
OBJ_DIR     := $(BUILD_DIR)/obj
BIN         := $(BUILD_DIR)/swordbake

# The SWORD translation units, taken verbatim from the app's own Sources build
# phase (extracted once from project.pbxproj — see sword_sources.txt). Keeping
# the list in a file rather than a wildcard means the tool compiles exactly the
# engine the app compiles, no more and no less.
SWORD_SRC_REL := $(shell cat sword_sources.txt)
SWORD_SRC     := $(addprefix $(REPO_ROOT)/,$(SWORD_SRC_REL))
SWORD_CPP     := $(filter %.cpp,$(SWORD_SRC))
SWORD_C       := $(filter %.c,$(SWORD_SRC))

# Object paths mirror the source tree under OBJ_DIR so the two ftplib/ftpparse
# C files can't collide with same-named C++ units.
SWORD_CPP_OBJ := $(patsubst %,$(OBJ_DIR)/%.o,$(SWORD_CPP_REL))
SWORD_CPP_OBJ := $(foreach s,$(SWORD_CPP),$(OBJ_DIR)/$(patsubst $(REPO_ROOT)/%,%,$(s)).o)
SWORD_C_OBJ   := $(foreach s,$(SWORD_C),$(OBJ_DIR)/$(patsubst $(REPO_ROOT)/%,%,$(s)).o)
MAIN_OBJ      := $(OBJ_DIR)/swordbake/main.mm.o

OBJS := $(SWORD_CPP_OBJ) $(SWORD_C_OBJ) $(MAIN_OBJ)

# Compile-time knobs. These mirror misc/PocketSword_Prefix.pch's SWORD section
# exactly: _ICU_, _APPLE_IOS_, USELUCENE and CURLAVAILABLE are all commented out
# there, so the iOS build already takes the portable, ICU-free, Lucene-free,
# CURL-free branch and so does this tool. We do NOT reuse that prefix header
# (it imports UIKit) nor Classes/globals.h (same).
SWORD_DEFS := -Dunix -D__unix__ -DEXCLUDEXZ
INCLUDES   := -I$(SWORD_ROOT)/include -I.

WARN     := -Wno-deprecated-declarations -Wno-deprecated -Wno-writable-strings \
            -Wno-unused-value -Wno-logical-op-parentheses -Wno-dangling-else
OPT      := -O2 -g0
CXXFLAGS := -std=c++11 $(OPT) $(SWORD_DEFS) $(INCLUDES) $(WARN)
CFLAGS   := -std=gnu11 $(OPT) $(SWORD_DEFS) $(INCLUDES) $(WARN)
OBJCXXFLAGS := -std=c++11 -fobjc-arc $(OPT) $(SWORD_DEFS) $(INCLUDES) $(WARN)
LDFLAGS  := -lz -lbz2 -lsqlite3 -framework Foundation

# Scratch layout for `make run` / `make verify`.
SCRATCH   := $(BUILD_DIR)/scratch
MODULES   := $(SCRATCH)/modules
OUT_DIR   := $(REPO_ROOT)/Resources
ZIPS      := KJV MHCC Robinson strongsrealgreek strongsrealhebrew locales.d

.PHONY: all run verify unpack clean

all: $(BIN)

$(BIN): $(OBJS)
	@mkdir -p $(dir $@)
	clang++ $(OPT) -o $@ $(OBJS) $(LDFLAGS)
	@echo "built $@"

$(OBJ_DIR)/%.cpp.o: $(REPO_ROOT)/%.cpp
	@mkdir -p $(dir $@)
	clang++ $(CXXFLAGS) -c -o $@ $<

$(OBJ_DIR)/%.c.o: $(REPO_ROOT)/%.c
	@mkdir -p $(dir $@)
	clang $(CFLAGS) -c -o $@ $<

$(MAIN_OBJ): main.mm
	@mkdir -p $(dir $@)
	clang++ $(OBJCXXFLAGS) -c -o $@ $<

# Unpack the shipped zips exactly as the app does on first launch: every module
# zip into the module root (mods.d/ + modules/ merge), locales.d.zip into a
# locales.d subdir. Drops KJV's dead 6.7 MB lucene index, which the app already
# sweeps at runtime (DefaultsLuceneSwept) and which Phase 5 removes from the zip.
unpack:
	@rm -rf $(MODULES)
	@mkdir -p $(MODULES)/locales.d
	@for z in $(ZIPS); do \
		if [ "$$z" = "locales.d" ]; then \
			unzip -oq $(OUT_DIR)/$$z.zip -d $(MODULES)/locales.d; \
		else \
			unzip -oq $(OUT_DIR)/$$z.zip -d $(MODULES); \
		fi; \
	done
	@rm -rf $(MODULES)/__MACOSX $(MODULES)/locales.d/__MACOSX
	@find $(MODULES) -name lucene -type d -prune -exec rm -rf {} +
	@echo "unpacked modules -> $(MODULES)"

run: $(BIN) unpack
	$(BIN) --modules $(MODULES) --locales $(MODULES)/locales.d --out $(OUT_DIR)

# Determinism gate: convert twice into separate dirs and compare checksums.
verify: $(BIN) unpack
	@rm -rf $(BUILD_DIR)/out1 $(BUILD_DIR)/out2
	@mkdir -p $(BUILD_DIR)/out1 $(BUILD_DIR)/out2
	$(BIN) --modules $(MODULES) --locales $(MODULES)/locales.d --out $(BUILD_DIR)/out1
	$(BIN) --modules $(MODULES) --locales $(MODULES)/locales.d --out $(BUILD_DIR)/out2
	@a=`shasum -a 256 $(BUILD_DIR)/out1/PSContent.sqlite | cut -d' ' -f1`; \
	 b=`shasum -a 256 $(BUILD_DIR)/out2/PSContent.sqlite | cut -d' ' -f1`; \
	 ja=`shasum -a 256 $(BUILD_DIR)/out1/Versification-KJV.json | cut -d' ' -f1`; \
	 jb=`shasum -a 256 $(BUILD_DIR)/out2/Versification-KJV.json | cut -d' ' -f1`; \
	 echo "run1 db  $$a"; echo "run2 db  $$b"; \
	 echo "run1 json $$ja"; echo "run2 json $$jb"; \
	 if [ "$$a" != "$$b" ] || [ "$$ja" != "$$jb" ]; then echo "FAIL: output is not deterministic"; exit 1; fi; \
	 echo "PASS: byte-identical across runs"

clean:
	rm -rf $(BUILD_DIR)
