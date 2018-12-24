require "benchmark"

Benchmark.ips do |x|
  x.report("String#to_i32") { "1234567890".to_i32 }
  x.report("String#to_i64") { "1234567890".to_i64 }
end
