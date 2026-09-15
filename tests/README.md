# Warband Camp Phase Allocation Tests

This directory contains standalone unit tests verifying the spatial phase allocation algorithm used by `mod-warband-camp`.

## Running the Test

### MSVC (Windows):
```cmd
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
cl /std:c++17 /EHsc camp_alloc_test.cpp /Fe:camp_alloc_test.exe
.\camp_alloc_test.exe
```

### GCC / Clang (Linux / macOS / MinGW):
```bash
g++ -std=c++17 camp_alloc_test.cpp -o camp_alloc_test
./camp_alloc_test
```
