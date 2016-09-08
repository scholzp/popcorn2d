#include "ppm.hpp"

#if defined(__PGI) or defined(__PGIC__)
#define USE_OPENACC 1
#include <openacc.h>
#endif

#include <iostream>
#include <chrono>
#include <cinttypes>

using namespace std;

const uint32_t WIDTH  = 1024;
const uint32_t HEIGHT = 1024;
const uint32_t IMG_SIZE = WIDTH * HEIGHT;

template<typename T>
using DataT = T[3*IMG_SIZE]; // RGB

/**
 * Set color values for pixel (i,j).
 * Underlying format is flattened structure of arrays
 *  red[Pixel 1..n], green[Pixel 1..n] and blue[Pixel 1..n].
 * This allows coalesced memory access on GPUs.
 */
template<typename T>
void setPixel(DataT<T>& image, uint32_t i, uint32_t j, T r, T g, T b) {
  image[ j + i*WIDTH ]              = r;
  image[ j + i*WIDTH + IMG_SIZE ]   = g;
  image[ j + i*WIDTH + 2*IMG_SIZE ] = b;
}

/**
 * Compute the pixels. Color values are from [0,1].
 * @todo implement popcorn 2d fractal
 * @todo find OpenACC directives to accelerate the computation
 */
template<typename T>
void computeImage(DataT<T>& image) {
  for( uint32_t i=0; i<HEIGHT; ++i ) {
    for( uint32_t j=0; j<WIDTH; ++j ) {
      T red   = 0.5;
      T green = j*1.0/WIDTH;
      T blue  = 0.5;
      setPixel(image, i, j, red, green, blue);
    }
  }
}

int main(void) {

#ifdef USE_OPENACC
  // init device to separate init time
  acc_init(acc_device_nvidia);
  acc_set_device_num(0, acc_device_nvidia);
#endif

  DataT<float> image;
  auto start_time = chrono::steady_clock::now();

  computeImage(image);

  auto end_time = chrono::steady_clock::now();
  cout << chrono::duration_cast<chrono::milliseconds>(end_time - start_time).count() << " ms";
  cout << endl;

  ImageWriter::PPM::writeRGB(image, WIDTH, HEIGHT, "image.ppm");

  return 0;
}
