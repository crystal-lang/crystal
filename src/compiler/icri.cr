require "readline"
require "crystal/**"

include Crystal

def count_openings(string)
  openings = 0

  lexer = Lexer.new string
  last_token = nil
  last_is_dot = false
  while (token = lexer.next_token).type != :EOF
    case token.type
    when :SPACE
      next
    when :"."
      last_is_dot = true
    when :IDENT
      unless last_is_dot
        case token.value
        when :begin, :class, :def, :if, :unless, :while, :macro, :case, :lib, :struct, :union, :enum
          openings += 1
        when :do
          openings += 1
        when :end
          openings -= 1
        end
      end
      last_is_dot = false
    else
      last_is_dot = false
    end
    last_token = token.type
  end
  openings
end

def is_evaluatable?(node)
  case node
  when Expressions
    is_evaluatable?(node.last)
  when ClassDef, StructDef, LibDef, Def
    false
  else
    true
  end
end

buffer = StringBuilder.new
openings = 0
incomplete_expression = false
line_number = 1
last_line = line_number
msg = nil
program = Program.new

# HACK
program.infer_type(NilLiteral.new || Nop.new)

interpreter = Interpreter.new(program)

loop do
  line = Readline.readline "icr:#{"%03d" % line_number}:#{openings}#{incomplete_expression ? "*" : ">"} #{"  " * openings }", true
  if line
    stripped_line = line.strip
    if stripped_line.empty?
      incomplete_expression = true
      line_number += 1
    else
      if stripped_line =~ /^(exit|quit)(\s*\(\s*\))?$/
        break
      end

      buffer << line << "\n"
      openings = count_openings buffer.to_s

      if openings == 0
        begin
          value = interpreter.interpret(buffer.to_s)
          puts "=> #{value}"
          incomplete_expression = false
        rescue ex : Crystal::Exception
          msg = ex.message
          if msg && (msg =~ /unexpected\stoken:\sEOF/ || msg =~ /not 'EOF'/)
            incomplete_expression = true
          else
            puts ex
            line_number = last_line - 1
          end
        end

        buffer.clear
      end

      line_number += 1
      last_line = line_number
    end
  else
    # ctrl + d
    puts
    exit
  end
end
