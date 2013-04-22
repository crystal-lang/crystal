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

  def map(target : Array(U))
    each { |e| target << yield e }
  end

  def select
    ary = Array(T).new
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
    ary = Array.new
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
end