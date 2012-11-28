module Enumerable
  def each_with_index
    i = 0
    each do |elem|
      yield elem, i
      i += 1
    end
  end

  def each_with_object(obj)
    each do |elem|
      yield elem, obj
    end
    obj
  end

  def inject(memo)
    each do |elem|
      memo = yield memo, elem
    end
    memo
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

  def count
    count = 0
    each { |e| count += 1 if yield e }
    count
  end
end