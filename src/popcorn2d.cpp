#include "ppm.hpp"
#include "CsvWriter.h"
#include <sstream>
#include <iostream>
#include <chrono>
#include <time.h>
#include <cinttypes>
#include <math.h>

// @todo store benchmark relevant parameters to output
// @todo remove defines with const expressions
// @todo maybe use cmd-line args, also for output file name

#if defined(__PGI) or defined(__PGIC__)
#include <openacc.h>
#endif


#define PI 3.14159265359
#define VERBOSE 0

/*test setup
 * Total Number of performed tests: numberofTest*talphaCount*numberOfRescaling
 * Number of tests performed with set talpha: numberOfTests
 * Number of tests performed with set resolution: numberOfTest*talphaCount
 */

#define numberOfTests 1 //sets number of performed tests with given resolution
#define numberOfRescalings 0 //sets number of resolution rescalings
#define EnableSafedialog 1 /*controlls if safedialog is displayed or skipped
							 if skipped, picture wont be safed to file*/


using namespace std;

//image settings
const uint32_t ITERATION = 64;
const uint32_t RES_EXPANSION = 128; //expands image resolution for each test
const uint32_t WIDTH_START  = 256;
const uint32_t HEIGHT_START = 256;

//parameters
const float s = 5.0, q = -5.0, l = 5.0, p = -5.0; //sets zoom
const float t0 = 31.1;
const float t1 = -43.4;
const float t2 = -43.3;
const float t3 = 22.2;

/**
 * Set color values for pixel (i,j).
 * Underlying format is flattened structure of arrays
 *  red[Pixel 1..n], green[Pixel 1..n] and blue[Pixel 1..n].
 * This allows coalesced memory access on GPUs.
 */
template<typename T>
void colorImage(T* image, uint32_t w, uint32_t h, uint32_t img_size) {
	//color order ist r, g, b
#pragma acc parallel loop independent present(image)
	for (uint32_t y=0; y  <  h; ++y) {
#pragma acc loop independent
    for (uint32_t x=0; x  <  w; ++x) {
      float colors[3];
      float density = sqrt(image[x + y*w ]);
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

      image[ x + y*w ]              = 1.0-0.5*colors[0];
      image[ x + y*w + img_size ]   = 1.0-0.2*colors[1];
      image[ x + y*w + 2*img_size ] = 1.0-0.4*colors[2];
    }
	}
}

int transX (float x, float w){
	return ((float)(x - l) / (p - l) * w);
}

int transY (float y, float h){
	return (float)((y - q) / (s - q) * h);
}

/**
 * Compute the pixels. Color values are from [0,1].
 * @todo implement popcorn 2d fractal
 * @todo find OpenACC directives to accelerate the computation
 */
template<typename T>
void initImage(T* image, uint32_t w, uint32_t h){
	for (uint32_t y=0; y  <  h; ++y) {
		 for (uint32_t x=0; x  <  w; ++x) {
			 image[ x + y*w ] = 0;
		 }
	}
}

template<typename T>
void computeImage(T* image, float talpha, uint32_t w, uint32_t h) {
#pragma acc parallel loop independent present(image)
    for (uint32_t y = 0; y < h; ++y) {
#pragma acc loop independent
      for (uint32_t x = 0; x < w; ++x) {
        //set start values
        float xk = (float) x / w * (p - l) + l;
        float yk = (float) y / h * (s - q) + q;
#pragma acc loop seq
        for (uint32_t j = 0; j <  ITERATION; j++) {
          //perform iterations
          xk +=(float)  talpha * (cos( (float)t0 * talpha + yk + cos(t1 * talpha + (PI * xk))));
          yk +=(float)  talpha * (cos( (float)t2 * talpha + xk + cos(t3 * talpha + PI * yk)));
          int py = transY (yk, h);
          int px = transX (xk, w);
          if ( px >= 0 && py >= 0 && px  <  w && py < h) {
//            #pragma acc atomic update
            image[ px + py*w ] += 0.001;
          }
        }
      }
#if VERBOSE == 1
      int each = 50;
      //print progress
      if((y%each)==0)
        std::cout << "Progress = " << 100.0*y/(h-1) << " %"<< endl;
    	// color pixels by generated values
#endif
    }
}

char * getFileName(char *dst, int ext){
/*
 * Time to string formated as: ddMMYYYYmmss
 * if "ext" == 0, then there will be not extension added
 * if "ext" == 1, then file extension will be ppm
 * if "ext" == 2, then file extension will be csv
 * maybe some more extensions will be added
*/
	char *d = dst;
	char buffer[18];
	int i = 0;
	time_t t;
	struct tm * timeinfo;
	time(&t);
	ctime(&t);
	timeinfo = localtime(&t);
	//As notes in comment near function head
	if (ext == 1){
		strftime(buffer,18, "%d%m%Y%H%M.ppm", timeinfo );
	} else if (ext == 2){
		strftime(buffer,18, "%d%m%Y%H%M.csv", timeinfo );
	}else if(ext == 0){
		strftime(buffer,18, "%d%m%Y%H%M", timeinfo );
	}

	while (i < 17) {
		*d = buffer[i];
		d++;
		i++;
	}
	return dst;
}


int main(int argc, char **argv) {
  char buffer[17];
  string fname;
  char in;
  int flag = 0;
  float log[numberOfTests + 3];//Height,Width,talpha,Test1,Test2...,Testn
  float dispersion = 0;
  uint32_t w = WIDTH_START;
  uint32_t h = HEIGHT_START;
  uint32_t img_size = w*h;
  // dispersion initilation
  float talphaStart = 0.0;   		// sets start value for dispersion
  float talphaIncrement = 0.1;		// 0.01		// sets values by wich talpha is incremented
  float talphaCount = 2;			// sets how often talpha is incremented
  if (argc >= 2){
	  fname = std::string(argv[1]);
  }
  if (argc >= 3)
	  talphaStart = atof(argv[2]);
  if (argc >= 4)
	  talphaIncrement = atof(argv[3]);
  if (argc >= 5)
	  talphaCount = atoi(argv[4]);
  //Output file
  std::CsvWriter Output;
  //generating first line for CSV-File (headline)
  std::stringstream sstr;
  sstr << "Width, Height, talpha,";
  for (int count = 0; count < numberOfTests; count++ ){
    sstr << "Test"<<count<<",";
  }

  Output.addLineString(sstr.str());
  //the image is computed numberOfRescaling*numberOfTest-Times
  for (int rescaleCount = 0; rescaleCount <= numberOfRescalings; ++rescaleCount) {
  	//rescaling image
    float* image = new float[3*img_size];
  	//performing computation numberOfTests-times with rescaled resolution
  	if (numberOfTests < 1){
  		return 100;
  	}
  	//set height and with in log
  	log[0] = w;
  	log[1] = h;
  	for(int count = 0; count < talphaCount; ++count){
  		//increment talpha
      if ( count > -1){
        dispersion = talphaStart + count * talphaIncrement;
      }
      //write talpha to log
      log[2] = dispersion;
      double duration = 0;

      //compute image numberOfTests-times + 1 warmup
      for(int testNumber = -1; testNumber < numberOfTests; testNumber++){
        initImage(image, w, h);
#pragma acc data copy(image[0:3*img_size])
        {
          auto start_time = std::chrono::high_resolution_clock::now();
          computeImage(image, dispersion, w, h);
          auto end_time = std::chrono::high_resolution_clock::now();
          duration = std::chrono::duration<double, std::milli>(end_time - start_time).count();
          colorImage(image, w, h, img_size);
        }
        if(testNumber<0) // warmup
          continue;
        log[testNumber + 3] = duration;
		}

		for(int testNumber = 0; testNumber < numberOfTests; testNumber++)
		{
      cout <<"Test "<< testNumber+1 <<" executed in "<< log[testNumber+3] << " ms; Resolution "<<w<<"x"<<h<<" talpha "<<log[2]<< endl;
		}
		Output.addLineValues(log, numberOfTests + 3);
		dispersion = 0;
  	}

#if EnableSafedialog == 1
    if(rescaleCount == numberOfRescalings) {
      getFileName(buffer, 1);
      //savedialog for last picture
      cout << "Save file? j/n" << endl;
      std::cin >> in;
      if ( in == 'j') {
        flag = 1;
      }
      if (flag == 1){
        cout <<"Saved to: " <<buffer;
        ImageWriter::PPM::writeRGB(image, w, h, buffer);
      }
    }
#endif
  	delete[] image;
    w += RES_EXPANSION;
    h += RES_EXPANSION;
    img_size = w*h;
  }
  cout << endl;
  //Write Log to CSV-file
  getFileName(buffer, 0);
  if (fname.length() < 1)
	  Output.writeToCSV(buffer);
  else
	  Output.writeToCSV(fname);

  //exit programm
  return 0;
}
