module Enumerable
  def each_with_index
    i = 0
    each do |elem|
      yield elem, i
      i += 1
    end
  end

  def map
    ary = []
    each { |e| ary << yield e }
    ary
  end

  def select
    ary = []
    each { |e| ary << e if yield e }
    ary
  end

  def to_a
    ary = []
    each { |e| ary << e }
    ary
  end
end