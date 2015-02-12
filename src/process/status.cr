class Process::Status
  property pid
  property exit
  property input
  property output

  def initialize(@pid)
  end

  def success?
    @exit == 0
  end
end

