class Enumerator(T)
  include Iterator(T)

  class Yielder(T)
    def initialize
      @channel = Channel(T | Iterator::Stop).new(20)
      @killed = false
    end

    def <<(value : T | Iterator::Stop)
      @channel.send value unless @killed
    end

    def receive
      @channel.receive
    end

    def kill
      @killed = true
    end
  end

  def initialize(&@block : Yielder(T) ->)
    @yielder = Yielder(T).new
    start
  end

  def next
    @yielder.receive
  end

  def rewind
    @yielder.kill
    @yielder = Yielder(T).new
    start
    self
  end

  private def start
    spawn do
      @block.call @yielder
      @yielder << stop
    end
  end
end
