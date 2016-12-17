module ECR
  # Defines a `to_s(io)` method whose body is the ECR contained
  # in *filename*, translated to Crystal code.
  #
  # ```text
  # # greeting.ecr
  # Hello <%= @name %>!
  # ```
  #
  # ```
  # require "ecr/macros"
  #
  # class Greeting
  #   def initialize(@name : String)
  #   end
  #
  #   ECR.def_to_s "greeting.ecr"
  # end
  #
  # Greeting.new("World").to_s # => "Hello World!"
  # ```
  #
  # The macro basically translates the text inside the given file
  # to Crystal code that appends to the IO:
  #
  # ```
  # class Greeting
  #   def to_s(io)
  #     io << "Hello "
  #     io << @name
  #     io << "!"
  #   end
  # end
  # ```
  macro def_to_s(filename)
    def to_s(__io__)
      ECR.embed {{filename}}, "__io__"
    end
  end

  # Embeds an ECR file contained in *filename* into the program.
  #
  # The generated code is the result of translating the contents of
  # the ECR file to Crystal, a program that appends to the IO
  # with the given *io_name*.
  #
  # ```text
  # # greeting.ecr
  # Hello <%= name %>!
  # ```
  #
  # ```
  # require "ecr/macros"
  #
  # name = "World"
  #
  # io = IO::Memory.new
  # ECR.embed "greeting.ecr", io
  # io.to_s # => "Hello World!"
  # ```
  #
  # The `ECR.embed` line basically generates this:
  #
  # ```
  # io << "Hello "
  # io << name
  # io << "!"
  # ```
  macro embed(filename, io_name)
    \{{ run("ecr/process", {{filename}}, {{io_name.id.stringify}}) }}
  end
end
