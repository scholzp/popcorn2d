#include "ppm.hpp"

#if defined(__PGI) or defined(__PGIC__)
#define USE_OPENACC 1
#include <openacc.h>
#endif

#include <iostream>
#include <chrono>
#include <time.h>
#include <cinttypes>
#include <math.h>
#define PI 3.14159265

using namespace std;
//image settings
const uint32_t WIDTH  = 1024;
const uint32_t HEIGHT = 1024;
const uint32_t ITERATION = 256;
const uint32_t IMG_SIZE = WIDTH * HEIGHT;

//parameters
const int t = -1, b = 1, l = 1, r = -1;
const uint32_t w = WIDTH;
const uint32_t h = HEIGHT;
const float t0 = 31.1;
const float t1 = -43.4;
const float t2 = -43.3;
const float t3 = 22.2;
const float talpha = 0.067;


/**
 * Set color values for pixel (i,j).
 * Underlying format is flattened structure of arrays
 *  red[Pixel 1..n], green[Pixel 1..n] and blue[Pixel 1..n].
 * This allows coalesced memory access on GPUs.
 */
template<typename T>
void setPixel(T* image, uint32_t i, uint32_t j, T r, T g, T b) {
  image[ j + i*WIDTH ]              = r;
  image[ j + i*WIDTH + IMG_SIZE ]   = g;
  image[ j + i*WIDTH + 2*IMG_SIZE ] = b;
}

int transX (int x){
	return rint((x - l) / (r - l) * w);
}

int transY (int y){
	return rint((y - t) / (b - t) * h);
}
/**
 * Compute the pixels. Color values are from [0,1].
 * @todo implement popcorn 2d fractal
 * @todo find OpenACC directives to accelerate the computation
 */
template<typename T>
void computeImage(T* image) {
	float xk;
	float yk;
	int each = 50;
	int px, py;

/*
  for( uint32_t i=0; i<HEIGHT; ++i ) {
    for( uint32_t j=0; j<WIDTH; ++j ) {
      T red   = 0.05;
      T green = j*1.0/WIDTH;
      T blue  = 0.01;
      setPixel(image, i, j, red, green, blue);
    }
  }
*/

	//generate values
	for (uint32_t y = 0; y < HEIGHT; ++y) {
	 for (uint32_t x = 0; x < WIDTH; ++x) {
		 //set start values
		 xk = (float)x / w * (r - l) + l;
		 yk = (float)y / h * (b - t) + t;
	  for (uint32_t j = 0; j <  ITERATION; j++) {
		  //perform iterations
		  xk = xk + talpha*(cos( t0 * talpha + yk + cos (t1 * talpha + PI * xk)));
		  yk = yk + talpha*(cos( t2 * talpha + xk + cos (t3 * talpha + PI * yk)));
		  px = transX (xk);
		  py = transY (yk);
		  if ( px >= 0 && py >= 0 && px  <  WIDTH && py < HEIGHT) {
			  image[ py + px*WIDTH ] += 0.001;
	  }
	 }
	 //print progress
	 if((y%each)==0)
	       std::cout << "Progress = " << 100.0*y/(HEIGHT-1) << " %"<< endl;
	}
	// color pixels by generated values
	for (uint32_t y=0; y  <  HEIGHT; ++y) {
	 for (uint32_t x=0; x  <  WIDTH; ++x) {

	 }
	}
}

template<typename T>
void setValue(T* image, uint32_t i, uint32_t j, T v) {

}

char * getFileName(char *dst){
//Time to string formated as: ddMMYYYYmmss.ppm to create filename
	char *d = dst;
	char buffer[18];
	int i = 0;
	time_t t;
	struct tm * timeinfo;
	time(&t);
	ctime(&t);
	timeinfo = localtime(&t);
	strftime(buffer,18, "%d%m%Y%H%M.ppm", timeinfo );
	while (i < 17) {
		*d = buffer[i];
		d++;
		i++;
	}
	return dst;
}


int main(void) {

#ifdef USE_OPENACC
  // init device to separate init time
  acc_init(acc_device_nvidia);
  acc_set_device_num(0, acc_device_nvidia);
#endif

  float* image = new float[3*IMG_SIZE];
  auto start_time = chrono::steady_clock::now();
  char test[17];
  char in;
  int flag = 0;


  computeImage(image);
  auto end_time = chrono::steady_clock::now();
  getFileName(test);


  cout <<"Executed in "<< chrono::duration_cast<chrono::milliseconds>(end_time - start_time).count() << " ms "<< endl;
  cout << "Save file? j/n" << endl;
    std::cin >> in;
    if ( in == 'j') {
  	  flag = 1;
    }
  if (flag == 1){
	  cout <<"Saved to: " <<test;
	  ImageWriter::PPM::writeRGB(image, WIDTH, HEIGHT, test);
  }
  cout << endl;

  delete[] image;
  return 0;
}
