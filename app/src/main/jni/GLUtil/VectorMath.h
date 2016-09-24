// VectorMath.h

#pragma once

///@todo Where do we need these Windows headers?
#ifdef _WIN32
#  define WINDOWS_LEAN_AND_MEAN
#  define NOMINMAX
#  include <windows.h>
#endif

#include "vectortypes.h"

float  length   (float3 v);
float  length2  (float3 v);
float3 normalize(float3 v);
float  dot      (float3 a, float3 b);
float3 cross    (const float3& b, const float3& c);
float3 operator+(const float3& a, const float3& b);
float3 operator-(const float3& a, const float3& b);
float3 operator*(      float    , const float3& b);

int2   operator+(const int2& a, const int2& b);
