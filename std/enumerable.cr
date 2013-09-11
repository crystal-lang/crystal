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
    String.build do |str|
      each_with_index do |elem, i|
        str << sep if i > 0
        str << elem
      end
    end
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
    nil
  end

  def grep(pattern)
    select { |elem| pattern === elem }
  end

  def min
    min_by { |x| x }
  end

  def max
    max_by { |x| x }
  end

  def min_by(&block : T -> U)
    min :: U
    obj :: T
    each_with_index do |elem, i|
      value = yield elem
      if i == 0 || value < min
        min = value
        obj = elem
      end
    end
    obj
  end

  def max_by(&block : T -> U)
    min :: U
    obj :: T
    each_with_index do |elem, i|
      value = yield elem
      if i == 0 || value > min
        min = value
        obj = elem
      end
    end
    obj
  end
end
