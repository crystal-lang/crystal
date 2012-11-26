class Range
  include Enumerable

  def initialize(the_start, the_end, exclusive)
    @begin = the_start
    @end = the_end
    @exclusive = exclusive
  end

  def each
    current = @begin
    while current != @end
      yield current
      current = current.succ
    end
    yield current unless @exclusive
    self
  end

  def step(n)
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
      @begin <= value && value < @end
    else
      @begin <= value && value <= @end
    end
  end

  def to_s
    if @exclusive
      "#{@begin}...#{@end}"
    else
      "#{@begin}..#{@end}"
    end
  end
end