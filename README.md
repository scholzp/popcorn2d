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

__TODO__
- [ ] implement Clifford Pickovers Popcorn 2D fractal
- [ ] use OpenACC directives to (hopefully) accelerate performance
