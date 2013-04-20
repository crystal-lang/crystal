#output: 78499
max = 1000000

sieve = [] of Bool
sieve.push false
(max - 1).times do
  sieve.push true
end

(2...max).each do |i|
  if sieve[i]
    (2 * i).step(max - 1, i) do |j|
      sieve[j] = false
    end
  end
end

found = sieve.count { |prime| prime }
puts found