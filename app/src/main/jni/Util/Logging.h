// Logging.h

#pragma once

#ifdef __ANDROID__

#define LOG_INFO(...) LOGI(__VA_ARGS__)
#define LOG_INFO_NONEWLINE(...) LOGI(__VA_ARGS__)
#define LOG_ERROR(...) LOGE(__VA_ARGS__)

#include <android/log.h>
#define  LOG_TAG    "flickercladding"
#define  LOGI(...)  __android_log_print(ANDROID_LOG_INFO,LOG_TAG,__VA_ARGS__)
#define  LOGE(...)  __android_log_print(ANDROID_LOG_ERROR,LOG_TAG,__VA_ARGS__)

#else
// For the desktop version, the Logger class is included as a project
// so all log messages can be fed through it and dumped to file.
#include "Logger.h"
#define LOGI(...) LOG_INFO(__VA_ARGS__)
#define LOGE(...) LOG_ERROR(__VA_ARGS__)

#endif
