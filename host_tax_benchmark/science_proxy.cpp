#include <vector>
#include <chrono>
#include <iostream>
#include <numeric>
#include <string>
#include <algorithm>

// 8192 bytes = 1024 doubles. High cache-conflict potential.
const size_t PACKET_SIZE_BYTES = 8192;
const size_t ELEMS_PER_PACKET = PACKET_SIZE_BYTES / sizeof(double);

// Force 64-byte alignment to ensure "clean" baseline cache behavior
void scientific_workload(size_t N, double* src, double* dst) {
    size_t total_elements = N * N;
    for (size_t p = 0; p < total_elements; p += ELEMS_PER_PACKET) {
        size_t end = std::min(p + ELEMS_PER_PACKET, total_elements);
        for (size_t i = p; i < end; ++i) {
            // Transpose-style access to stress the memory controller
            size_t target_idx = (i % N) * N + (i / N);
            if (target_idx < total_elements) {
                dst[target_idx] = src[i] * 1.00001 + 0.5;
            }
        }
    }
}

int main(int argc, char* argv[]) {
    // Usage: ./science_proxy [N] [mode]
    size_t N = (argc > 1) ? std::stoul(argv[1]) : 8192;
    std::string mode = (argc > 2) ? argv[2] : "baseline";

    // Align memory to cache line boundaries (64 bytes)
    double* A;
    double* B;
    posix_memalign((void**)&A, 64, N * N * sizeof(double));
    posix_memalign((void**)&B, 64, N * N * sizeof(double));
    
    std::fill(A, A + (N * N), 1.23);

    std::cout << "Mode: " << mode << " | Size: " << N << " (" 
              << (N * N * sizeof(double) * 2) / (1024*1024) << " MB)" << std::endl;

    auto start = std::chrono::high_resolution_clock::now();
    scientific_workload(N, A, B);
    auto end = std::chrono::high_resolution_clock::now();

    std::cout << "Completion Time: " << std::chrono::duration<double>(end - start).count() << "s" << std::endl;

    free(A);
    free(B);
    return 0;
}
