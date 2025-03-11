def fibonacci(n : Int32) : Int32
  return 0 if n < 0
  return n if n <= 1

  fibonacci(n - 1) + fibonacci(n - 2)
end

puts "First ten Fibonacci numbers:"
(0..9).each do |n|
  puts "fibonacci(#{n}) = #{fibonacci(n)}"
end