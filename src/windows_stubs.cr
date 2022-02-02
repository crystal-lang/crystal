require "c/synchapi"

class Mutex
  enum Protection
    Checked
    Reentrant
    Unchecked
  end

  def initialize(@protection : Protection = :checked)
  end

  def lock
  end

  def unlock
  end

  def synchronize
    lock
    begin
      yield
    ensure
      unlock
    end
  end
end

enum Signal
  KILL = 0
end
