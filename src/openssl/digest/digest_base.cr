require "base64"

module OpenSSL
  module DigestBase
    def file(file_name)
      File.open(file_name) do |io|
        self << io
      end
    end

    def update(io : IO)
      buffer = uninitialized UInt8[4096]
      while (read_bytes = io.read(buffer.to_slice)) > 0
        self << buffer.to_slice[0, read_bytes]
      end
      self
    end

    def digest
      self.clone.finish
    end

    def <<(data)
      update(data)
    end

    def base64digest
      Base64.encode(digest)
    end

    def hexdigest
      digest.hexstring
    end

    def to_s(io)
      io << hexdigest
    end
  end
end
