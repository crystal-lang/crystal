require "ast"
require "set"

module Crystal
  def print_hierarchy(program)
    HierarchyPrinter.new(program).execute
  end

  class HierarchyPrinter
    def initialize(@program)
      @indents = [] of Bool
      @printed = Set(Type).new
    end

    def execute
      print "\e[1;37m"
      print_types @program.types
      print "\e[0m"
    end

    def print_types(types_hash)
      types_hash.each_value do |type|
        print_subtype type
      end
    end

    def print_subtypes(types)
      while types.length > 0
        type = types.pop

        if types.empty?
          @indents[@indents.length - 1] = false
        end

        print_subtype type

        types = types.select { |t| must_print?(t) }
      end
    end

    def print_subtype(type)
      return unless must_print? type

      @printed.add type

      unless @indents.empty?
        print_indent
        print "|"
        puts
      end

      print_type type
    end

    def print_type_name(type)
      print_indent
      print "+" unless @indents.empty?
      print "- "
      print type.type_desc
      print " "
      print type
      puts
    end

    def print_type(type : NonGenericClassType | GenericClassInstanceType)
      print_type_name type

      subtypes = type.subclasses.select { |sub| must_print?(sub) }
      print_instance_vars type, !subtypes.empty?

      with_indent do
        print_subtypes subtypes.select { |t| !t.is_a?(GenericClassInstanceType) }
      end

      if type.is_a?(NonGenericClassType)
        print_types type.types
      end
    end

    def print_type(type : GenericClassType)
      print_type_name type

      with_indent do
        print_subtypes type.generic_types.values.select { |sub| must_print?(sub) }
      end
      print_types type.types
    end

    def print_type(type)
      # Nothing to do
    end

    def print_instance_vars(type, has_subtypes)
      type.instance_vars.each_value do |ivar|
        print_indent
        print (@indents.last ? "|" : " ")
        if has_subtypes
          print "  .   "
        else
          print "      "
        end
        print "\e[0;37m"
        print ivar.name
        print " : "
        print ivar.type
        print "\e[1;37m"
        puts
      end
    end

    def must_print?(type : NonGenericClassType | GenericClassInstanceType)
      type.allocated && !@printed.includes?(type)
    end

    def must_print?(type : GenericClassType)
      !type.generic_types.empty? && !@printed.includes?(type)
    end

    def must_print?(type)
      false
    end

    def print_indent
      unless @indents.empty?
        print "  "
        0.upto(@indents.length - 2) do |i|
          indent = @indents[i]
          if indent
            print "|  "
          else
            print "   "
          end
        end
      end
    end

    def with_indent
      @indents.push true
      yield
      @indents.pop
    end
  end
end
