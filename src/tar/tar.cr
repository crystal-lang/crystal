require "./*"

module Tar
  private ZERO_BLOCK = Bytes.new(512)

  class Error < Exception
  end
end
