# cat somefile | egrep 'some'

regx = Regex.new(ARGV[0])
while str = STDIN.gets
  STDOUT.print(str) if str =~ regx
end
