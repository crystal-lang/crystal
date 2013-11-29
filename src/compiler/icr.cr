require "readline"
require "crystal/**"

include Crystal

def count_openings(string)
  openings = 0

  lexer = Lexer.new string
  last_token = nil
  last_is_dot = false
  while (token = lexer.next_token).type != :EOF
    if token.type != :SPACE
      case token.type
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
total_buffer = StringBuilder.new
openings = 0
incomplete_expression = false
line_number = 1
last_line = line_number
msg = nil

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
        total_buffer << buffer
        begin
          parser = Parser.new total_buffer.to_s
          parser.filename = "-"
          nodes = parser.parse
          if is_evaluatable?(nodes)
            nodes = Expressions.new [Require.new("prelude"), nodes] of ASTNode
            nodes = Call.new(nodes, "inspect")
            program = Program.new
            nodes = program.normalize nodes
            nodes = program.infer_type nodes
            if nodes.type?
              program.load_libs
              llvm_mod = program.build(nodes, true)[""]
              engine = LLVM::JITCompiler.new(llvm_mod)
              argc = LibLLVM.create_generic_value_of_int(LLVM::Int32, 0_u64, 1)
              argv = LibLLVM.create_generic_value_of_pointer(nil)
              result = engine.run_function llvm_mod.functions[Crystal::MAIN_NAME], [argc, argv]
              puts "=> #{result.to_string}"
            else
              puts "=> nil"
            end
          else
            puts "=> nil"
          end
          incomplete_expression = false
        rescue ex : Crystal::Exception
          msg = ex.message
          if msg && (msg =~ /unexpected\stoken:\sEOF/ || msg =~ /not 'EOF'/)
            incomplete_expression = true
          else
            puts ex
            total_buffer = StringBuilder.new total_buffer.to_s[0 .. -(buffer.length + 1)]
            line_number = last_line - 1
          end
        rescue ex : Crystal::Exception
          puts ex.to_s(total_buffer.to_s)
          puts ex.backtrace
          total_buffer = StringBuilder.new total_buffer.to_s[0 .. -(buffer.length + 1)]
          line_number = last_line - 1
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
