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

      needs_loc_pragma = true

      define_main do
        until (token = @lexer.next_token).type.eof?
          case token.type
          when .string?
            if needs_loc_pragma
              append_loc(token.line_number, token.column_number)
              needs_loc_pragma = false
            end

            add_printf_string(token.value)
          when .control?
            pieces = token.value.split(' ', 2)
            if pieces.size != 2
              raise "expected `<%= directive args %>`, not `<%= #{token.value} %>`"
            end

            directive, value = pieces
            case directive
            when "include"
              add_include value
            else
              append_loc(token.line_number, token.column_number)
              add_directive directive, value
            end

            needs_loc_pragma = true
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
