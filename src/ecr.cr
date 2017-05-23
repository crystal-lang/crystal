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
# Quick Example:
#
# ```
# require "ecr"
#
# class Greeting
#   def initialize(@name : String)
#   end
#
#   ECR.def_to_s "greeting.ecr"
# end
#
# # greeting.ecr
# Greeting, <%= @name %>!
#
# Greeting.new("John").to_s #=> Greeting, John!
# ```
#
# Using logical statements:
#
# ```
# # greeting.ecr
# <%- if @name -%>
# Greeting, <%= @name %>!
# <%- else -%>
# Greeting!
# <%- end -%>
#
# Greeting.new(nil).to_s #=> Greeting!
# ```
#
# Using loops:
#
# ```
# require "ecr"
#
# class Greeting
#   @names : Array(String)
#
#   def initialize(*names)
#    @names = names.to_a
#   end
#
#   ECR.def_to_s "greeting.ecr"
# end
#
# # greeting.ecr
# <%- @names.each do |name| -%>
# Hi, <%= name %>!
# <%- end -%>
#
# Greeting.new("John", "Zoe", "Ben").to_s
# #=> Hi, John!
# #=> Hi, Zoe!
# #=> Hi, Ben!
# ```
#
# Likewise, other Crystal logic can be implemented in ECR text.
module ECR
end

require "./ecr/macros"
