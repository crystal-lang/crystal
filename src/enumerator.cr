class Enumerator(T)
  include Iterator(T)

  struct Yielder(T)
    def initialize
      @channel = Channel(T | Iterator::Stop).new(20)
    end

    def <<(value : T | Iterator::Stop)
      @channel.send value
    end

    def receive
      @channel.receive
    end
  end

  def initialize(&block : Yielder(T) ->)
    @yielder = Yielder(T).new
    spawn do
      block.call @yielder
      @yielder << stop
    end
  end

  def next
    @yielder.receive
  end
end
