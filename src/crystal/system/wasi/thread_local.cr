class Thread
  struct Local(T)
    @value : T?

    def initialize
    end

    def initialize(&destructor : T ->)
    end

    def get? : T?
      @value
    end

    def set(value : T) : T
      @value = value
    end
  end
end
