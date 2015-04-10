struct Range(B, E)
  include Enumerable(B)

  getter :begin
  getter :end

  def initialize(@begin : B, @end : E, @exclusive : Bool)
  end

  def cycle
    each.cycle
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

  def each
    Iterator.new(self)
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

  class Iterator(B, E)
    include ::Iterator(B)

    def initialize(@range : Range(B, E), @current = range.begin, @reached_end = false)
    end

    def next
      return stop if @reached_end

      if @current == @range.end
        @reached_end = true

        if @range.excludes_end?
          return stop
        else
          return @current
        end
      else
        value = @current
        @current = @current.succ
        value
      end
    end

    def rewind
      @current = @range.begin
      @reached_end = false
      self
    end
  end
end
