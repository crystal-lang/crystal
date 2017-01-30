require "c/iconv"

# :nodoc:
struct Iconv
  @skip_invalid : Bool

  def initialize(from : String, to : String, invalid : Symbol? = nil)
    original_from, original_to = from, to

    @skip_invalid = invalid == :skip
    {% unless flag?(:freebsd) || flag?(:musl) %}
    if @skip_invalid
      from = "#{from}//IGNORE"
      to = "#{to}//IGNORE"
    end
    {% end %}

    @iconv = LibC.iconv_open(to, from)

    if @iconv.address == LibC::SizeT.new(-1)
      if Errno.value == Errno::EINVAL
        if original_from == "UTF-8"
          raise ArgumentError.new("Invalid encoding: #{original_to}")
        elsif original_to == "UTF-8"
          raise ArgumentError.new("Invalid encoding: #{original_from}")
        else
          raise ArgumentError.new("Invalid encoding: #{original_from} -> #{original_to}")
        end
      else
        raise Errno.new("iconv_open")
      end
    end
  end

  def self.new(from : String, to : String, invalid : Symbol? = nil)
    iconv = new(from, to, invalid)
    begin
      yield iconv
    ensure
      iconv.close
    end
  end

  def convert(inbuf : UInt8**, inbytesleft : LibC::SizeT*, outbuf : UInt8**, outbytesleft : LibC::SizeT*)
    {% if flag?(:freebsd) %}
    if @skip_invalid
      return LibC.__iconv(@iconv, inbuf, inbytesleft, outbuf, outbytesleft, LibC::ICONV_F_HIDE_INVALID, out invalids)
    end
    {% end %}
    LibC.iconv(@iconv, inbuf, inbytesleft, outbuf, outbytesleft)
  end

  def handle_invalid(inbuf, inbytesleft)
    if @skip_invalid
      # iconv will leave inbuf right at the beginning of the invalid sequence,
      # so we just skip that byte and later we'll try with the next one
      if inbytesleft.value > 0
        inbuf.value += 1
        inbytesleft.value -= 1
      end
    else
      case Errno.value
      when Errno::EINVAL
        raise ArgumentError.new "Incomplete multibyte sequence"
      when Errno::EILSEQ
        raise ArgumentError.new "Invalid multibyte sequence"
      end
    end
  end

  def close
    if LibC.iconv_close(@iconv) == -1
      raise Errno.new("iconv_close")
    end
  end
end
