require "../syntax/ast"
require "set"
require "colorize"

module Crystal
  def print_hierarchy(program)
    HierarchyPrinter.new(program).execute
  end

  class HierarchyPrinter
    def initialize(@program)
      @indents = [] of Bool
      @printed = Set(Type).new
      @llvm_typer = LLVMTyper.new(@program)
    end

    def execute
      with_color.light_gray.bold.push(STDOUT) do
        print_types @program.types
      end
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
      if (type.is_a?(NonGenericClassType) || type.is_a?(GenericClassInstanceType)) &&
         !type.is_a?(PointerInstanceType) && !type.is_a?(FunInstanceType)
        size = @llvm_typer.size_of(@llvm_typer.llvm_struct_type(type))
        with_color.light_gray.push(STDOUT) do
          print " ("
          print size.to_s
          print " bytes)"
        end
      end
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
        with_color.light_gray.push(STDOUT) do
          print ivar.name
          print " : "
          print ivar.type
          size = @llvm_typer.size_of(@llvm_typer.llvm_embedded_type(ivar.type))
          print " ("
          print size
          print " bytes)"
        end
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
