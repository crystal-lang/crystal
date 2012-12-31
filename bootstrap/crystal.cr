require "crystal/**"

if ARGV.length == 0
  puts "Usage: test2 [file]"
  exit(1)
end

str = File.read ARGV[0]

parser = Crystal::Parser.new(str)
parser.filename = ARGV[0]
nodes = parser.parse
puts nodes
