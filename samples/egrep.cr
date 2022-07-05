if ARGV.empty?
  abort "Usage: cat somefile | egrep 'some'"
end

regex = Regex.new(ARGV[0])
while str = STDIN.gets
  STDOUT.print(str) if str =~ regex
end
