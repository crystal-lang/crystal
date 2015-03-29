Building Crystal:
=================

The working directory is `crystal-0.6.1-win32` on both linux and windows.

1. cross-compile on linux with:

		bin/crystal build src/compiler/crystal.cr --cross-compile "windows x86" --single-module --target "i686-pc-win32-gnu" --release -o bin/crystal

2. link on windows to get crystal.exe with:

		gcc bin\crystal.o -m32 -static -lpthread -lws2_32 -Llib32 -lgc -lpcre -lLLVM -limagehlp -lstdc++ -lz -o bin\crystal

3. test crystal.exe on windows with:

		bin\crystal build src\compiler\crystal.cr --cross-compile "windows x86" --single-module --target "i686-pc-win32-gnu" --release -o bin\crystal_win

4. link on windows to get crystal_win.exe with:

		gcc bin\crystal_win.o -m32 -static -lpthread -lws2_32 -Llib32 -lgc -lpcre -lLLVM -limagehlp -lstdc++ -lz -o bin\crystal_win

5. compile and link test.cr on windows with:

		bin\crystal build bin\test.cr --cross-compile "windows x86" --single-module --target "i686-pc-win32-gnu" --release -o bin\test
		gcc bin\test.o -m32 -Llib32 -lgc -lpcre -o bin\test

Notes
=====
1. Only tested with TDM64-GCC 4.9.2 so far.
2. Comments about the win32-state are marked with `#--`.
