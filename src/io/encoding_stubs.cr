{% unless flag?(:without_iconv) %}
  {% skip_file %}
{% end %}

abstract class IO
  private class Encoder
    def initialize(encoding_options : EncodingOptions)
      raise NotImplementedError.new("IO::Encoder.new")
    end

    def write(io, slice : Bytes)
      raise NotImplementedError.new("IO::Encoder#write")
    end

    def close
      raise NotImplementedError.new("IO::Encoder#close")
    end
  end

  private class Decoder
    def initialize(encoding_options : EncodingOptions)
      raise NotImplementedError.new("IO::Decoder.new")
    end

    def out_slice : Bytes
      raise NotImplementedError.new("IO::Decoder#out_slice")
    end

    def read(io)
      raise NotImplementedError.new("IO::Decoder#read")
    end

    def read_byte(io)
      raise NotImplementedError.new("IO::Decoder#read_byte")
    end

    def read_utf8(io, slice)
      raise NotImplementedError.new("IO::Decoder#read_utf8")
    end

    def gets(io, delimiter : UInt8, limit : Int, chomp)
      raise NotImplementedError.new("IO::Decoder#gets")
    end

    def write(io)
      raise NotImplementedError.new("IO::Decoder#write")
    end

    def write(io, numbytes)
      raise NotImplementedError.new("IO::Decoder#write")
    end

    def close
      raise NotImplementedError.new("IO::Decoder#close")
    end
  end
end
