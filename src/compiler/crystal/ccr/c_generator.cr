require "./lexer"

module Crystal::CCR
  class CGenerator
    def initialize(@filename : String)
      @lexer = Lexer.new(File.read(@filename))
      @headers = String::Builder.new
      @main = String::Builder.new
    end

    def process
      add_include "<stdio.h>"

      define_main do
        until (token = @lexer.next_token).type.eof?
          append_loc(token.line_number, token.column_number)

          case token.type
          when .string?
            add_printf_string(token.value)
          when .control?
            pieces = token.value.split(' ', 2)
            if pieces.size == 2
              directive, value = pieces
            else
              directive, value = pieces[0], ""
            end
            case directive
            when "include"
              add_include value
            when "ifdef", "ifndef", "if", "elsif"
              add_pragma directive, value
            when "else", "endif"
              add_pragma directive
            else
              add_directive directive, value
            end
          end
        end
      end

      "#{@headers.to_s}\n#{@main.to_s}"
    end

    def define_main
      @main << <<-HEADER
                 #ifndef offsetof
                 #define offsetof(t, f) ((size_t) &((t *)0)->f)
                 #endif

                 #define ccr_sizeof(t...)                  \\
                   printf("%ld", (long) sizeof(t));

                 #define ccr_offsetof(t, f) \
                   printf("%ld", (long) offsetof (t, f));

                 #define ccr_const(x...)                       \\
                   if ((x) < 0)                                \\
                     printf ("%lld", (long long)(x));          \\
                   else                                        \\
                     printf ("%llu", (unsigned long long)(x));

                 #define ccr_type(t...)                                     \\
                   if ((t)(int)(t)1.4 == (t)1.4)                             \\
                       printf ("%s%lu",                                      \\
                               (t)(-1) < (t)0 ? "Int" : "UInt",              \\
                               (unsigned long)sizeof (t) * 8);               \\
                    else                                                     \\
                       printf ("%s",                                         \\
                                sizeof (t) == sizeof (double) ? "Float64"  : \\
                                "Float32");
                 HEADER
      @main << "\n"
      @main << "\n"
      @main << "int main(int argc, char** argv) {\n"
      yield
      @main << "}\n"
    end

    def add_include(header_file)
      @headers << "#include " << header_file << "\n"
    end

    def add_pragma(name, value)
      @main << "#" << name << " " << value << "\n"
    end

    def add_pragma(name)
      @main << "#" << name << "\n"
    end

    def add_directive(directive, value)
      @main << "  ccr_" << directive << "(" << value << ");\n"
    end

    def add_printf_string(string)
      @main << %|  printf("%s", |
      string.inspect(@main)
      @main << ");\n"
    end

    private def append_loc(line_number, column_number)
      add_printf_string("#<loc:#{@filename.inspect},#{line_number},#{column_number}>")
    end
  end
end
