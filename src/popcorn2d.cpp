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
#define PI 3.14159265359
#define VERBOSE 0
#define TESTS 10 //sets numbers of performed tests

using namespace std;
//image settings
const uint32_t WIDTH  = 400;
const uint32_t HEIGHT = 400;
const uint32_t ITERATION = 64;
const uint32_t IMG_SIZE = WIDTH * HEIGHT;

//parameters
const int passCount = 2;
const float s = 5.0, q = -5.0, l = 5.0, p = -5.0;
const uint32_t w = WIDTH;
const uint32_t h = HEIGHT;
const float t0 = 31.1;
const float t1 = -43.4;
const float t2 = -43.3;
const float t3 = 22.2;
float talpha = 0.0632;


/**
 * Set color values for pixel (i,j).
 * Underlying format is flattened structure of arrays
 *  red[Pixel 1..n], green[Pixel 1..n] and blue[Pixel 1..n].
 * This allows coalesced memory access on GPUs.
 */
template<typename T>
void colorImage(T* image) {
	//color order ist r, g, b
	float colors[3];

	for (uint32_t y=0; y  <  HEIGHT; ++y) {
	 for (uint32_t x=0; x  <  WIDTH; ++x) {
	      float density = sqrt(image[x + y*WIDTH ]);
	      colors[0] = pow(density,0.4);
	      colors[1] = pow(density,1.0);
	      colors[2] = pow(density,1.4);
	      // check if color values in range of [0,1], else correctj
	      for(int count = 0; count <  3; ++count){
	    	  if (colors[count] > 1 ){
	    		  colors[count] = 1;
	    	  }else if(colors[count] < 0){
	    		  colors[count] = 0;
	    	  }
	      }
	      image[ x + y*WIDTH ]              = 1.0 - 0.5*colors[0];
	      image[ x + y*WIDTH + IMG_SIZE ]   = 1.0 - 0.2*colors[1];
	      image[ x + y*WIDTH + 2*IMG_SIZE ] = 1.0 - 0.4*colors[2];
	 }
	}
}

int transX (float x){
	return ((float)(x - l) / (p - l) * w);
}

int transY (float y){
	return (float)((y - q) / (s - q) * h);
}
/**
 * Compute the pixels. Color values are from [0,1].
 * @todo implement popcorn 2d fractal
 * @todo find OpenACC directives to accelerate the computation
 */
template<typename T>
void initImage(T* image){
	for (uint32_t y=0; y  <  HEIGHT; ++y) {
		 for (uint32_t x=0; x  <  WIDTH; ++x) {
			 image[ x + y*WIDTH ] = 0;
		 }
	}
}

template<typename T>
void computeImage(T* image) {
	float xk;
	float yk;
	int each = 50;
	int px, py;

	//generate values

	for (uint32_t y = 0; y < HEIGHT; ++y) {
	 for (uint32_t x = 0; x < WIDTH; ++x) {
		 //set start values
		 xk = (float) x / w * (p - l) + l;
		 yk = (float) y / h * (s - q) + q;
	  for (uint32_t j = 0; j <  ITERATION; j++) {
		  //perform iterations
		  xk +=(float)  talpha * (cos( (float)t0 * talpha + yk + cos(t1 * talpha + (PI * xk))));
		  yk +=(float)  talpha * (cos( (float)t2 * talpha + xk + cos(t3 * talpha + PI * yk)));
		  py = transY (yk);
		  px = transX (xk);
		  if ( px >= 0 && py >= 0 && px  <  WIDTH && py < HEIGHT) {
			  image[ px + py*WIDTH ] += 0.001;
		  }
	  }
	 }
#if VERBOSE == 1
	 //print progress
	 if((y%each)==0)
	       std::cout << "Progress = " << 100.0*y/(HEIGHT-1) << " %"<< endl;
	// color pixels by generated values
#endif
	}

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
  char test[17];
  char in;
  int flag = 0;
  initImage(image);
  int log[TESTS];

  //performing computation TESTS-times
  if (TESTS < 1){
	  return 100;
  }
  for(int testNumber = 0; testNumber < TESTS; testNumber++)
  {
	  auto start_time = chrono::steady_clock::now();
	  //actuall computation
	  for(int pass = 0; pass < passCount; ++pass){
#if VERBOSE==1
		  std::cout << "Pass " << (pass+1) << " out of " << passCount << endl;
#endif
		  computeImage(image);
		  talpha += 0.001;
	  }
	  colorImage(image);
	  auto end_time = chrono::steady_clock::now();
	  log[testNumber] = chrono::duration_cast<chrono::milliseconds>(end_time - start_time).count();
  }
  //Filename for computated picture
  getFileName(test);
  //Output data from log-array
  for(int logCount = 0; logCount < TESTS; logCount++) {
	  cout <<"Test "<< logCount+1 <<" executed in "<< log[logCount] << " ms "<< endl;
  }
  //savedialog
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
  //exit programm
  delete[] image;
  return 0;
}
