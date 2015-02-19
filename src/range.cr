struct Range(T)
  include Enumerable

  getter :begin
  getter :end

  def initialize(@begin : T, @end : T, @exclusive : Bool)
  end

  def each
    current = @begin
    while current < @end
      yield current
      current = current.succ
    end
    yield current unless @exclusive
    self
  end

  def step(n = 1)
    current = @begin
    while current < @end
      yield current
      n.times { current = current.succ }
    end
    yield current if current == @end && !@exclusive
    self
  end

  def excludes_end?
    @exclusive
  end

  def includes?(value)
    if @exclusive
      @begin <= value < @end
    else
      @begin <= value <= @end
    end
  end

  def covers?(value)
    includes?(value)
  end

  def ===(value)
    includes?(value)
  end

  def to_s(io : IO)
    io << @begin
    io << (@exclusive ? "..." : "..")
    io << @end
  end

  def inspect(io)
    to_s(io)
  end
end
