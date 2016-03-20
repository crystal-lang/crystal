# Copied with little modifications from: https://github.com/wmoxam/Ruby-Benchmarks-Game/blob/master/benchmarks/spectral-norm.rb

def eval_A(i, j)
  return 1.0_f64 / ((i + j) * (i + j + 1.0) / 2.0 + i + 1.0)
end

def eval_A_times_u(u)
  (0...u.size).map do |i|
    v = 0.0_f64
    (0...u.size).each do |j|
      v += eval_A(i, j) * u[j]
    end
    v
  end
end

def eval_At_times_u(u)
  (0...u.size).map do |i|
    v = 0.0_f64
    (0...u.size).each do |j|
      v += eval_A(j, i) * u[j]
    end
    v
  end
end

def eval_AtA_times_u(u)
  eval_At_times_u(eval_A_times_u(u))
end

n = (ARGV[0]? || 1000).to_i
u = Array.new(n, 1.0_f64)
v = Array.new(n, 1.0_f64)
10.times do
  v = eval_AtA_times_u(u)
  u = eval_AtA_times_u(v)
end
vBv = vv = 0.0_f64
(0...n).each do |i|
  vBv += u[i] * v[i]
  vv += v[i] * v[i]
end
puts "#{(Math.sqrt(vBv / vv))}"
