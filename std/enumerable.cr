module Enumerable(T)
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

  def inject
    memo :: T
    each_with_index do |elem, i|
      memo = i == 0 ? elem : yield memo, elem
    end
    memo
  end

  def inject(memo)
    each do |elem|
      memo = yield memo, elem
    end
    memo
  end

  def map(&block : T -> U)
    ary = [] of U
    each { |e| ary << yield e }
    ary
  end

  def select
    ary = [] of T
    each { |e| ary << e if yield e }
    ary
  end

  def join(sep = "")
    str = StringBuilder.new
    each_with_index do |elem, i|
      str << sep if i > 0
      str << elem
    end
    str.to_s
  end

  def to_a
    ary = [] of T
    each { |e| ary << e }
    ary
  end

  def count
    count = 0
    each { |e| count += 1 if yield e }
    count
  end

  def count
    count { true }
  end

  def count(item)
    count { |e| e == item }
  end

  def find(if_none = nil)
    each do |elem|
      return elem if yield elem
    end
    if_none
  end

  def any?
    each { |e| return true if yield e }
    false
  end

  def all?
    each { |e| return false unless yield e }
    true
  end

  def includes?(obj)
    any? { |e| e == obj }
  end

  def index(obj)
    index { |e| e == obj }
  end

  def index
    each_with_index do |e, i|
      return i if yield e
    end
    -1
  end

  def grep(pattern)
    select { |elem| pattern === elem }
  end

  def min_by(&block : T -> U)
    min = U::MAX
    obj :: T
    each do |elem|
      value = yield elem
      if value < min
        min = value
        obj = elem
      end
    end
    obj
  end

  def max_by(&block : T -> U)
    min = U::MIN
    obj :: T
    each do |elem|
      value = yield elem
      if value > min
        min = value
        obj = elem
      end
    end
    obj
  end
end