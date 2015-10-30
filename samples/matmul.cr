# Copied with little modifications from: https://github.com/attractivechaos/plb/blob/master/matmul/matmul_v1.rb

def matmul(a, b)
  m = a.size
  n = a[0].size
  p = b[0].size
  # transpose
  b2 = Array.new(n) { Array.new(p, 0.0) }
  (0...n).each do |i|
    (0...p).each do |j|
      b2[j][i] = b[i][j]
    end
  end
  # multiplication
  c = Array.new(m) { Array.new(p, 0.0) }
  (0...m).each do |i|
    (0...p).each do |j|
      s = 0.0
      ai, b2j = a[i], b2[j]
      (0...n).each do |k|
        s += ai[k] * b2j[k]
      end
      c[i][j] = s
    end
  end
  c
end

def matgen(n)
  tmp = 1.0 / n / n
  a = Array.new(n) { Array.new(n, 0.0) }
  (0...n).each do |i|
    (0...n).each do |j|
      a[i][j] = tmp * (i - j) * (i + j)
    end
  end
  a
end

n = (ARGV[0]? || 500).to_i
n = n / 2 * 2
a = matgen(n)
b = matgen(n)
c = matmul(a, b)
puts c[n / 2][n / 2]
