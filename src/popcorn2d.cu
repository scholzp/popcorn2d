
#include "cuda_globals.hpp"

#include "ppm.hpp"
#include "CsvWriter.h"

#include <sstream>
#include <iostream>
#include <chrono>
#include <time.h>
#include <cinttypes>
#include <math.h>

#define VERBOSE 0

/*test setup
 * Total Number of performed tests: numberofTest*talphaCount*numberOfRescaling
 * Number of tests performed with set talpha: numberOfTests
 * Number of tests performed with set resolution: numberOfTest*talphaCount
 */

#define numberOfRescalings 0 //sets number of resolution rescalings
#define EnableSafedialog 0 /*controlls if safedialog is displayed or skipped
                             if skipped, picture wont be safed to file*/

static constexpr bool UseAtomics=false;
static constexpr bool RenderTrace=false;

template<typename T>
struct Parameters
{
  unsigned width = 256;
  unsigned height = 256;
  unsigned n;

  const T y1 = 5.0, y0 = -5.0, x0 = 5.0, x1 = -5.0; //sets zoom
  const T t0 = 31.1;
  const T t1 = -43.4;
  const T t2 = -43.3;
  const T t3 = 22.2;

  T talpha = 0.01;
};


//image settings
const uint32_t ITERATION = 64;
const uint32_t RES_EXPANSION = 128; //expands image resolution for each test
const uint32_t WIDTH_START  = 256;
const uint32_t HEIGHT_START = 256;

const double PI = 3.141592653589793;
static cudaEvent_t custart, cuend;


using namespace std;

// from world-space to image-space
template<typename T>
__device__
unsigned unmap( T v, const T v0, const T v1, const T len)
{
  return static_cast<unsigned>( (v-v0)/(v1-v0)*len );
}

// from image-space to world-space
template<typename T>
__device__
T map( unsigned v, const T v0, const T v1, const T len)
{
  return static_cast<T>(v)/len*(v1-v0)+v0;
}


/// HSL [0:1] to RGB {0..255}, from http://stackoverflow.com/questions/4728581/hsl-image-adjustements-on-gpu
template<typename T>
__device__
void hsl2rgb( T* _data, unsigned n, float hue, float sat, float lum )
{
  const float onethird = 1.0 / 3.0;
  const float twothird = 2.0 / 3.0;
  const float rcpsixth = 6.0;

  float xtr = rcpsixth * (hue - twothird);
  float xtg = 0.0;
  float xtb = rcpsixth * (1.0 - hue);

  if (hue < twothird) {
    xtr = 0.0;
    xtg = rcpsixth * (twothird - hue);
    xtb = rcpsixth * (hue      - onethird);
  }

  if (hue < onethird) {
    xtr = rcpsixth * (onethird - hue);
    xtg = rcpsixth * hue;
    xtb = 0.0;
  }

  xtr = __saturatef(xtr);
  xtg = __saturatef(xtg);
  xtb = __saturatef(xtb);

  float sat2   =  2.0 * sat;
  float satinv =  1.0 - sat;
  float luminv =  1.0 - lum;
  float lum2m1 = (2.0 * lum) - 1.0;
  float ctr    = (sat2 * xtr) + satinv;
  float ctg    = (sat2 * xtg) + satinv;
  float ctb    = (sat2 * xtb) + satinv;

  if (lum >= 0.5) {
    _data[0] = ((luminv * ctr) + lum2m1);
    _data[n] = ((luminv * ctg) + lum2m1);
    _data[2*n] = ((luminv * ctb) + lum2m1);
  }else {
    _data[0] = (lum * ctr);
    _data[n] = (lum * ctg);
    _data[2*n] = (lum * ctb);
  }
}


template<typename T>
__global__
void d_colorImage(T* _data, const Parameters<T> _params)
{
  unsigned j;
  T* red   = _data;
  T* green = _data+_params.n;
  T* blue  = _data+2*_params.n;
  for (j = blockIdx.x * blockDim.x + threadIdx.x;
       j < _params.n;
       j += blockDim.x * gridDim.x)
  {
    if(RenderTrace) {
      // red[j]   = 1.0-red[j];
      // green[j] = 1.0-green[j];
      // blue[j]  = 1.0-blue[j];
    }
    else {
      T colors[3];
      T density = sqrt(_data[j]);
      colors[0] = pow(density,0.4);
      colors[1] = pow(density,1.0);
      colors[2] = pow(density,1.4);
      // check if color values in range of [0,1], else correct
      for(int count = 0; count <  3; ++count){
        if (colors[count] > 1 ){
          colors[count] = 1;
        }else if(colors[count] < 0){
          colors[count] = 0;
        }
      }

      red[j]   = 1.0-0.5*colors[0];
      green[j] = 1.0-0.2*colors[1];
      blue[j]  = 1.0-0.4*colors[2];
      /*unsigned char d = 255*data.buffer[j];
        ptr[j].x = d;
        ptr[j].y = d;
        ptr[j].z = d;*/
    }
  }
}

template<typename T>
__global__
void d_computeImage(T* _data, const Parameters<T> _params)
{
  unsigned i,j;

  for (i = blockIdx.y * blockDim.y + threadIdx.y;
       i < _params.height;
       i += blockDim.y * gridDim.y)
  {
    for (j = blockIdx.x * blockDim.x + threadIdx.x;
         j < _params.width;
         j += blockDim.x * gridDim.x)
    {

      T xk = map(j, _params.x0, _params.x1, (T)_params.width);
      T yk = map(i, _params.y0, _params.y1, (T)_params.height);
      // T xk = (T) j / _params.width * (_params.x1 - _params.x0) + _params.x0;
      // T yk = (T) i / _params.height * (_params.y1 - _params.y0) + _params.y0;


      for(unsigned t=0; t<ITERATION; ++t) {
        xk += _params.talpha * (cos( _params.t0 * _params.talpha + yk + cos(_params.t1 * _params.talpha + PI * xk)));
        yk += _params.talpha * (cos( _params.t2 * _params.talpha + xk + cos(_params.t3 * _params.talpha + PI * yk)));

        int px = unmap(xk, _params.x0, _params.x1, (T)_params.width);
        int py = unmap(yk, _params.y0, _params.y1, (T)_params.height);
        if (px>=0 && py>=0 && px<_params.width && py<_params.height) {
          unsigned offset = px+py*_params.width;
          T v = 0.001;
          if( RenderTrace ) {
            if( (i&31)==0 && (j&31)==0 ) {
              hsl2rgb(_data+offset, _params.n, 0.5*(float(t)/63)+0.25, 1.0, 0.6);
            }

          }
          else {

            if(UseAtomics) {
              atomicAdd(_data+offset, v); // just density
            } else {
              _data[offset] += v;
            }
          }
        }
      } // for
    }
  }
}


template<typename T>
__global__
void d_computeImage_1D(T* _data, const Parameters<T> _params)
{
  unsigned i;
  for (i = blockIdx.x * blockDim.x + threadIdx.x;
       i < _params.n;
       i += blockDim.x * gridDim.x)
  {
    T xk = map(i%_params.width, _params.x0, _params.x1, (T)_params.width);
    T yk = map(i/_params.height, _params.y0, _params.y1, (T)_params.height);
    // T xk = (T) j / _params.width * (_params.x1 - _params.x0) + _params.x0;
    // T yk = (T) i / _params.height * (_params.y1 - _params.y0) + _params.y0;

    for(unsigned t=0; t<ITERATION; ++t) {
      xk += _params.talpha * (cos( _params.t0 * _params.talpha + yk + cos(_params.t1 * _params.talpha + PI * xk)));
      yk += _params.talpha * (cos( _params.t2 * _params.talpha + xk + cos(_params.t3 * _params.talpha + PI * yk)));

      int px = unmap(xk, _params.x0, _params.x1, (T)_params.width);
      int py = unmap(yk, _params.y0, _params.y1, (T)_params.height);
      if (px>=0 && py>=0 && px<_params.width && py<_params.height) {
        unsigned offset = px+py*_params.width;
        T v = 0.001;
        if( RenderTrace ) {
          if( (i&31)==0 ) {
            hsl2rgb(_data+offset, _params.n, 0.5*(float(t)/63)+0.25, 1.0, 0.6);
          }

        }
        else {

          if(UseAtomics) {
            atomicAdd(_data+offset, v); // just density
          } else {
            _data[offset] += v;
          }
        }
      }
    } // for
  }
}



template<typename T>
double launch_kernel(T* _data, const Parameters<T>& _params)
{
  int numSMs;
  int devId = 0;
  cudaDeviceGetAttribute(&numSMs, cudaDevAttrMultiProcessorCount, devId);

  dim3 threads( 16, 16 );
  dim3 threads1d( 128 );
  dim3 blocks( 32*numSMs );
  size_t num_bytes;
  cudaError_t err;

  CHECK_CUDA(cudaEventRecord(custart));
  auto start_time = std::chrono::high_resolution_clock::now();

//  d_computeImage<<<blocks, threads>>>(_data, _params);
  d_computeImage_1D<<<blocks, threads1d>>>(_data, _params);

  CHECK_CUDA(cudaEventRecord(cuend));
  CHECK_CUDA( cudaEventSynchronize(cuend) );
  auto end_time = std::chrono::high_resolution_clock::now();

  d_colorImage<<<blocks, threads1d>>>(_data, _params);

  return std::chrono::duration<double, std::milli>(end_time - start_time).count();

  // float ms = 0.0f;
  // CHECK_CUDA( cudaEventElapsedTime(&ms, custart, cuend) );
  // return ms;
}


/**
 *
 */
template<typename T>
void alloc_buffer(T** _data, unsigned n)
{
  if(_data && *_data) {
    CHECK_CUDA( cudaFree(*_data) );
    CHECK_CUDA( cudaEventDestroy(custart) );
    CHECK_CUDA( cudaEventDestroy(cuend) );
  }
  CHECK_CUDA( cudaMalloc(_data, 3*n*sizeof(T)) );
  CHECK_CUDA( cudaEventCreate(&custart) );
  CHECK_CUDA( cudaEventCreate(&cuend) );
}

/**
 *
 */
template<typename T>
void init_buffer(T* _data, unsigned n)
{
  CHECK_CUDA( cudaMemset(_data, 0.0, 3*n*sizeof(T)));
  CHECK_CUDA( cudaDeviceSetCacheConfig(cudaFuncCachePreferL1) );
}
template<typename T>
void download(T* _image, T* _data, unsigned n) {
  CHECK_CUDA(cudaMemcpy(_image, _data, 3*n*sizeof(T), cudaMemcpyDeviceToHost));
}

/**
 *
 */
template<typename T>
void cleanup_cuda(T* _data)
{
  if(_data) {
    CHECK_CUDA( cudaFree(_data) );
    CHECK_CUDA( cudaEventDestroy(custart) );
    CHECK_CUDA( cudaEventDestroy(cuend) );
  }
}

int main(int argc, char **argv) {
  char buffer[17];
  string fname;
  char in;
  int flag = 0;
  int numberOfTests = 20;
  float dispersion = 0;
  uint32_t w = WIDTH_START;
  uint32_t h = HEIGHT_START;
  // dispersion initilation
  float talphaStart = 0.0;   		// sets start value for dispersion
  float talphaIncrement = 0.1;		// 0.01		// sets values by wich talpha is incremented
  float talphaCount = 2;			// sets how often talpha is incremented
  Parameters<float> params;
  float* data = nullptr;

  //checking cmd-line for arguments and override settings if necessary
  if (argc >= 2)
	  fname = std::string(argv[1]);
  if (argc >= 3)
	  talphaStart = atof(argv[2]);
  if (argc >= 4)
	  talphaIncrement = atof(argv[3]);
  if (argc >= 5)
	  talphaCount = atoi(argv[4]);
  if (argc >= 6)
    w = atoi(argv[5]);
  if (argc >= 7)
    h = atoi(argv[6]);
  if (argc >= 8)
    numberOfTests = atoi(argv[7]);

  if(talphaCount<1)
    talphaCount = 1;

  //creates log <- size depending on numberOfTests
  float log[numberOfTests + 3];//Height,Width,talpha,Test1,Test2...,Testn
  uint32_t img_size = w*h;
  //Output file
  std::CsvWriter Output;
  //generating first line for CSV-File (headline)
  std::stringstream sstr;
  sstr << "Width, Height, talpha,";
  for (int count = 0; count < numberOfTests; ++count){
    sstr << "Test"<<count<<",";
  }

  Output.addLineString(sstr.str());
  //the image is computed numberOfRescaling*numberOfTest-Times
  for (int rescaleCount = 0; rescaleCount <= numberOfRescalings; ++rescaleCount) {
  	//rescaling image
    //float* image = new float[3*img_size];
  	//performing computation numberOfTests-times with rescaled resolution
  	if (numberOfTests < 1){
  		return 100;
  	}
  	//set height and with in log
  	log[0] = w;
  	log[1] = h;
    params.width = w;
    params.height = h;
    params.n = h*w;

    alloc_buffer(&data, params.n);

  	for(int count = 0; count < talphaCount; ++count) {
  		//increment talpha
      if ( count > -1){
        dispersion = talphaStart + count * talphaIncrement;
      }
      //write talpha to log
      log[2] = dispersion;
      params.talpha = dispersion;
      double duration = 0;

      //compute image numberOfTests-times + 1 warmup
      for(int testNumber = -1; testNumber < numberOfTests; ++testNumber){
        //initImage(image, w, h);
        init_buffer(data, params.n);
        {
          duration = launch_kernel(data, params);
        }
        if(testNumber<0) // warmup
          continue;
        log[testNumber + 3] = duration;
      }

      for(int testNumber = 0; testNumber < numberOfTests; ++testNumber)
      {
        cout <<"Test "<< testNumber+1 <<" executed in "<< log[testNumber+3] << " ms; Resolution "<<w<<"x"<<h<<" talpha "<<log[2]<< endl;
      }
      Output.addLineValues(log, numberOfTests + 3);
      dispersion = 0;
  	}

#if EnableSafedialog == 1
    if(rescaleCount == numberOfRescalings) {
      //savedialog for last picture
      // cout << "Save file? j/n" << endl;
      // std::cin >> in;
      // if ( in == 'j') {
      //   flag = 1;
      // }
      // if (flag == 1){
        float* image = new float[3*img_size];
        download(image, data, params.n);
        ImageWriter::PPM::writeRGB(image, w, h, fname + ".png");
        cout <<"Saved to "+ fname + ".png.\n";
        delete[] image;
//      }
    }
#endif
  	//delete[] image;
    cleanup_cuda(data);
    data = nullptr;
    w += RES_EXPANSION;
    h += RES_EXPANSION;
    img_size = w*h;
  }
  cout << endl;
  //Write Log to CSV-file

  if (fname.length() < 1)
	  Output.writeToCSV("result");
  else
	  Output.writeToCSV(fname);

  CHECK_CUDA(cudaDeviceReset());

  //exit programm
  return 0;
}
