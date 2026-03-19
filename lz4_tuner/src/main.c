#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <lz4.h>
#include <hdr/hdr_histogram.h>
#include <hdr/hdr_histogram_log.h> 

char *workload="";
unsigned long num_samples = 0;    
int acceleration = 1;
void help(){
    printf("./build/tuner -w <workload_filename> -n <num_of_samples> -a <acceleration:1 to 65537>\n");
}

char* read_file_into_buffer(const char* filename, int* length) {
    FILE* fptr = fopen(filename, "rb"); // Open file in read binary mode
    if (fptr == NULL) {
        perror("Error opening file");
        return NULL;
    }

    // Go to the end of the file to determine the size
    if (fseek(fptr, 0L, SEEK_END) != 0) {
        perror("Error seeking in file");
        fclose(fptr);
        return NULL;
    }

    // Get the current file position (file size)
    int filesize = ftell(fptr);
    if (filesize == -1) {
        perror("Error getting file size");
        fclose(fptr);
        return NULL;
    }

    // Go back to the beginning of the file
    rewind(fptr);

    // Allocate memory for the buffer (+1 for null terminator for text files, optional for binary)
    char* buffer = (char*)malloc(sizeof(char) * (filesize + 1));
    if (buffer == NULL) {
        perror("Error allocating memory");
        fclose(fptr);
        return NULL;
    }

    // Read the entire file into the buffer
    size_t bytes_read = fread(buffer, sizeof(char), filesize, fptr);
    if (bytes_read != filesize) {
        perror("Error reading file content");
        free(buffer);
        fclose(fptr);
        return NULL;
    }

    // Null-terminate the buffer if you intend to use it as a C string
    buffer[filesize] = '\0';

    // Close the file
    fclose(fptr);

    // Set the length parameter if provided
    if (length != NULL) {
        *length = filesize;
    }

    return buffer;
}

static inline uint64_t rdtsc(void) {
    uint32_t cycles_high, cycles_low;
     __asm__ __volatile__("RDTSC" : "=a"(cycles_low), "=d"(cycles_high));
    return (((uint64_t)cycles_high << 32) | (uint64_t)cycles_low);
}

void benchmark(char *workload_buffer, int workload_length){
    //volatile should prevent loop unrolling giving correct result.
    volatile unsigned long samples_created = 0;
    volatile int compressed_size, decompressed_size;
    void* lz4_state = malloc(LZ4_sizeofState());
    char *compression_buffer = (char *)calloc(workload_length,sizeof(char));
    char *decompression_buffer = (char *)calloc(workload_length,sizeof(char));
    struct hdr_histogram *compress_hist, *decompress_hist;
    hdr_init(1, INT64_C(1000000000), 3, &compress_hist);
    hdr_init(1, INT64_C(1000000000), 3, &decompress_hist);
    while(samples_created<num_samples){
        uint64_t before_compression = rdtsc();
        compressed_size = LZ4_compress_fast_extState(lz4_state,
                workload_buffer,compression_buffer,
                workload_length,workload_length, acceleration);
        
        hdr_record_value(compress_hist,rdtsc()-before_compression);    
        uint64_t before_decompression = rdtsc();
        decompressed_size= LZ4_decompress_safe(compression_buffer,
                decompression_buffer,compressed_size, workload_length);
        hdr_record_value(decompress_hist,rdtsc()-before_decompression);
        
        if((decompressed_size!=-1) &&  (workload_length!=decompressed_size)){
            printf("Mismatch: workload_length:%d, decompressed_size:%d\n",
                    workload_length, decompressed_size);
        } 
        
        memset(compression_buffer, 0, workload_length);
        memset(decompression_buffer, 0, workload_length);
        samples_created++;
    }
    //printf("acceleration,compression_ratio,avg_compression_cycles,tail_compression_cycles,");
    //printf("avg_decompression_cycles,tail_decompression_cycles\n");
    
    printf("%s,a:%d,%.3f,%.3f,%lu,%.3f,%lu\n",workload,acceleration,((workload_length * 1.0)/compressed_size),
            hdr_mean(compress_hist),hdr_value_at_percentile(compress_hist,99),
            hdr_mean(decompress_hist),hdr_value_at_percentile(decompress_hist,99));
    free(lz4_state);
    free(compression_buffer);
    free(decompression_buffer);
}

int 
main(int argc, char* argv[])
{
    char *endptr;
    // Parse command line arguments
    char c;
    while ((c = getopt (argc, argv, "w:n:a:")) != -1) {
        switch (c) {
            case 'w':
                workload = optarg;
                break;
            case 'n':
                num_samples = strtoul(optarg, &endptr, 10);
                break;
            case 'a':
                acceleration = atoi(optarg);
                break;
        }
    }
    if(num_samples<1){
        printf("Number of samples cannot be %lu\n",num_samples);
        help();
        return -1;
    } 
    if (access(workload, F_OK) != 0) {
        printf("Could not find provided workload file %s\n",workload);
        help();
        return -1;
    }

    int workload_length= 0;
    char* workload_buffer = read_file_into_buffer(workload, &workload_length);
    if (workload_buffer == NULL) {
        printf("Could not read workload from file");
        return -1;
    }
    
    benchmark(workload_buffer,workload_length);
    
    free(workload_buffer);     
    return 0;
}
