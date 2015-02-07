struct Process::Status
  property pid
  property exit
  property input
  property output
  property error

  def initialize(@pid)
  end

  def success?
    @exit == 0
  end

  def self.last=(@@last : Status?)
  end

  def self.last?
    @@last
  end

  def self.last
    last?.not_nil!
  end
end

