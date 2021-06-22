# part of windows

lib LibC
  fun QueryPerformanceCounter(lpPerformanceCount : LARGE_INTEGER*) : BOOL
  fun QueryPerformanceFrequency(lpFrequency : LARGE_INTEGER*) : BOOL
end
