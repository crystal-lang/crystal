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
    @finished = false
    start
  end

  def next
    if @finished
      stop
    else
      value = @yielder.receive
      @finished = true if value.is_a?(Stop)
      value
    end
  end

  def rewind
    @yielder.kill
    @yielder = Yielder(T).new
    @finished = false
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
