if ARGV.empty?
  puts "usage: cat somefile | egrep 'some'"
  exit
end

regx = Regex.new(ARGV[0])
while str = STDIN.gets
  STDOUT.print(str) if str =~ regx
end
