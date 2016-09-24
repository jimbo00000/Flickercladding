// DebugOutput.cpp

#ifdef _WIN32
#define NOMINMAX
#include <windows.h>
#endif

#include "DebugOutput.h"
#include <sstream>
#include <iostream>
#include <stdio.h>
#include <stdarg.h>

void OutputPrint(char* format, ...)
{
    const unsigned int bufSz = 2048;
    char buffer[bufSz];

    va_list args;
    va_start(args, format);
    vsnprintf(buffer, bufSz, format, args);
    va_end(args);

    std::cout << buffer << std::endl;

#ifdef _WIN32
    // Send to Visual Studio console as well.
    std::wostringstream osw;
    osw << buffer << std::endl;
    OutputDebugString(osw.str().c_str());
#endif
}
