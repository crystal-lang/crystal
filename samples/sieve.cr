# Compute prime numbers up to 100 with the Sieve of Eratosthenes
max = 100

sieve = Array.new(max + 1, true)
sieve[0] = false
sieve[1] = false

2.step(to: Math.sqrt(max)) do |i|
  if sieve[i]
    (i * i).step(to: max, by: i) do |j|
      sieve[j] = false
    end
  end
end

sieve.each_with_index do |prime, number|
  if prime
    puts number
  end
end
