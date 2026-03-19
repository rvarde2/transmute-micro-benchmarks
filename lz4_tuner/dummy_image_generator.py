import sys
import random

def generate_chunked_payload(filename, percent_same, chunk_size=100):
    """
    Generates a 9000-byte file by shuffling 'flat' and 'random' chunks.
    """
    TOTAL_SIZE = 9000
    
    # Validation: Ensure strict 9000 byte limit is divisible by chunk size
    if TOTAL_SIZE % chunk_size != 0:
        print(f"Error: Chunk size {chunk_size} does not divide evenly into {TOTAL_SIZE}.")
        return

    # 1. Calculate Chunk Distribution
    total_chunks = TOTAL_SIZE // chunk_size
    
    # Calculate how many chunks should be "same" (flat) vs "random"
    # We constrain this to integer counts of chunks
    count_same_chunks = int(total_chunks * (percent_same / 100.0))
    count_random_chunks = total_chunks - count_same_chunks
    
    actual_percent = (count_same_chunks / total_chunks) * 100
    
    print(f"Generating '{filename}' ({TOTAL_SIZE} bytes)...")
    print(f"Chunk Size:      {chunk_size} bytes")
    print(f"Total Chunks:    {total_chunks}")
    print(f"Flat Chunks:     {count_same_chunks}")
    print(f"Random Chunks:   {count_random_chunks}")
    print(f"Actual 'Same':   {actual_percent:.2f}%")

    # 2. Prepare the Data Sources
    # We pick ONE repeating byte to represent "Same" data globally 
    # (simulating a background color or silence)
    repeating_byte_val = random.randint(0, 255)
    flat_chunk_data = bytes([repeating_byte_val]) * chunk_size

    chunk_list = []

    # Add the "Flat" chunks
    for _ in range(count_same_chunks):
        chunk_list.append(flat_chunk_data)

    # Add the "Random" chunks
    # We generate fresh random noise for every random chunk
    for _ in range(count_random_chunks):
        random_chunk_data = random.randbytes(chunk_size)
        chunk_list.append(random_chunk_data)

    # 3. Shuffle the Blocks
    # This interleaves the data, creating the "alternating" stress test
    random.shuffle(chunk_list)

    # 4. Combine and Write
    final_data = b"".join(chunk_list)

    try:
        with open(filename, 'wb') as f:
            f.write(final_data)
        print("Success.")
    except IOError as e:
        print(f"Error writing file: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python dummy_image_generator.py <output_file> <percent_same> [chunk_size]")
        print("In order to avoid commiting test files accidently, use .app or .out extension")
        sys.exit(1)

    output_file = sys.argv[1]
    
    try:
        percent = float(sys.argv[2])
        # Default chunk size is 100, but can be overridden
        c_size = int(sys.argv[3]) if len(sys.argv) > 3 else 100
    except ValueError:
        print("Error: Numeric values required.")
        sys.exit(1)

    generate_chunked_payload(output_file, percent, c_size)
