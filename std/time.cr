require "time.linux" if linux
require "time.darwin" if darwin

class Time
  def to_f
    @seconds
  end

  def to_i
    @seconds.to_i
  end

  def self.now
    new
  end
end
