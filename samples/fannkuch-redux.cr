# Copied with little modifications from: http://benchmarksgame.alioth.debian.org/u32/benchmark.php?test=fannkuchredux&lang=yarv&id=2&data=u32

def fannkuch(n)
  sign, maxflips, sum = 1, 0, 0

  w = [0].concat((1..n).to_a)
  q = w.dup
  s = w.dup

  while (true)
    # Copy and flip.
    q1 = w[1] # Cache 1st element.
    if q1 != 1
      q = w.dup
      flips = 1
      while (true)
        qq = q[q1]
        if qq == 1 # ... until 1st element is 1.
          sum = sum + sign * flips
          maxflips = flips if flips > maxflips # New maximum?
          break
        end
        q[q1] = q1
        if q1 >= 4
          i, j = 2, q1 - 1

          while true
            q.swap i, j
            i = i + 1
            j = j - 1
            break if !(i < j)
          end
        end
        q1 = qq
        flips = flips + 1
      end
    end
    # Permute.
    if sign == 1
      # Rotate 1<-2.
      w.swap 1, 2
      sign = -1
    else
      # Rotate 1<-2 and 1<-2<-3.
      w.swap 2, 3

      sign = 1
      3.upto(n) do |ki|
        unless s[ki] == 1
          s[ki] = s[ki] - 1
          break
        end

        return [sum, maxflips] if ki == n # Out of permutations.

        s[ki] = ki
        # Rotate 1<-...<-i+1.
        t = w[1]
        1.upto(ki) do |kj|
          w[kj] = w[kj + 1]
        end
        w[ki + 1] = t
      end
    end
  end
end

n = (ARGV[0]? || 10).to_i
sum, flips = fannkuch(n)
puts "#{sum}\nPfannkuchen(#{n}) = #{flips}"
