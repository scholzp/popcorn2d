#ifndef PPM_HPP_
#define PPM_HPP_

#include <string>
#include <cinttypes>
#include <fstream>
#include <iostream>

namespace ImageWriter {
  namespace PPM {
    template<typename T>
    void writeRGB(const T* image,
                  uint32_t width,
                  uint32_t height,
                  const std::string &fname) {
      std::ofstream ppm(fname.c_str(), std::ios::out | std::ios::binary);
      if (ppm.is_open()) {
        ppm << "P6\n"
            << width
            << " "
            << height
            << "\n255\n";

        unsigned char r, g, b;
        uint32_t img_size = width * height;
        for (uint32_t i=0; i<img_size; ++i) {
          r = static_cast<unsigned char>(std::min(1.f, image[i             ]) * 255);
          g = static_cast<unsigned char>(std::min(1.f, image[i +   img_size]) * 255);
          b = static_cast<unsigned char>(std::min(1.f, image[i + 2*img_size]) * 255);
          ppm << r << g << b;
        }
        ppm.close();
      } else {
        std::cerr << "Error. Unable to open " << fname << std::endl;
      }
    }
  } // PPM
} // ImageWriter

#endif
