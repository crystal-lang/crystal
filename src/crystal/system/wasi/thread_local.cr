class Thread
  struct Local(T)
    @value : T?

    def initialize
      {% raise "T must be a Reference or Pointer" unless T < Reference || T < Pointer %}
    end

    def initialize(&destructor : T ->)
      {% raise "T must be a Reference or Pointer" unless T < Reference || T < Pointer %}
    end

    def get? : T?
      @value
    end

    def set(value : T) : T
      @value = value
    end
  end
end
