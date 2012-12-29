require "crystal/**"

if ARGV.length == 0
  puts "Usage: test2 [file]"
  exit(1)
end

str = File.read String.from_cstr(ARGV[0])

lexer = Crystal::Lexer.new(str)
lexer.filename = ARGV[0]
while !lexer.eos?
  token = lexer.next_token
  if token.value.nil?
    puts token.type
  else
    puts "#{token.type} (#{token.value})"
  end
end
