TARGET = tuner

# --- Configuration ---
# Point this to your local HdrHistogram installation root
#HDR_HOME = /data/HdrHistogram_c/local_install
HDR_HOME = /data/rohan/SciStream/HdrHistogram_c/local_install

# Compiler and Linker
CC = gcc
LD = gcc

# Directories
SRC_DIR = src
BUILD_DIR = build

# --- Flags & Libraries ---
# 1. Includes: Where to find .h files (used during compilation)
INCLUDES = -I$(HDR_HOME)/include

# 2. Compiler Flags: Optimization and warnings
CFLAGS = -O3 -DLZ4_MEMORY_USAGE=12 -Wall

# 3. Linker Flags: Where to find .so/.a files (used during linking)
#    We use -Wl,-rpath to bake the library path into the binary
LDFLAGS = -L$(HDR_HOME)/lib -Wl,-rpath,$(HDR_HOME)/lib

# 4. Libraries: The actual libraries to link against
LDLIBS = -lhdr_histogram -llz4 -lm

# --- File Management ---
SOURCES = $(wildcard $(SRC_DIR)/*.c)
OBJECTS = $(SOURCES:$(SRC_DIR)/%.c=$(BUILD_DIR)/%.o)
EXEC = $(BUILD_DIR)/$(TARGET)

# --- Targets ---

# Default target
all: $(EXEC)

# Link object files into the final binary
# Order matters: LDFLAGS comes before objects, LDLIBS comes last
$(EXEC): $(OBJECTS)
	@mkdir -p $(dir $@)
	$(LD) $(LDFLAGS) $(OBJECTS) -o $@ $(LDLIBS)

# Compile source files into object files
# Added $(INCLUDES) here so the compiler finds hdr_histogram.h
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

# Clean up
clean:
	rm -rf $(BUILD_DIR) *.app *.data

.PHONY: all clean
