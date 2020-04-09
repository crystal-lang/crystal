# Crystal Programming Language

Copyright 2012-2020 Manas Technology Solutions.

This product includes software developed at Manas Technology Solutions (<https://manas.tech/>).

Apache License v2.0 applies to all works.

Please see [LICENSE](/LICENSE) for additional copyright and licensing information.

## External libraries information

Crystal compiler links the following libraries, which have their own license:

  * [LLVM][] - [BSD-3, effectively][]
  * [PCRE][] - [BSD-3][]
  * [libevent2][] - [BSD-3][]
  * [libiconv][] - [LGPLv3][]
  * [bdwgc][] - [MIT][]

Crystal compiler calls the following tools as external process on compiling, which have their own license:

  * [pkg-config](https://www.freedesktop.org/wiki/Software/pkg-config/) - [GPLv3]

Crystal standard library uses the following libraries, which have their own licenses:

  * [LLVM][] - [BSD-3, effectively][]
  * [PCRE][] - [BSD-3][]
  * [libevent2][] - [BSD-3][]
  * [libiconv][] - [LGPLv3][]
  * [bdwgc][] - [MIT][]
  * [Zlib][] - [Zlib][Zlib-license]
  * [OpenSSL][] - [Apache License v2.0](https://www.openssl.org/source/apache-license-2.0.txt)
  * [Libxml2][] - [MIT][]
  * [LibYAML][] - [MIT][]
  * [readline](https://tiswww.case.edu/php/chet/readline/rltop.html) - [GPLv3][]
  * [GMP](https://gmplib.org/) - [LGPLv3][]

Crystal playground includes the following libraries, which have their own licenses.
(There are these files under [/src/compiler/crystal/tools/playground/public/vendor](/src/compiler/crystal/tools/playground/public/vendor)):

   * [jQuery](https://jquery.com/) - [MIT][]
     `Copyright JS Foundation and other contributors, https://js.foundation/`
   * [Octicons](https://octicons.github.com/) - [MIT][] (for codes) or [OFL-1.1][] (for fonts) `(c) 2012-2016 GitHub, Inc.`
   * [Materialize](http://materializecss.com/) - [MIT][] `Copyright (c) 2014-2015 Materialize`
   * [CodeMirror](https://codemirror.net/) - [MIT][] `Copyright (C) 2016 by Marijn Haverbeke <marijnh@gmail.com> and others`
   * [ansi\_up](https://github.com/drudru/ansi\_up) - [MIT][] `Copyright (c) 2011 Dru Nelson`

<!-- licenses -->
[BSD-3]: https://opensource.org/licenses/BSD-3-Clause
[BSD-3, effectively]: http://releases.llvm.org/2.8/LICENSE.TXT
[GPLv3]: https://www.gnu.org/licenses/gpl-3.0.en.html
[LGPLv3]: https://www.gnu.org/licenses/lgpl-3.0.en.html
[MIT]: https://opensource.org/licenses/MIT
[OFL-1.1]: https://opensource.org/licenses/OFL-1.1
[Zlib-license]: https://opensource.org/licenses/Zlib
<!-- libraries -->
[bdwgc]: http://www.hboehm.info/gc/
[libevent2]: http://libevent.org/
[libiconv]: https://www.gnu.org/software/libiconv/
[Libxml2]: http://xmlsoft.org/
[LibYAML]: http://pyyaml.org/wiki/LibYAML
[LLVM]: http://llvm.org/
[OpenSSL]: https://www.openssl.org/
[PCRE]: http://pcre.org/
[Zlib]: http://www.zlib.net/
