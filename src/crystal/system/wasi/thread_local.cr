class Thread
  struct Local(T)
    @value : T?

    def get? : T?
      @value
    end

    def set(value : T) : T
      @value = value
    end
  end
end
