require "base64"

module OpenSSL
  module DigestBase
    # Reads the file's content and updates the digest with it.
    def file(file_name : Path | String) : Digest
      File.open(file_name) do |io|
        self << io
      end
    end

    # Reads the io's data and updates the digest with it.
    def update(io : IO) : self
      buffer = uninitialized UInt8[4096]
      while (read_bytes = io.read(buffer.to_slice)) > 0
        self << buffer.to_slice[0, read_bytes]
      end
      self
    end

    # :ditto:
    def <<(data) : self
      update(data)
    end

    # Returns a base64-encoded digest.
    @[Deprecated("Use `Base64.strict_encode(final)` instead.")]
    def base64digest : String
      Base64.strict_encode(digest)
    end

    @[Deprecated("Use `io << final.hexstring` instead.")]
    def to_s(io : IO) : Nil
      io << hexdigest
    end
  end
end
