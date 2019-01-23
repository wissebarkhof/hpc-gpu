extern "C" {
#include <stdio.h>
#include <stdlib.h>
#include <omp.h>

}

const int device0 = 0;
#define BLOCK_SIZE 16

void __global__ jacobi_gpu2(int N, double delta, int kMAX, double *f, double *u_new, double *u_old) {
    int j = blockIdx.x * blockDim.x + threadIdx.x;
    int i = blockIdx.y * blockDim.y + threadIdx.y;
    double scalar = 1.0/4;
    if (i <= N && j <= N && i > 0 && j > 0) {
        u_new[i*N + j] = scalar * (u_old[(i-1)*N + j] + u_old[(i+1)*N + j] + u_old[i*N + (j-1)] + u_old[i*N + (j+1)] +delta*f[i*N + j]);
    }
}

int main(int argc, char *argv[]) {

    // warm up:
    double *dummy_d;
    cudaSetDevice(device0);
    cudaMalloc((void**)&dummy_d, 0);

    int kMAX, N,i,j;

    if (argc == 3) {
        N = atoi(argv[1]);
        kMAX = atoi(argv[2]);
    }
    else {
        // use default N
        N = 200;
        kMAX = 5000;
    }
    double delta = (2.0 / N) * (2.0 / N);

    // allocate mem
    double *h_f, *h_u_new, *h_u_old, *d_f, *d_u_new, *d_u_old;

    int size_f = N * N * sizeof(double);
    int size_u_new = N * N * sizeof(double);
    int size_u_old = N * N * sizeof(double);

    //Allocate memory on device
    cudaSetDevice(device0);
    cudaMalloc((void**)&d_f, size_f);
    cudaMalloc((void**)&d_u_new, size_u_new);
    cudaMalloc((void**)&d_u_old, size_u_old);
    //Allocate memory on host
    cudaMallocHost((void**)&h_f, size_f);
    cudaMallocHost((void**)&h_u_new, size_u_new);
    cudaMallocHost((void**)&h_u_old, size_u_old);

    // initilize boarder
    for (i = 0; i <N; i++){
        for (j = 0; j < N; j++){
            if (i >= N * 0.5  &&  i <= N * 2.0/3.0  &&  j >= N * 1.0/6.0  &&  j <= N * 1.0/3.0)
                h_f[i*N + j] = 200.0;
            else
                h_f[i*N + j] = 0.0;

            if (i == (N - 1) || i == 0 || j == (N - 1)){
                h_u_new[i*N + j] = 20.0;
                h_u_old[i*N + j] = 20.0;
            }
            else{
                h_u_new[i*N + j] = 0.0;
                h_u_old[i*N + j] = 0.0;
            }
        }
    }

    //Copy memory CPU -> GPU
    double time_tmp = omp_get_wtime();
    cudaMemcpy(d_f, h_f, size_f, cudaMemcpyHostToDevice);
    cudaMemcpy(d_u_new, h_u_new, size_u_old, cudaMemcpyHostToDevice);
    cudaMemcpy(d_u_old, h_u_old, size_u_old, cudaMemcpyHostToDevice);
    double time_IO_1 = omp_get_wtime() - time_tmp;

    // do program
    int k = 0;
    dim3 dim_grid(((N+BLOCK_SIZE-1) / BLOCK_SIZE), ((N+BLOCK_SIZE-1) / BLOCK_SIZE));
    dim3 dim_block(BLOCK_SIZE, BLOCK_SIZE);
    double *temp, time_compute = omp_get_wtime();
    while (k < kMAX) {
        // Set u_old = u
        temp = d_u_new;
        d_u_new = d_u_old;
        d_u_old = temp;
        jacobi_gpu2<<<dim_grid,dim_block>>>(N, delta, kMAX, d_f, d_u_new, d_u_old);
        cudaDeviceSynchronize();
        k++;
    }/* end while */
    double tot_time_compute = omp_get_wtime() - time_compute;
    // end program

    //Copy memory GPU -> CPU
    time_tmp = omp_get_wtime();
    cudaMemcpy(h_u_new, d_u_new, size_u_new, cudaMemcpyDeviceToHost);
    double time_IO_2 = omp_get_wtime() - time_tmp;

    tot_time_compute += time_IO_1 + time_IO_2;

    // stats
    double GB = 1.0e-09;
    double flop = kMAX * (double)(N) * (double)(N) * 10.0;
    double gflops  = (flop / tot_time_compute) * GB;
    double memory  = size_f + size_u_new + size_u_old;
    double memoryGBs  = memory * GB * (1 / tot_time_compute);

    printf("%d\t", N);
    printf("%g\t", memory); // footprint
    printf("%g\t", gflops); // Gflops
    //printf("%g\t", memoryGBs); // bandwidth GB/s
    printf("%g\t", tot_time_compute); // total time
    //printf("%g\t", time_IO_1 + time_IO_2); // I/O time
    //printf("%g\t", tot_time_compute); // compute time
    printf("# GPU2\n");

    // free allocated mem
    cudaFree(d_f), cudaFree(d_u_new), cudaFree(d_u_old);
    cudaFreeHost(h_f), cudaFreeHost(h_u_new), cudaFreeHost(h_u_old);
    // end program
    return(0);
}