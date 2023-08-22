struct Slice(T)
  protected def self.intro_sort!(a, n)
    return if n < 2
    quick_sort_for_intro_sort!(a, n, (n.bit_length - 1) * 2)
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
    quick_sort_for_intro_sort!(a, n, (n.bit_length - 1) * 2, comp)
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

  # The stable sort implementation is ported from Rust.
  # https://github.com/rust-lang/rust/blob/507bff92fadf1f25a830da5065a5a87113345163/library/alloc/src/slice.rs
  #
  # Rust License (MIT):
  #
  # Permission is hereby granted, free of charge, to any
  # person obtaining a copy of this software and associated
  # documentation files (the "Software"), to deal in the
  # Software without restriction, including without
  # limitation the rights to use, copy, modify, merge,
  # publish, distribute, sublicense, and/or sell copies of
  # the Software, and to permit persons to whom the Software
  # is furnished to do so, subject to the following
  # conditions:
  #
  # The above copyright notice and this permission notice
  # shall be included in all copies or substantial portions
  # of the Software.
  #
  # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
  # ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
  # TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
  # PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT
  # SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
  # CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
  # OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
  # IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
  # DEALINGS IN THE SOFTWARE.

  # Slices of up to this length get sorted using insertion sort.
  private MAX_INSERTION = 10

  # Very short runs are extended using insertion sort to span at least this many elements.
  private MIN_RUN = 10

  # This merge sort borrows some (but not all) ideas from TimSort, which is described in detail
  # [here](http://svn.python.org/projects/python/trunk/Objects/listsort.txt).
  #
  # The algorithm identifies strictly descending and non-descending subsequences, which are called
  # natural runs. There is a stack of pending runs yet to be merged. Each newly found run is pushed
  # onto the stack, and then some pairs of adjacent runs are merged until these two invariants are
  # satisfied:
  #
  # 1. for every `i` in `1..runs.len()`: `runs[i - 1].len > runs[i].len`
  # 2. for every `i` in `2..runs.len()`: `runs[i - 2].len > runs[i - 1].len + runs[i].len`
  #
  # The invariants ensure that the total running time is `O(n * log(n))` worst-case.
  protected def self.merge_sort!(v : Slice(T)) forall T
    size = v.size

    # Short arrays get sorted in-place via insertion sort to avoid allocations.
    if size <= MAX_INSERTION
      if size >= 2
        (size - 1).downto(0) { |i| insert_head!(v[i..]) }
      end
      return
    end

    # Allocate a buffer to use as scratch memory. We keep the length 0 so we can keep in it
    # shallow copies of the contents of `v` without risking the dtors running on copies if
    # `is_less` panics. When merging two sorted runs, this buffer holds a copy of the shorter run,
    # which will always have length at most `len / 2`.
    buf = Pointer(T).malloc(size // 2)

    # In order to identify natural runs in `v`, we traverse it backwards. That might seem like a
    # strange decision, but consider the fact that merges more often go in the opposite direction
    # (forwards). According to benchmarks, merging forwards is slightly faster than merging
    # backwards. To conclude, identifying runs by traversing backwards improves performance.
    runs = [] of Range(Int32, Int32)
    last = size
    while last > 0
      # Find the next natural run, and reverse it if it's strictly descending.
      start = last - 1
      if start > 0
        start -= 1
        if cmp(v[start + 1], v[start]) < 0
          while start > 0 && cmp(v[start], v[start - 1]) < 0
            start -= 1
          end
          v[start...last].reverse!
        else
          while start > 0 && cmp(v[start], v[start - 1]) > 0
            start -= 1
          end
        end
      end

      # Insert some more elements into the run if it's too short. Insertion sort is faster than
      # merge sort on short sequences, so this significantly improves performance.
      while start > 0 && last - start < MIN_RUN
        start -= 1
        insert_head!(v[start...last])
      end

      # Push this run onto the stack.
      runs.push(start...last)
      last = start

      # Merge some pairs of adjacent runs to satisfy the invariants.
      while r = collapse(runs)
        left = runs[r + 1]
        right = runs[r]
        merge!(v[left.begin...right.end], left.size, buf)
        runs[r] = left.begin...right.end
        runs.delete_at(r + 1)
      end
    end
  end

  # Inserts `v[0]` into pre-sorted sequence `v[1..]` so that whole `v[..]` becomes sorted.
  #
  # This is the integral subroutine of insertion sort.
  protected def self.insert_head!(v)
    if v.size >= 2 && cmp(v[1], v[0]) < 0
      x, v[0] = v[0], v[1]
      (2...v.size).each do |i|
        if cmp(v[i], x) < 0
          v[i - 1] = v[i]
        else
          v[i - 1] = x
          return
        end
      end
      v[v.size - 1] = x
    end
  end

  # Merges non-decreasing runs `v[..mid]` and `v[mid..]` using `buf` as temporary storage, and
  # stores the result into `v[..]`.
  protected def self.merge!(v, mid, buf)
    size = v.size

    if mid <= size - mid
      # The left run is shorter.
      buf.copy_from(v.to_unsafe, mid)

      left = 0
      right = mid
      out = v.to_unsafe

      while left < mid && right < size
        # Consume the lesser side.
        # If equal, prefer the left run to maintain stability.
        if cmp(v[right], buf[left]) < 0
          out.value = v[right]
          out += 1
          right += 1
        else
          out.value = buf[left]
          out += 1
          left += 1
        end
      end

      out.copy_from(buf + left, mid - left)
    else
      # The right run is shorter.
      buf.copy_from((v + mid).to_unsafe, size - mid)

      left = mid
      right = size - mid
      out = v.to_unsafe + size

      while left > 0 && right > 0
        # Consume the greater side.
        # If equal, prefer the right run to maintain stability.
        if cmp(buf[right - 1], v[left - 1]) < 0
          left -= 1
          out -= 1
          out.value = v[left]
        else
          right -= 1
          out -= 1
          out.value = buf[right]
        end
      end

      (v + left).copy_from(buf, right)
    end
  end

  # This merge sort borrows some (but not all) ideas from TimSort, which is described in detail
  # [here](http://svn.python.org/projects/python/trunk/Objects/listsort.txt).
  #
  # The algorithm identifies strictly descending and non-descending subsequences, which are called
  # natural runs. There is a stack of pending runs yet to be merged. Each newly found run is pushed
  # onto the stack, and then some pairs of adjacent runs are merged until these two invariants are
  # satisfied:
  #
  # 1. for every `i` in `1..runs.len()`: `runs[i - 1].len > runs[i].len`
  # 2. for every `i` in `2..runs.len()`: `runs[i - 2].len > runs[i - 1].len + runs[i].len`
  #
  # The invariants ensure that the total running time is `O(n * log(n))` worst-case.
  protected def self.merge_sort!(v : Slice(T), comp) forall T
    size = v.size

    # Short arrays get sorted in-place via insertion sort to avoid allocations.
    if size <= MAX_INSERTION
      if size >= 2
        (size - 1).downto(0) { |i| insert_head!(v[i..], comp) }
      end
      return
    end

    # Allocate a buffer to use as scratch memory. We keep the length 0 so we can keep in it
    # shallow copies of the contents of `v` without risking the dtors running on copies if
    # `is_less` panics. When merging two sorted runs, this buffer holds a copy of the shorter run,
    # which will always have length at most `len / 2`.
    buf = Pointer(T).malloc(size // 2)

    # In order to identify natural runs in `v`, we traverse it backwards. That might seem like a
    # strange decision, but consider the fact that merges more often go in the opposite direction
    # (forwards). According to benchmarks, merging forwards is slightly faster than merging
    # backwards. To conclude, identifying runs by traversing backwards improves performance.
    runs = [] of Range(Int32, Int32)
    last = size
    while last > 0
      # Find the next natural run, and reverse it if it's strictly descending.
      start = last - 1
      if start > 0
        start -= 1
        if cmp(v[start + 1], v[start], comp) < 0
          while start > 0 && cmp(v[start], v[start - 1], comp) < 0
            start -= 1
          end
          v[start...last].reverse!
        else
          while start > 0 && cmp(v[start], v[start - 1], comp) > 0
            start -= 1
          end
        end
      end

      # Insert some more elements into the run if it's too short. Insertion sort is faster than
      # merge sort on short sequences, so this significantly improves performance.
      while start > 0 && last - start < MIN_RUN
        start -= 1
        insert_head!(v[start...last], comp)
      end

      # Push this run onto the stack.
      runs.push(start...last)
      last = start

      # Merge some pairs of adjacent runs to satisfy the invariants.
      while r = collapse(runs)
        left = runs[r + 1]
        right = runs[r]
        merge!(v[left.begin...right.end], left.size, buf, comp)
        runs[r] = left.begin...right.end
        runs.delete_at(r + 1)
      end
    end
  end

  # Inserts `v[0]` into pre-sorted sequence `v[1..]` so that whole `v[..]` becomes sorted.
  #
  # This is the integral subroutine of insertion sort.
  protected def self.insert_head!(v, comp)
    if v.size >= 2 && cmp(v[1], v[0], comp) < 0
      x, v[0] = v[0], v[1]
      (2...v.size).each do |i|
        if cmp(v[i], x, comp) < 0
          v[i - 1] = v[i]
        else
          v[i - 1] = x
          return
        end
      end
      v[v.size - 1] = x
    end
  end

  # Merges non-decreasing runs `v[..mid]` and `v[mid..]` using `buf` as temporary storage, and
  # stores the result into `v[..]`.
  protected def self.merge!(v, mid, buf, comp)
    size = v.size

    if mid <= size - mid
      # The left run is shorter.
      buf.copy_from(v.to_unsafe, mid)

      left = 0
      right = mid
      out = v.to_unsafe

      while left < mid && right < size
        # Consume the lesser side.
        # If equal, prefer the left run to maintain stability.
        if cmp(v[right], buf[left], comp) < 0
          out.value = v[right]
          out += 1
          right += 1
        else
          out.value = buf[left]
          out += 1
          left += 1
        end
      end

      out.copy_from(buf + left, mid - left)
    else
      # The right run is shorter.
      buf.copy_from((v + mid).to_unsafe, size - mid)

      left = mid
      right = size - mid
      out = v.to_unsafe + size

      while left > 0 && right > 0
        # Consume the greater side.
        # If equal, prefer the right run to maintain stability.
        if cmp(buf[right - 1], v[left - 1], comp) < 0
          left -= 1
          out -= 1
          out.value = v[left]
        else
          right -= 1
          out -= 1
          out.value = buf[right]
        end
      end

      (v + left).copy_from(buf, right)
    end
  end

  # Examines the stack of runs and identifies the next pair of runs to merge. More specifically,
  # if `r` is returned, that means `runs[r]` and `runs[r + 1]` must be merged next. If the
  # algorithm should continue building a new run instead, `nil` is returned.
  #
  # TimSort is infamous for its buggy implementations, as described here:
  # http://envisage-project.eu/timsort-specification-and-verification/
  #
  # The gist of the story is: we must enforce the invariants on the top four runs on the stack.
  # Enforcing them on just top three is not sufficient to ensure that the invariants will still
  # hold for *all* runs in the stack.
  #
  # This function correctly checks invariants for the top four runs. Additionally, if the top
  # run starts at index 0, it will always demand a merge operation until the stack is fully
  # collapsed, in order to complete the sort.
  @[AlwaysInline]
  protected def self.collapse(runs)
    n = runs.size
    if n >= 2 &&
       (runs[n - 1].begin == 0 ||
       runs[n - 2].size <= runs[n - 1].size ||
       (n >= 3 && runs[n - 3].size <= runs[n - 2].size + runs[n - 1].size) ||
       (n >= 4 && runs[n - 4].size <= runs[n - 3].size + runs[n - 2].size))
      n >= 3 && runs[n - 3].size < runs[n - 1].size ? n - 3 : n - 2
    end
  end
end
