# popcorn2d

This is going to be a C++ program, that computes the fancy Popcorn 2D fractal by Clifford Pickover.

__INSTALL__
```
mkdir release
cd release
cmake ..
make
./popcorn2d
```
```
mkdir debug
cd debug
cmake -DCMAKE_BUILD_TYPE=Debug ..
make
./popcorn2d
```
# Measurements on K80 (without atomics)

## PGI OpenACC Implementation 256x256 (talpha=0.0)

- computeImage kernel: `1.2 ms`
  - 128 Threads, 256 Blocks
- colorImage kernel: `2.4 ms`
  - memory resides on device
  - uses shared memory, but seems to be inefficient compared to simple CUDA kernel below

```
nvprof --print-gpu-trace ./popcorn2d_kepler test 0 0 1 256 256 1
[...]
   Start  Duration  Grid Size      Block Size     Regs*    SSMem*    DSMem*      Size  Throughput           Device   Context    Stream  Name
[...warmup...]
461.73ms  72.703us          -               -         -         -         -  768.00KB  10.074GB/s    Tesla K80 (0)         1        13  [CUDA memcpy HtoD]
461.83ms  1.2267ms  (256 1 1)       (128 1 1)        45        0B        0B         -           -    Tesla K80 (0)         1        13  void computeImage<float>(float*, float, unsigned int, unsigned int)_105_gpu [40]
463.07ms  2.3851ms  (256 1 1)       (128 1 1)        43        0B       12B         -           -    Tesla K80 (0)         1        13  void colorImage<float>(float*, unsigned int, unsigned int, unsigned int)_55_gpu [42]
465.48ms  72.032us          -               -         -         -         -  768.00KB  10.168GB/s    Tesla K80 (0)         1        13  [CUDA memcpy DtoH]
```

## CUDA Implementation 256x256 (talpha=0.0)

- 1D grid-striding for computeImage kernel: `1.05 ms`
  - 128 Threads, 32*13 Blocks
- 1D grid-striding for colorImage kernel: `0.039 ms`

```
$ nvprof --print-gpu-trace popcorn2d_cuda testc 0 0 1 256 256 1
[...]
   Start  Duration  Grid Size      Block Size     Regs*    SSMem*    DSMem*      Size  Throughput           Device   Context    Stream  Name
[...warmup...]
444.67ms  11.872us          -               -         -         -         -  768.00KB  61.693GB/s    Tesla K80 (0)         1         7  [CUDA memset]
444.69ms  1.0457ms  (416 1 1)       (128 1 1)        45        0B        0B         -           -    Tesla K80 (0)         1         7  void d_computeImage_1D<float>(float*, Parameters<float>) [124]
445.76ms  39.295us  (416 1 1)       (128 1 1)        42        0B        0B         -           -    Tesla K80 (0)         1         7  void d_colorImage<float>(float*, Parameters<float>) [130]
```

- 2D grid-striding for computeImage kernel: `2.9 ms`
  - 16x16 Threads, 32*13 Blocks
- 1D grid-striding for colorImage kernel: `0.039 ms`

```
$ nvprof --print-gpu-trace popcorn2d_cuda testc 0 0 1 256 256 1
[...]
   Start  Duration  Grid Size      Block Size     Regs*    SSMem*    DSMem*      Size  Throughput           Device   Context    Stream  Name
[...warmup...]
428.16ms  11.904us          -               -         -         -         -  768.00KB  61.527GB/s    Tesla K80 (0)         1         7  [CUDA memset]
428.17ms  2.9001ms  (416 1 1)       (16 16 1)        50        0B        0B         -           -    Tesla K80 (0)         1         7  void d_computeImage<float>(float*, Parameters<float>) [124]
431.09ms  39.168us  (416 1 1)       (128 1 1)        42        0B        0B         -           -    Tesla K80 (0)         1         7  void d_colorImage<float>(float*, Parameters<float>) [130]
```

## PGI OpenACC Implementation 1024x1024 (talpha=0.1)

- computeImage kernel: `20.3 ms`

```
$ nvprof --print-gpu-trace ./popcorn2d_kepler test 0.1 0 1 1024 1024 1
[...]
   Start  Duration            Grid Size      Block Size     Regs*    SSMem*    DSMem*      Size  Throughput           Device   Context    Stream  Name
[...warmup...]
489.29ms  1.0841ms                    -               -         -         -         -  12.000MB  10.810GB/s    Tesla K80 (0)         1        13  [CUDA memcpy HtoD]
490.40ms  20.323ms           (1024 1 1)       (128 1 1)        45        0B        0B         -           -    Tesla K80 (0)         1        13  void computeImage<float>(float*, float, unsigned int, unsigned int)_105_gpu [42]
510.75ms  25.289ms           (1024 1 1)       (128 1 1)        43        0B       12B         -           -    Tesla K80 (0)         1        13  void colorImage<float>(float*, unsigned int, unsigned int, unsigned int)_55_gpu [44]
536.06ms  1.0977ms                    -               -         -         -         -  12.000MB  10.676GB/s    Tesla K80 (0)         1        13  [CUDA memcpy DtoH]
```
## CUDA Implementation 1024x1024 (talpha=0.1)

- 1D grid-striding computeImage kernel: `16.3 ms`

```
$ nvprof --print-gpu-trace ../release_cuda/popcorn2d_cuda testc 0.1 0 1 1024 1024 1
[...]
   Start  Duration            Grid Size      Block Size     Regs*    SSMem*    DSMem*      Size  Throughput           Device   Context    Stream  Name
[...warmup...]
438.40ms  68.671us                    -               -         -         -         -  12.000MB  170.65GB/s    Tesla K80 (0)         1         7  [CUDA memset]
438.47ms  16.297ms            (416 1 1)       (128 1 1)        45        0B        0B         -           -    Tesla K80 (0)         1         7  void d_computeImage_1D<float>(float*, Parameters<float>) [124]
454.79ms  602.75us            (416 1 1)       (128 1 1)        42        0B        0B         -           -    Tesla K80 (0)         1         7  void d_colorImage<float>(float*, Parameters<float>) [130]
```
