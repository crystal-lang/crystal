# Embedded Crystal (ECR) is a template language for embedding Crystal code into other text,
# that includes but is not limited to HTML. The template is read and transformed
# at compile time and then embedded into the binary.
#
# There are `<%= %>` and `<% %>` syntax. The former will render returned values.
# The latter will not, but instead serve to control the structure as we do in Crystal.
#
# Using a dash inside `<...>` either eliminates previous indentation or removes the next newline:
#
# * `<%- ... %>`: removes previous indentation
# * `<% ... -%>`: removes next newline
# * `<%-= ... %>`: removes previous indentation
# * `<%= ... -%>`: removes next newline
#
# A comment can be created the same as normal code: `<% # hello %>` or by the special
# tag: `<%# hello %>`. An ECR tag can be inserted directly (i.e. the tag itself may be
# escaped) by using a second `%` like so: `<%% a = b %>` or `<%%= foo %>`.
#
# NOTE: To use `ECR`, you must explicitly import it with `require "ecr"`
#
# Quick Example:
#
# Create a simple ECR file named `greeter.ecr`:
#
# ```
# Greetings, <%= @name %>!
# ```
#
# and then use it like so with the `#def_to_s` macro:
#
# ```
# require "ecr"
#
# class Greeter
#   def initialize(@name : String)
#   end
#
#   ECR.def_to_s "greeter.ecr"
# end
#
# Greeter.new("John").to_s # => "Greetings, John!\n"
# ```
#
# Using logical statements:
#
# ```
# # greeter.ecr
# <%- if @name -%>
# Greetings, <%= @name %>!
# <%- else -%>
# Greetings!
# <%- end -%>
# ```
#
# ```
# require "ecr"
#
# class Greeter
#   def initialize(@name : String | Nil)
#   end
#
#   ECR.def_to_s "greeter.ecr"
# end
#
# Greeter.new(nil).to_s    # => "Greetings!\n"
# Greeter.new("Jill").to_s # => "Greetings, Jill!\n"
# ```
#
# Using loops:
#
# ```
# # greeter.ecr
# <%- @names.each do |name| -%>
# Hi, <%= name %>!
# <%- end -%>
# ```
#
# ```
# require "ecr"
#
# class Greeter
#   @names : Array(String)
#
#   def initialize(*names)
#     @names = names.to_a
#   end
#
#   ECR.def_to_s "greeter.ecr"
# end
#
# Greeter.new("John", "Zoe", "Ben").to_s # => "Hi, John!\nHi, Zoe!\nHi, Ben!\n"
# ```
#
# Comments and Escapes:
#
# ```
# # demo.ecr
# <%# Demonstrate use of ECR tag -%>
# A valid ECR tag looks like this: <%%= foo %>
# ```
#
# ```
# require "ecr"
# foo = 2
# ECR.render("demo.ecr") # => "A valid ECR tag looks like this: <%= foo %>\n"
# ```
#
# Likewise, other Crystal logic can be implemented in ECR text.
module ECR
end

require "./ecr/macros"
