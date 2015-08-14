class Process::Status
  def initialize(@exit_status)
  end

  def exit_code
    @exit_status >> 8
  end

  def success?
    exit_code == 0
  end
end

