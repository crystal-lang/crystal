module Enumerable(T)
  def first
    each { |e| return e }
    nil
  end

  def first(count : Int)
    take(count)
  end

  def take(count : Int)
    ary = [] of T
    each_with_index do |e, i|
      break if i == count
      ary << e
    end
    ary
  end

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
    found = false

    each_with_index do |elem, i|
      memo = i == 0 ? elem : yield memo, elem
      found = true
    end

    found ? memo : raise EmptyEnumerable.new
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

  def map_with_index(&block : T, Int32 -> U)
    ary = [] of U
    each_with_index { |e, i| ary << yield e, i }
    ary
  end

  def flat_map(&block : T -> Array(U))
    ary = [] of U
    each { |e| ary.concat(yield e) }
    ary
  end

  def compact_map(&block : T -> Nil | U)
    ary = [] of U
    each do |e|
      v = yield e
      ary << v if v
    end
    ary
  end

  def select(&block : T ->)
    ary = [] of T
    each { |e| ary << e if yield e }
    ary
  end

  def reject(&block : T ->)
    ary = [] of T
    each { |e| ary << e unless yield e }
    ary
  end

  def join(separator = "")
    String.build do |io|
      join separator, io
    end
  end

  def join(separator, io)
    join(separator, io) do |elem|
      elem.to_s(io)
    end
  end

  def join(separator, io)
    each_with_index do |elem, i|
      io << separator if i > 0
      yield elem, io
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

  def any?
    any? { |e| e }
  end

  def all?
    each { |e| return false unless yield e }
    true
  end

  def all?
    all? { |o| o }
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

  def minmax
    minmax_by { |x| x }
  end

  def min_by(&block : T -> U)
    min :: U
    obj :: T
    found = false

    each_with_index do |elem, i|
      value = yield elem
      if i == 0 || value < min
        min = value
        obj = elem
      end
      found = true
    end

    found ? obj : raise EmptyEnumerable.new
  end

  def max_by(&block : T -> U)
    min :: U
    obj :: T
    found = false

    each_with_index do |elem, i|
      value = yield elem
      if i == 0 || value > min
        min = value
        obj = elem
      end
      found = true
    end

    found ? obj : raise EmptyEnumerable.new
  end

  def minmax_by(&block : T -> U)
    min :: U
    max :: U
    objmin :: T
    objmax :: T
    found = false

    each_with_index do |elem, i|
      value = yield elem
      if i == 0 || value < min
        min = value
        objmin = elem
      end
      if i == 0 || value > max
        max = value
        objmax = elem
      end
      found = true
    end

    found ? {objmin, objmax} : raise EmptyEnumerable.new
  end

  def partition(&block : T -> U)
    a, b = [] of T, [] of T
    each do |e|
      value = yield(e)
      value ? a.push(e) : b.push(e)
    end
    {a, b}
  end

  def group_by(&block : T -> U)
    h = Hash(U, Array(T)).new
    each do |e|
      v = yield e
      if h.has_key?(v)
        h[v].push(e)
      else
        h[v] = [e]
      end
    end
    h
  end

  def one?(&block : T -> U)
    c = 0
    each do |e|
      c += 1 if yield(e)
      return false if c > 1
    end
    c == 1
  end

  def none?(&block : T -> U)
    each { |e| return false if yield(e) }
    true
  end

  def sum(initial = 0)
    sum(initial) { |e| e }
  end

  def sum(initial = 0)
    inject(initial) { |memo, e| memo + (yield e) }
  end

  def index_by(&block : T -> U)
    hash = {} of U => T
    each do |elem|
      hash[yield elem] = elem
    end
    hash
  end
end
