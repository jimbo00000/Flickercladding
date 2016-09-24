// Logger.h

#pragma once

#include <fstream>

#ifdef _DEBUG
#define VERBOSE_LOGGING
#endif

#ifdef _WIN32
#  ifdef VERBOSE_LOGGING
#  define LOG_INFO(string, ...) Logger::Instance().WriteLn(string , __VA_ARGS__)
#  define LOG_INFO_NONEWLINE(string, ...) Logger::Instance().Write(string , __VA_ARGS__)
#  else
#  define LOG_INFO(string, ...)
#  define LOG_INFO_NONEWLINE(string, ...)
#  endif

#  define LOG_WARNING(string, ...) Logger::Instance().WriteLn(string , __VA_ARGS__)
#  define LOG_ERROR(string, ...) Logger::Instance().WriteError(string , __VA_ARGS__)
#endif

#ifdef _UNIX
#  define LOG_INFO(string, args...) Logger::Instance().Write(string, ## args)
#  define LOG_INFO_NONEWLINE(string, args...) Logger::Instance().Write(string, ## args)
#  define LOG_WARNING(string, args...) Logger::Instance().Write(string, ## args)
#  define LOG_ERROR(string, args...) Logger::Instance().Write(string, ## args)
#endif

#ifdef _MACOS
#  define LOG_INFO(string, args...) Logger::Instance().Write(string, ## args)
#  define LOG_INFO_NONEWLINE(string, args...) Logger::Instance().Write(string, ## args)
#  define LOG_WARNING(string, args...) Logger::Instance().Write(string, ## args)
#  define LOG_ERROR(string, args...) Logger::Instance().Write(string, ## args)
#endif


///@brief Writes log messages to output stream.
class Logger
{
public:
    void SetOutputFilename(const std::string& filename);
    void OpenStream();
    void CloseStream();

    void Write(const char*, ...);
    void WriteLn(const char*, ...);
    void WriteError(const char*, ...);

    static Logger& Instance()
    {
        static Logger theLogger;   // Instantiated when this function is called
        return theLogger;
    }

    static const int s_bufferSz;

private:
    Logger();                           ///< disallow default constructor
    Logger(const Logger&);              ///< disallow copy constructor
    Logger& operator =(const Logger&); ///< disallow assignment operator
    virtual ~Logger();

    std::string m_logFilename;
    std::ofstream  m_stream;
};
