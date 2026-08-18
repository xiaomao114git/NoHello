
#pragma once

#ifndef NOHELLO_LOG_H
#define NOHELLO_LOG_H

#ifdef DEBUG_BUILD
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, "NoHello", __VA_ARGS__)
#else
#define LOGD(...) ((void) 0)
#endif

#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, "NoHello", __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "NoHello", __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, "NoHello", __VA_ARGS__)
#define LOGF(...) __android_log_print(ANDROID_LOG_FATAL, "NoHello", __VA_ARGS__)

#endif //NOHELLO_LOG_H
