# The status of a terminated process.
class Process::Status
  getter exit_status

  def initialize(@exit_status)
  end

  def exit_code
    @exit_status >> 8
  end

  def success?
    exit_code == 0
  end
end

