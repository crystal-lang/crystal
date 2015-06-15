# Fresh variables

Once macros generate code, they are parsed with a regular Crystal parser where local variables in the context of the macro invocations are assumed to be defined.

This is better understood with an example:

```ruby
macro update_x
  x = 1
end

x = 0
update_x
x #=> 1
```

This can sometimes be useful to avoid repetitive code by actually accessing and reading/writing local variables, but can also overwrite local variables by mistake. You can use fresh variables with `%name`:

```ruby
macro dont_update_x
  %x = 1
  puts %x
end

x = 0
dont_update_x # outputs 1
x #=> 0
```

Using `%x` in the above example we declare a variable whose name is guaranteed not to conflict with local varaibles in the current scope.

Additionally, you can declare fresh variables related to some other AST node using `%var{key1, key2, ..., keyN}`. For example:

```ruby
macro fresh_vars_sample(*names)
  # First declare vars
  {% for name, index in names %}
    print "Declaring: ", "%name{index}", '\n'
    %name{index} = {{index}}
  {% end %}

  # Then print them
  {% for name, index in names %}
    print "%name{index}: ", %name{index}, '\n'
  {% end %}
end

fresh_vars_sample a, b, c

# Sample output:
# Declaring: __temp_255
# Declaring: __temp_256
# Declaring: __temp_257
# __temp_255: 0
# __temp_256: 1
# __temp_257: 2
```

In the above example three variables were declared, associated to an index, and then they were printed, referring to these variables with the same indices.
