require "enumerable"

class Range(B, E)
  include Enumerable(B)

  def initialize(the_start : B, the_end : E, exclusive)
    @begin = the_start
    @end = the_end
    @exclusive = exclusive
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

  def begin
    @begin
  end

  def end
    @end
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

  def to_s
    if @exclusive
      "#{@begin}...#{@end}"
    else
      "#{@begin}..#{@end}"
    end
  end
end
