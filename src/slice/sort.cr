struct Slice(T)
  protected def self.intro_sort!(a, n)
    return if n < 2
    quick_sort_for_intro_sort!(a, n, Math.log2(n).to_i * 2)
    insertion_sort!(a, n)
  end

  protected def self.quick_sort_for_intro_sort!(a, n, d)
    while n > 16
      if d == 0
        heap_sort!(a, n)
        return
      end
      d -= 1
      center_median!(a, n)
      c = partition_for_quick_sort!(a, n)
      quick_sort_for_intro_sort!(c, n - (c - a), d)
      n = c - a
    end
  end

  protected def self.heap_sort!(a, n)
    (n // 2).downto 0 do |p|
      heapify!(a, p, n)
    end
    while n > 1
      n -= 1
      a.value, a[n] = a[n], a.value
      heapify!(a, 0, n)
    end
  end

  protected def self.heapify!(a, p, n)
    v, c = a[p], p
    while c < (n - 1) // 2
      c = 2 * (c + 1)
      c -= 1 if cmp(a[c], a[c - 1]) < 0
      break unless cmp(v, a[c]) <= 0
      a[p] = a[c]
      p = c
    end
    if n & 1 == 0 && c == n // 2 - 1
      c = 2 * c + 1
      if cmp(v, a[c]) < 0
        a[p] = a[c]
        p = c
      end
    end
    a[p] = v
  end

  protected def self.center_median!(a, n)
    b, c = a + n // 2, a + n - 1
    if cmp(a.value, b.value) <= 0
      if cmp(b.value, c.value) <= 0
        return
      elsif cmp(a.value, c.value) <= 0
        b.value, c.value = c.value, b.value
      else
        a.value, b.value, c.value = c.value, a.value, b.value
      end
    elsif cmp(a.value, c.value) <= 0
      a.value, b.value = b.value, a.value
    elsif cmp(b.value, c.value) <= 0
      a.value, b.value, c.value = b.value, c.value, a.value
    else
      a.value, c.value = c.value, a.value
    end
  end

  protected def self.partition_for_quick_sort!(a, n)
    v, l, r = a[n // 2], a + 1, a + n - 1
    loop do
      while cmp(l.value, v) < 0
        l += 1
      end
      r -= 1
      while cmp(v, r.value) < 0
        r -= 1
      end
      return l unless l < r
      l.value, r.value = r.value, l.value
      l += 1
    end
  end

  protected def self.insertion_sort!(a, n)
    (1...n).each do |i|
      l = a + i
      v = l.value
      p = l - 1
      while l > a && cmp(v, p.value) < 0
        l.value = p.value
        l, p = p, p - 1
      end
      l.value = v
    end
  end

  protected def self.intro_sort!(a, n, comp)
    return if n < 2
    quick_sort_for_intro_sort!(a, n, Math.log2(n).to_i * 2, comp)
    insertion_sort!(a, n, comp)
  end

  protected def self.quick_sort_for_intro_sort!(a, n, d, comp)
    while n > 16
      if d == 0
        heap_sort!(a, n, comp)
        return
      end
      d -= 1
      center_median!(a, n, comp)
      c = partition_for_quick_sort!(a, n, comp)
      quick_sort_for_intro_sort!(c, n - (c - a), d, comp)
      n = c - a
    end
  end

  protected def self.heap_sort!(a, n, comp)
    (n // 2).downto 0 do |p|
      heapify!(a, p, n, comp)
    end
    while n > 1
      n -= 1
      a.value, a[n] = a[n], a.value
      heapify!(a, 0, n, comp)
    end
  end

  protected def self.heapify!(a, p, n, comp)
    v, c = a[p], p
    while c < (n - 1) // 2
      c = 2 * (c + 1)
      c -= 1 if cmp(a[c], a[c - 1], comp) < 0
      break unless cmp(v, a[c], comp) <= 0
      a[p] = a[c]
      p = c
    end
    if n & 1 == 0 && c == n // 2 - 1
      c = 2 * c + 1
      if cmp(v, a[c], comp) < 0
        a[p] = a[c]
        p = c
      end
    end
    a[p] = v
  end

  protected def self.center_median!(a, n, comp)
    b, c = a + n // 2, a + n - 1
    if cmp(a.value, b.value, comp) <= 0
      if cmp(b.value, c.value, comp) <= 0
        return
      elsif cmp(a.value, c.value, comp) <= 0
        b.value, c.value = c.value, b.value
      else
        a.value, b.value, c.value = c.value, a.value, b.value
      end
    elsif cmp(a.value, c.value, comp) <= 0
      a.value, b.value = b.value, a.value
    elsif cmp(b.value, c.value, comp) <= 0
      a.value, b.value, c.value = b.value, c.value, a.value
    else
      a.value, c.value = c.value, a.value
    end
  end

  protected def self.partition_for_quick_sort!(a, n, comp)
    v, l, r = a[n // 2], a + 1, a + n - 1
    loop do
      while l < a + n && cmp(l.value, v, comp) < 0
        l += 1
      end
      r -= 1
      while r >= a && cmp(v, r.value, comp) < 0
        r -= 1
      end
      return l unless l < r
      l.value, r.value = r.value, l.value
      l += 1
    end
  end

  protected def self.insertion_sort!(a, n, comp)
    (1...n).each do |i|
      l = a + i
      v = l.value
      p = l - 1
      while l > a && cmp(v, p.value, comp) < 0
        l.value = p.value
        l, p = p, p - 1
      end
      l.value = v
    end
  end

  protected def self.cmp(v1, v2)
    v = v1 <=> v2
    raise ArgumentError.new("Comparison of #{v1} and #{v2} failed") if v.nil?
    v
  end

  protected def self.cmp(v1, v2, block)
    v = block.call(v1, v2)
    raise ArgumentError.new("Comparison of #{v1} and #{v2} failed") if v.nil?
    v
  end
end
