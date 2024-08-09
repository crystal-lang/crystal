# NOTE: this is a struct because it's a mere pointer to a Deque
struct Crystal::Epoll::Timers
  def initialize
    @list = Deque(Epoll::Event*).new
  end

  def empty? : Bool
    @list.empty?
  end

  def next_ready? : Time::Span?
    @list.first?.try(&.value.time)
  end

  def dequeue_ready(&) : Nil
    return if @list.empty?

    now = Time.monotonic
    n = 0

    @list.each do |event|
      break if event.value.time > now
      yield event
      n += 1
    end

    n.times { @list.shift }
  end

  def add(event : Epoll::Event*) : Nil
    if @list.empty?
      @list << event
    elsif index = lookup(event.value.time)
      @list.insert(index, event)
    else
      @list.push(event)
    end
  end

  def delete(event : Epoll::Event*) : Nil
    @list.delete(event)
  end

  private def lookup(time)
    @list.each_with_index do |event, index|
      return index if event.value.time >= time
    end
  end
end
