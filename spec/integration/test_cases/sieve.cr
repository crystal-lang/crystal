#output: 78499
max = 1000000

sieve = Array.new max, true
sieve[0] = false

(2...max).each do |i|
  if sieve[i]
    (2 * i).step(max - 1, i) do |j|
      sieve[j] = false
    end
  end
end

found = sieve.count { |prime| prime }
puts found