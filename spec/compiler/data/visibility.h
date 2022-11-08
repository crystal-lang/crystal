#ifdef _WIN32
  #define EXPORT __declspec(dllexport)
  #define LOCAL
#else
  #define EXPORT __attribute__ ((visibility ("default")))
  #define LOCAL __attribute__ ((visibility ("hidden")))
#endif
