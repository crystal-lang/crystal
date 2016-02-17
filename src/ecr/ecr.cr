# Embedded Crystal (ECR) is a template language for embedding Crystal code into other text,
# that includes but is not limited to HTML. The template is read and transformed
# at compile time and then embedded into the binary.
#
# There are `<%= %>` and `<% %>` syntax. The former will render returned values.
# The latter will not, but instead serve to control the structure as we do in normal Crystal.
#
# Quick Example:
#
#     require "ecr/macros"
#
#     class Greeting
#       def initialize(@name)
#       end
#
#       ECR.def_to_s "greeting.ecr"
#     end
#
#     # greeting.ecr
#     Greeting, <%= @name %>!
#
#     Greeting.new("John").to_s
#     #=> Greeting, John!
#
# Using logical statements:
#
#     # greeing.ecr
#     <% if @name %>
#       Greeting, <%= @name %>!
#     <% else %>
#       Greeting!
#     <% end %>
#
#     Greeting.new(nil).to_s
#     #=> Greeting!
#
# Using loops:
#
#     require "ecr/macros"
#
#     class Greeting
#       def initialize(*names)
#        @names = names
#       end
#
#       ECR.def_to_s "greeting.ecr"
#     end
#
#     # greeting.ecr
#     <% @names.each do |name| %>
#       Hi, <%= name %>!
#     <% end %>
#
#     Greeting.new("John", "Zoe", "Ben").to_s
#     #=> Hi, John!
#     #=> Hi, Zoe!
#     #=> Hi, Ben!
#
# Likewise, other Crystal logic can be implemented in ECR text.
module ECR
  extend self

  DefaultBufferName = "__str__"

  # :nodoc:
  def process_file(filename, buffer_name = DefaultBufferName)
    process_string File.read(filename), filename, buffer_name
  end

  # :nodoc:
  def process_string(string, filename, buffer_name = DefaultBufferName)
    lexer = Lexer.new string

    String.build do |str|
      while true
        token = lexer.next_token
        case token.type
        when :STRING
          str << buffer_name
          str << " << "
          token.value.inspect(str)
          str << "\n"
        when :OUTPUT
          str << "("
          append_loc(str, filename, token)
          str << token.value
          str << ").to_s "
          str << buffer_name
          str << "\n"
        when :CONTROL
          append_loc(str, filename, token)
          str << " " unless token.value.starts_with?(' ')
          str << token.value
          str << "\n"
        when :EOF
          break
        end
      end
    end
  end

  private def append_loc(str, filename, token)
    str << %(#<loc:")
    str << filename
    str << %(",)
    str << token.line_number
    str << %(,)
    str << token.column_number
    str << %(>)
  end
end

require "./lexer"
