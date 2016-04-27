require "c/iconv"

# :nodoc:
struct Iconv
  @skip_invalid : Bool

  def initialize(from : String, to : String, invalid : Symbol? = nil)
    original_from, original_to = from, to

    @skip_invalid = invalid == :skip
    if @skip_invalid
      from = "#{from}//IGNORE"
      to = "#{to}//IGNORE"
    end

    Errno.value = 0
    @iconv = LibC.iconv_open(to, from)
    if Errno.value != 0
      if original_from == "UTF-8"
        raise ArgumentError.new("invalid encoding: #{original_to}")
      elsif original_to == "UTF-8"
        raise ArgumentError.new("invalid encoding: #{original_from}")
      else
        raise ArgumentError.new("invalid encoding: #{original_from} -> #{original_to}")
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
        raise ArgumentError.new "incomplete multibyte sequence"
      when Errno::EILSEQ
        raise ArgumentError.new "invalid multibyte sequence"
      end
    end
  end

  def close
    LibC.iconv_close(@iconv)
  end
end
