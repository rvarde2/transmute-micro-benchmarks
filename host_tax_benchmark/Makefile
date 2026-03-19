CXX = g++
CXXFLAGS = -O3 -march=native
TARGET = science_proxy
SIZE ?= 8192

all: $(TARGET)

$(TARGET): science_proxy.cpp
	$(CXX) $(CXXFLAGS) science_proxy.cpp -o $(TARGET)

clean:
	rm -f $(TARGET) *.tmp *.csv
