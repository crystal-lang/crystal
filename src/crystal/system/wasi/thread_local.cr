class Thread
  struct Local(T)
    @value : T?

    def self.new(&destructor : T ->) : self
      new
    end

    def initialize
      {% unless T < Reference || T < Pointer || T.union_types.all? { |t| t == Nil || t < Reference } %}
        {% raise "Can only create Thread::Local with reference types, nilable reference types, or pointer types, not {{T}}" %}
      {% end %}
    end

    def get? : T?
      @value
    end

    def set(value : T) : T
      @value = value
    end
  end
end
