# Last argument is file path to write
test_path = ARGV.pop
File.open(test_path, "w") do |f|
  ARGV.inspect(f)
  f.puts
  {other_flag: {{flag?(:other_flag)}}}.inspect(f)
end
