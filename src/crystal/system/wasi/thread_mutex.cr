# TODO: Implement
class Thread
  class Mutex
    def lock
    end

    def try_lock
    end

    def unlock
    end

    def synchronize(&)
      yield
    end
  end
end
