# Local Installation of HdrHistogram_c

1) git clone https://github.com/HdrHistogram/HdrHistogram_c.git
2) cd HdrHistogram_c;mkdir build;cd build
3) cmake .. -DCMAKE_INSTALL_PREFIX=$(pwd)/../local_install
4) make && make install 
