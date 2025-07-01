class Thread
  struct Local(T)
    @value : T?

    def initialize
      previous_def
    end

    def initialize(&destructor : T ->)
      previous_def(&destructor)
    end

    def get? : T?
      @value
    end

    def set(value : T) : T
      @value = value
    end
  end
end
