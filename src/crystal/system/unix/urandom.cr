# TODO: replace with `flag?(:unix) && !flag?(:openbsd) && !flag?(:linux)` after crystal > 0.22.0 is released
{% skip_file if flag?(:openbsd) && flag?(:linux) %}

module Crystal::System::Random
  @@initialized = false

  private def self.init
    @@initialized = true
    @@urandom = urandom = File.open("/dev/urandom", "r")
    urandom.sync = true # don't buffer bytes
  end

  def self.random_bytes(buf : Bytes) : Nil
    init unless @@initialized

    if urandom = @@urandom
      urandom.read_fully(buf)
    else
      raise "Failed to access secure source to generate random bytes!"
    end
  end

  def self.next_u : UInt8
    init unless @@initialized

    if urandom = @@urandom
      urandom.read_bytes(UInt8)
    else
      raise "Failed to access secure source to generate random bytes!"
    end
  end
end
