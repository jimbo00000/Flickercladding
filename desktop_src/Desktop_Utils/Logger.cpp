// Logger.cpp

#include "Logger.h"

#ifdef _WIN32
#include "WindowsFunctions.h"
#endif
#include "DebugOutput.h"

#include <stdio.h>
#include <stdarg.h>
#include <time.h>

const int Logger::s_bufferSz = 2048*8;

///@brief Default constructor: called the first time Instance() is called.
/// Open the output file.
Logger::Logger()
: m_logFilename("log.txt")
{
    ///@note Logger will dump to the current working directory unless SetOutputFilename is called.
}

///@brief Flush and close the output file.
Logger::~Logger()
{
    CloseStream();
}

void Logger::SetOutputFilename(const std::string& filename)
{
    CloseStream();
    m_logFilename = filename;
    OpenStream();
}

void Logger::OpenStream()
{
    m_stream.open(m_logFilename.c_str(), std::ios::out);

#ifdef _WIN32
    SYSTEMTIME sysTime;
    ::GetLocalTime(&sysTime);
    const std::string t = GetStringFromSYSTEMTIME(sysTime);

    if (m_stream.is_open())
    {
        m_stream
            << "Opening log at "
            << t
            << std::endl;
    }
    else
    {
        OutputPrint("Error opening log stream...");
    }
#endif
}

void Logger::CloseStream()
{
    if (m_stream.is_open())
    {
        m_stream.close();
    }
}

///@brief Write a message to the log's output stream with a trailing newline.
///@param format The string to write to the log.
void Logger::WriteLn(const char* format, ...)
{
    if (m_stream.is_open() == false)
    {
        OpenStream();
    }

    char buffer[s_bufferSz];

    va_list args;
    va_start(args, format);
    vsnprintf(buffer, s_bufferSz, format, args);
    va_end(args);

    m_stream
        << buffer
        << std::endl;

    m_stream.flush();

    OutputPrint(buffer);
}

///@brief Write a message to the log's output stream.
///@param format The string to write to the log.
void Logger::Write(const char* format, ...)
{
    if (m_stream.is_open() == false)
    {
        OpenStream();
    }

    char buffer[s_bufferSz];

    va_list args;
    va_start(args, format);
    vsnprintf(buffer, s_bufferSz, format, args);
    va_end(args);

    m_stream << buffer;

    m_stream.flush();

    OutputPrint(buffer);
}

///@brief Write a message to the log's output stream with a noticeable error message.
///@param format The string to write to the log.
void Logger::WriteError(const char* format, ...)
{
    if (m_stream.is_open() == false)
    {
        OpenStream();
    }

    char buffer[s_bufferSz];

    va_list args;
    va_start(args, format);
    vsnprintf(buffer, s_bufferSz, format, args);
    va_end(args);

    m_stream
        << std::endl
        << "    *** ERROR *** "
        << buffer
        << std::endl
        << std::endl;

    m_stream.flush();

    OutputPrint(buffer);
}
