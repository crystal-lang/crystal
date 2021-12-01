require "c/stddef"

{% if flag?(:without_iconv) %}
  {% raise "The `without_iconv` flag is preventing you to use the LibIconv module" %}
{% end %}

@[Link("iconv")]
lib LibIconv
  type IconvT = Void*

  alias Int = LibC::Int
  alias Char = LibC::Char
  alias SizeT = LibC::SizeT

  fun iconv = libiconv(cd : IconvT, inbuf : Char**, inbytesleft : SizeT*, outbuf : Char**, outbytesleft : SizeT*) : SizeT
  fun iconv_close = libiconv_close(cd : IconvT) : Int
  fun iconv_open = libiconv_open(tocode : Char*, fromcode : Char*) : IconvT
end
