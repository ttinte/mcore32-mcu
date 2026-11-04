# ===== DEFAULT TARGET =====
.DEFAULT_GOAL := fw
.DELETE_ON_ERROR:

# ===== RTL SIMULATION CONFIG =====
TOP ?= rv32_core

FLIST_DIR = sim/filelists
FILELIST  = $(FLIST_DIR)/$(TOP).f
WLF_FILE  = $(TOP).wlf

# ===== FIRMWARE TOOLCHAIN CONFIG =====
CROSS_COMPILE ?= riscv64-unknown-elf-
PYTHON        ?= python3

FW_CC      := $(CROSS_COMPILE)gcc
FW_OBJCOPY := $(CROSS_COMPILE)objcopy
FW_OBJDUMP := $(CROSS_COMPILE)objdump
FW_SIZE    := $(CROSS_COMPILE)size

# ===== FIRMWARE APPLICATION CONFIG =====
APP ?= core_tests

FW_DIR            := firmware
FW_SOURCE_ROOT    := $(FW_DIR)/src
FW_PLATFORM_DIR   := $(FW_DIR)/platform
FW_DRIVER_DIR     := $(FW_DIR)/drivers
FW_APP_DIR        := $(FW_SOURCE_ROOT)/$(APP)
FW_BUILD_ROOT     := $(FW_DIR)/build
FW_BUILD_DIR      := $(FW_BUILD_ROOT)/$(APP)
FW_ELF            := $(FW_BUILD_DIR)/firmware.elf
FW_BIN            := $(FW_BUILD_DIR)/firmware.bin
FW_MAP            := $(FW_BUILD_DIR)/firmware.map
FW_DUMP           := $(FW_BUILD_DIR)/firmware.dump
FW_APP_MEM        := $(FW_BUILD_DIR)/firmware.mem
FW_APP_HEX        := $(FW_BUILD_DIR)/firmware.hex
FW_MEM            := $(FW_DIR)/firmware.mem
FW_HEX            := $(FW_DIR)/firmware.hex
FW_APP_SOURCES    := $(wildcard $(FW_APP_DIR)/*.c)
FW_APP_ASM_SOURCES := $(wildcard $(FW_APP_DIR)/*.S)
FW_PLATFORM_C_SOURCES := $(wildcard $(FW_PLATFORM_DIR)/*.c)
FW_PLATFORM_ASM_SOURCES := $(wildcard $(FW_PLATFORM_DIR)/*.S)
FW_DRIVER_SOURCES := $(wildcard $(FW_DRIVER_DIR)/*/*.c)
FW_APP_OBJECTS    := $(patsubst $(FW_APP_DIR)/%.c,$(FW_BUILD_DIR)/app/%.o,$(FW_APP_SOURCES)) \
                     $(patsubst $(FW_APP_DIR)/%.S,$(FW_BUILD_DIR)/app/%.o,$(FW_APP_ASM_SOURCES))
FW_PLATFORM_OBJECTS := $(patsubst $(FW_PLATFORM_DIR)/%.c,$(FW_BUILD_DIR)/platform/%.o,$(FW_PLATFORM_C_SOURCES)) \
                       $(patsubst $(FW_PLATFORM_DIR)/%.S,$(FW_BUILD_DIR)/platform/%.o,$(FW_PLATFORM_ASM_SOURCES))
FW_DRIVER_OBJECTS := $(patsubst $(FW_DRIVER_DIR)/%.c,$(FW_BUILD_DIR)/drivers/%.o,$(FW_DRIVER_SOURCES))
FW_OBJECTS        := $(FW_PLATFORM_OBJECTS) $(FW_DRIVER_OBJECTS) $(FW_APP_OBJECTS)
FW_DEPFILES       := $(FW_OBJECTS:.o=.d)
FW_APPS           := $(notdir $(patsubst %/,%,$(wildcard $(FW_SOURCE_ROOT)/*/)))

FW_ARCH_FLAGS := -march=rv32i_zicsr -mabi=ilp32
# Vitis multilib selection does not map rv32i_zicsr to rv32i/ilp32.
# Integer software helpers are compatible; select that archive explicitly.
FW_LIBGCC = $(shell $(FW_CC) -march=rv32i -mabi=ilp32 -print-libgcc-file-name)

FW_CFLAGS     := $(FW_ARCH_FLAGS) -Os -g -Wall -Wextra \
                 -ffreestanding -fno-builtin -fno-stack-protector \
                 -ffunction-sections -fdata-sections -msmall-data-limit=0 \
                 -MMD -MP -I$(FW_DIR)/include -I$(FW_PLATFORM_DIR) -I$(FW_DRIVER_DIR)
FW_ASFLAGS    := $(FW_ARCH_FLAGS) -g -MMD -MP -I$(FW_PLATFORM_DIR)
FW_LDFLAGS    := $(FW_ARCH_FLAGS) -nostdlib -nostartfiles \
                 -Wl,-T,$(FW_PLATFORM_DIR)/linker.ld -Wl,--gc-sections \
                 -Wl,--build-id=none -Wl,-Map,$(FW_MAP)

# ===== RTL SIMULATION TARGETS =====
rtl-tools:
	@for tool in vlib vlog vsim; do \
	    command -v "$$tool" || \
	        { echo "Questa tool not found: $$tool"; \
	          echo "Add the Questa bin directory to PATH."; \
	          exit 1; }; \
	done

rtl-check:
	@test -f $(FILELIST) || \
	    { echo "Missing RTL filelist: $(FILELIST)"; exit 1; }

rtl-lib: rtl-tools
	@if [ ! -d work ]; then vlib work; fi

rtl-compile: rtl-check rtl-lib
	@echo "[Compile RTL & Testbench]"
	vlog -sv -f $(FILELIST)

rtl-wave: rtl-compile
	@echo "[Run GUI Live: $(TOP)]"
	vsim -voptargs=+acc $(TOP) -do "do sim/wave.do $(TOP) sim"

rtl-run: rtl-compile
	@echo "[Run CLI & Dump WLF: $(TOP)]"
	vsim -c -voptargs=+acc $(TOP) -wlf $(WLF_FILE) -do "log -r /*; run -all; quit -f"

rtl-view: rtl-tools
	@echo "[Open Waveform from WLF: $(WLF_FILE)]"
	vsim -gui -l /dev/null -view $(WLF_FILE) -do "do sim/wave.do $(TOP) $(TOP)"

rtl-syntax: rtl-check rtl-lib
	@echo "[Syntax check using $(FILELIST)]"
	vlog -sv -lint -f $(FILELIST)

rtl-clean:
	rm -rf work transcript vsim.wlf *.wlf uvm_test_*.log *.vstf

# ===== FIRMWARE BUILD TARGETS =====
fw-tools:
	@for tool in "$(FW_CC)" "$(FW_OBJCOPY)" "$(FW_OBJDUMP)" "$(FW_SIZE)"; do \
	    command -v "$$tool" || \
	        { echo "RISC-V tool not found: $$tool"; \
	          echo "Add the RISC-V toolchain bin directory to PATH."; \
	          exit 1; }; \
	done

$(FW_BUILD_DIR):
	mkdir -p $@

$(FW_OBJECTS): Makefile

$(FW_BUILD_DIR)/platform/%.o: $(FW_PLATFORM_DIR)/%.c
	mkdir -p $(dir $@)
	$(FW_CC) $(FW_CFLAGS) -c $< -o $@

$(FW_BUILD_DIR)/platform/%.o: $(FW_PLATFORM_DIR)/%.S
	mkdir -p $(dir $@)
	$(FW_CC) $(FW_ASFLAGS) -c $< -o $@

$(FW_BUILD_DIR)/app/%.o: $(FW_APP_DIR)/%.c
	mkdir -p $(dir $@)
	$(FW_CC) $(FW_CFLAGS) -c $< -o $@

$(FW_BUILD_DIR)/app/%.o: $(FW_APP_DIR)/%.S
	mkdir -p $(dir $@)
	$(FW_CC) $(FW_ASFLAGS) -c $< -o $@

$(FW_BUILD_DIR)/drivers/%.o: $(FW_DRIVER_DIR)/%.c
	mkdir -p $(dir $@)
	$(FW_CC) $(FW_CFLAGS) -c $< -o $@

$(FW_ELF): $(FW_OBJECTS) $(FW_PLATFORM_DIR)/linker.ld
	@test -n "$(FW_APP_SOURCES)" || \
	    { echo "Unknown firmware app '$(APP)'"; echo "Available apps: $(FW_APPS)"; exit 1; }
	$(FW_CC) $(FW_LDFLAGS) $(FW_OBJECTS) "$(FW_LIBGCC)" -o $@
	$(FW_SIZE) $@

$(FW_BIN): $(FW_ELF)
	$(FW_OBJCOPY) -O binary $< $@

$(FW_APP_MEM): $(FW_BIN) $(FW_DIR)/bin2hex.py
	$(PYTHON) $(FW_DIR)/bin2hex.py $< $@

$(FW_APP_HEX): $(FW_ELF)
	$(FW_OBJCOPY) -O ihex $< $@

$(FW_DUMP): $(FW_ELF)
	$(FW_OBJDUMP) -d -S $< > $@

fw: fw-tools $(FW_APP_MEM) $(FW_APP_HEX) $(FW_DUMP)
	cp $(FW_APP_MEM) $(FW_MEM)
	cp $(FW_APP_HEX) $(FW_HEX)
	@echo "Selected firmware app: $(APP)"
	@echo "Vivado image: $(FW_MEM)"

fw-rebuild:
	rm -rf $(FW_BUILD_DIR)
	$(MAKE) fw APP=$(APP)

fw-clean:
	rm -rf $(FW_BUILD_ROOT) $(FW_MEM) $(FW_HEX)

fw-info:
	@echo "CROSS_COMPILE=$(CROSS_COMPILE)"
	@echo "CC=$(FW_CC)"
	@echo "OBJCOPY=$(FW_OBJCOPY)"
	@echo "APP=$(APP)"
	@echo "APP_SOURCES=$(FW_APP_SOURCES)"
	@echo "DRIVER_SOURCES=$(FW_DRIVER_SOURCES)"

fw-list:
	@echo "Available firmware apps: $(FW_APPS)"

# ===== HELP =====
help:
	@echo "RTL simulation:"
	@echo "  make rtl-tools          Check Questa tools in PATH"
	@echo "  make rtl-wave TOP=...   Compile and open the simulator"
	@echo "  make rtl-run TOP=...    Run simulation in CLI mode"
	@echo "  make rtl-view TOP=...   Open an existing waveform"
	@echo "  make rtl-syntax TOP=... Run RTL syntax checks"
	@echo "  make rtl-clean          Remove simulation outputs"
	@echo "Firmware:"
	@echo "  make fw-tools           Check RISC-V GNU Compiler Toolchain"
	@echo "  make fw APP=...         Build a selected application"
	@echo "  make fw-rebuild APP=... Rebuild only the selected application"
	@echo "  make fw-clean           Remove all firmware outputs"
	@echo "  make fw-info APP=...    Show firmware configuration"
	@echo "  make fw-list            List available applications"

-include $(FW_DEPFILES)

.PHONY: rtl-tools rtl-check rtl-lib rtl-compile rtl-wave rtl-run rtl-view rtl-syntax \
        rtl-clean fw fw-tools fw-rebuild fw-clean fw-info fw-list help
