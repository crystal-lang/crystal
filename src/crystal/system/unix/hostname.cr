require "c/unistd"

module Crystal::System
  def self.hostname
    String.new(255) do |buffer|
      unless LibC.gethostname(buffer, LibC::SizeT.new(255)) == 0
        raise Errno.new("Could not get hostname")
      end
      len = LibC.strlen(buffer)
      {len, len}
    end
  end
end
