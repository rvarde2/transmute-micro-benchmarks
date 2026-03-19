#include <iostream>
#include <vector>
#include <chrono>
#include <string>
#include <algorithm>

// Function to perform the workload
void scientific_workload(size_t total_elements, double* src, double* dst, const std::vector<size_t>& indices) {
    for (size_t i = 0; i < total_elements; ++i) {
        // Accessing via a shuffled index breaks the CPU's ability to predict the next address
        size_t idx = indices[i];
        
        // Simple computation to keep the CPU busy while waiting for DRAM
        dst[idx] = (src[idx] * 1.00001) + 0.5;
    }
}

int main(int argc, char* argv[]) {
    // 16384 is your script's default; 16384^2 * 8 bytes * 2 arrays = 4GB of data
    size_t N = (argc > 1) ? std::stoll(argv[1]) : 16384;
    std::string mode = (argc > 2) ? argv[2] : "baseline";
    size_t total_elements = N * N;

    std::cout << "Starting " << mode << " mode with N=" << N << "..." << std::endl;

    // Standard vectors are easier to manage and still use contiguous memory
    std::vector<double> A(total_elements, 1.23);
    std::vector<double> B(total_elements, 0.0);
    std::vector<size_t> indices(total_elements);

    // 1. Fill indices linearly (0, 1, 2, 3...)
    for (size_t i = 0; i < total_elements; ++i) {
        indices[i] = i;
    }

    // 2. Simple Shuffle (Fisher-Yates) to break the prefetcher
    // We use a fixed seed (42) so every run (baseline vs tax) is identical
    srand(42);
    for (size_t i = total_elements - 1; i > 0; --i) {
        size_t j = rand() % (i + 1);
        std::swap(indices[i], indices[j]);
    }

    // Measure only the workload
    auto start = std::chrono::high_resolution_clock::now();
    
    // .data() gives us the raw pointer needed for the function
    scientific_workload(total_elements, A.data(), B.data(), indices);
    
    auto end = std::chrono::high_resolution_clock::now();

    std::chrono::duration<double> elapsed = end - start;
    std::cout << "Completion Time: " << elapsed.count() << "s" << std::endl;

    return 0;
}
