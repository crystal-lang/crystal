if ARGV.empty?
  abort "Usage: cat somefile | egrep 'some'"
end

regx = Regex.new(ARGV[0])
while str = STDIN.gets
  STDOUT.print(str) if str =~ regx
end
