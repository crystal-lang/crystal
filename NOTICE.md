# Crystal Programming Language

Copyright 2012-2025 Manas Technology Solutions.

This product includes software developed at Manas Technology Solutions (<https://manas.tech/>).

Apache License v2.0 with Swift exception applies to all works unless specified
otherwise:

Please see [REUSE.toml](REUSE.toml) and [LICENSE](LICENSE) for additional
copyright and licensing information.

* This repository includes vendored libraries (shards) in `/lib/` which have
their own licenses. See [REUSE.toml](REUSE.toml) for details.
* Crystal playground includes vendored libraries with their own licenses. See
[src/compiler/crystal/tools/playground/public/vendor/REUSE.toml](src/compiler/crystal/tools/playground/public/vendor/REUSE.toml)
for details.

## External libraries information

Crystal compiler links the following libraries, which have their own license:

  * [LLVM][] - [Apache-2.0 with LLVM exceptions][]
  * [PCRE or PCRE2][] - [BSD-3][]
  * [libevent2][] - [BSD-3][]
  * [libiconv][] - [LGPLv3][]
  * [bdwgc][] - [MIT][]

Crystal compiler calls the following tools as external process on compiling, which have their own license:

  * [pkg-config](https://www.freedesktop.org/wiki/Software/pkg-config/) - [GPLv3]

Crystal standard library uses the following libraries, which have their own licenses:

  * [LLVM][] - [Apache-2.0 with LLVM exceptions][]
  * [PCRE or PCRE2][] - [BSD-3][]
  * [libevent2][] - [BSD-3][]
  * [libiconv][] - [LGPLv3][]
  * [bdwgc][] - [MIT][]
  * [Zlib][] - [Zlib][Zlib-license]
  * [OpenSSL][] - [Apache-2.0][]
  * [Libxml2][] - [MIT][]
  * [LibYAML][] - [MIT][]
  * [readline][] - [GPLv3][]
  * [GMP][] - [LGPLv3][]

<!-- licenses -->
[Apache-2.0]: https://www.openssl.org/source/apache-license-2.0.txt
[Apache-2.0 with LLVM exceptions]: https://raw.githubusercontent.com/llvm/llvm-project/main/llvm/LICENSE.TXT
[BSD-3]: https://opensource.org/licenses/BSD-3-Clause
[GPLv3]: https://www.gnu.org/licenses/gpl-3.0.en.html
[LGPLv3]: https://www.gnu.org/licenses/lgpl-3.0.en.html
[MIT]: https://opensource.org/licenses/MIT
[OFL-1.1]: https://opensource.org/licenses/OFL-1.1
[Zlib-license]: https://opensource.org/licenses/Zlib
<!-- libraries -->
[ansi\_up]: https://github.com/drudru/ansi\_up
[bdwgc]: http://www.hboehm.info/gc/
[CodeMirror]: https://codemirror.net/
[jQuery]: https://jquery.com/
[GMP]: https://gmplib.org/
[libevent2]: http://libevent.org/
[libiconv]: https://www.gnu.org/software/libiconv/
[Libxml2]: http://xmlsoft.org/
[LibYAML]: http://pyyaml.org/wiki/LibYAML
[LLVM]: http://llvm.org/
[Materialize]: http://materializecss.com/
[Octicons]: https://octicons.github.com/
[OpenSSL]: https://www.openssl.org/
[PCRE or PCRE2]: http://pcre.org/
[readline]: https://tiswww.case.edu/php/chet/readline/rltop.html
[Zlib]: http://www.zlib.net/
