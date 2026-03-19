import struct
import os
import time

# Opening the interface to the PM QoS (Power Management Quality of Service)
# Writing a 0 tells the kernel "I can tolerate zero latency"
target_value = 0
device = "/dev/cpu_dma_latency"

try:
    fd = os.open(device, os.O_WRONLY)
    os.write(fd, struct.pack('i', target_value))
    print(f"C-states disabled. Holding CPU in C0. Press Ctrl+C to reverse.")
    while True:
        time.sleep(1)
except KeyboardInterrupt:
    print("\nReleasing latency lock. CPU power saving restored.")
