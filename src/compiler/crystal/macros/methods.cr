module Crystal
  class ASTNode
    def to_macro_id
      to_s
    end

    def to_macro_var
      self
    end

    def truthy?
      true
    end

    def interpret(method, args, block, interpreter)
      case method
      when "id"
        interpret_argless_method("id", args) { MacroId.new(to_macro_id) }
      when "stringify"
        interpret_argless_method("stringify", args) { stringify }
      when "=="
        BoolLiteral.new(self == args.first)
      when "!="
        BoolLiteral.new(self != args.first)
      when "!"
        BoolLiteral.new(!truthy?)
      else
        raise "undefined macro method #{class_desc}##{method}'"
      end
    end

    def interpret_argless_method(method, args)
      interpret_check_args_length method, args, 0
      yield
    end

    def interpret_one_arg_method(method, args)
      interpret_check_args_length method, args, 1
      yield args.first
    end

    def interpret_check_args_length(method, args, length)
      unless args.length == length
        raise "wrong number of arguments for #{method} (#{args.length} for #{length})"
      end
    end

    def stringify
      StringLiteral.new(to_s)
    end

    def to_macro_id
      to_s
    end
  end

  class Nop
    def truthy?
      false
    end
  end

  class NilLiteral
    def to_macro_id
      "nil"
    end

    def truthy?
      false
    end
  end

  class BoolLiteral
    def to_macro_id
      @value ? "true" : "false"
    end

    def truthy?
      @value
    end
  end

  class NumberLiteral
    def interpret(method, args, block, interpreter)
      case method
      when ">"
        compare_to(args.first) { |me, other| me > other }
      when ">="
        compare_to(args.first) { |me, other| me >= other }
      when "<"
        compare_to(args.first) { |me, other| me < other }
      when "<="
        compare_to(args.first) { |me, other| me <= other }
      when "<=>"
        other = args.first
        unless other.is_a?(NumberLiteral)
          raise "can't compare number to #{other}"
        end
        NumberLiteral.new(to_number <=> other.to_number)
      else
        super
      end
    end

    def compare_to(other)
      unless other.is_a?(NumberLiteral)
        raise "can't compare number to #{other}"
      end

      BoolLiteral.new(yield to_number, other.to_number)
    end

    def to_number
      @value.to_f64
    end
  end

  class StringLiteral
    def interpret(method, args, block, interpreter)
      case method
      when "[]"
        interpret_one_arg_method(method, args) do |arg|
          case arg
          when RangeLiteral
            from, to = arg.from, arg.to
            unless from.is_a?(NumberLiteral)
              raise "range from in StringLiteral#[] must be a number, not #{from.class_desc}: #{from}"
            end

            unless to.is_a?(NumberLiteral)
              raise "range to in StringLiteral#[] must be a number, not #{to.class_desc}: #{from}"
            end

            from, to = from.to_number.to_i, to = to.to_number.to_i
            range = Range.new(from, to, arg.exclusive)
            StringLiteral.new(@value[range])
          else
            raise "wrong argument for StringLiteral#[] (#{arg.class_desc}): #{arg}"
          end
        end
      when "=~"
        interpret_one_arg_method(method, args) do |arg|
          case arg
          when RegexLiteral
            arg_value = arg.value
            if arg_value.is_a?(StringLiteral)
              regex = Regex.new(arg_value.value, arg.modifiers)
            else
              raise "regex interpolations not yet allowed in macros"
            end
            BoolLiteral.new(!!(@value =~ regex))
          else
            BoolLiteral.new(false)
          end
        end
      when "capitalize"
        interpret_argless_method(method, args) { StringLiteral.new(@value.capitalize) }
      when "chars"
        interpret_argless_method(method, args) { ArrayLiteral.map(@value.chars) { |value| CharLiteral.new(value) } }
      when "chomp"
        interpret_argless_method(method, args) { StringLiteral.new(@value.chomp) }
      when "downcase"
        interpret_argless_method(method, args) { StringLiteral.new(@value.downcase) }
      when "empty?"
        interpret_argless_method(method, args) { BoolLiteral.new(@value.empty?) }
      when "ends_with?"
        interpret_one_arg_method(method, args) do |arg|
          case arg
          when CharLiteral
            piece = arg.value
          when StringLiteral
            piece = arg.value
          else
            raise "StringLiteral#ends_with? expects char or string, not #{arg.class_desc}"
          end
          BoolLiteral.new(@value.ends_with?(piece))
        end
      when "identify"
        interpret_argless_method(method, args) { StringLiteral.new(@value.tr(":", "_")) }
      when "length"
        interpret_argless_method(method, args) { NumberLiteral.new(@value.length) }
      when "lines"
        interpret_argless_method(method, args) { ArrayLiteral.map(@value.lines) { |value| StringLiteral.new(value) } }
      when "split"
        case args.length
        when 0
          ArrayLiteral.map(@value.split) { |value| StringLiteral.new(value) }
        when 1
          first_arg = args.first
          case first_arg
          when CharLiteral
            splitter = first_arg.value
          when StringLiteral
            splitter = first_arg.value
          else
            splitter = first_arg.to_s
          end

          ArrayLiteral.map(@value.split(splitter)) { |value| StringLiteral.new(value) }
        else
          raise "wrong number of arguments for split (#{args.length} for 0, 1)"
        end
      when "starts_with?"
        interpret_one_arg_method(method, args) do |arg|
          case arg
          when CharLiteral
            piece = arg.value
          when StringLiteral
            piece = arg.value
          else
            raise "StringLiteral#starts_with? expects char or string, not #{arg.class_desc}"
          end
          BoolLiteral.new(@value.starts_with?(piece))
        end
      when "strip"
        interpret_argless_method(method, args) { StringLiteral.new(@value.strip) }
      when "upcase"
        interpret_argless_method(method, args) { StringLiteral.new(@value.upcase) }
      else
        super
      end
    end

    def to_macro_id
      @value
    end
  end

  class ArrayLiteral
    def interpret(method, args, block, interpreter)
      case method
      when "any?"
        interpret_argless_method(method, args) do
          raise "any? expects a block" unless block

          block_arg = block.args.first?

          BoolLiteral.new(elements.any? do |elem|
            block_value = interpreter.accept elem.to_macro_var
            interpreter.define_var(block_arg.name, block_value) if block_arg
            interpreter.accept(block.body).truthy?
          end)
        end
      when "all?"
        interpret_argless_method(method, args) do
          raise "all? expects a block" unless block

          block_arg = block.args.first?

          BoolLiteral.new(elements.all? do |elem|
            block_value = interpreter.accept elem.to_macro_var
            interpreter.define_var(block_arg.name, block_value) if block_arg
            interpreter.accept(block.body).truthy?
          end)
        end
      when "argify"
        interpret_argless_method(method, args) do
          MacroId.new(elements.join ", ")
        end
      when "empty?"
        interpret_argless_method(method, args) { BoolLiteral.new(elements.empty?) }
      when "find"
        interpret_argless_method(method, args) do
          raise "select expects a block" unless block

          block_arg = block.args.first?

          found = elements.find do |elem|
            block_value = interpreter.accept elem.to_macro_var
            interpreter.define_var(block_arg.name, block_value) if block_arg
            interpreter.accept(block.body).truthy?
          end
          found ? found : NilLiteral.new
        end
      when "first"
        interpret_argless_method(method, args) { elements.first? || NilLiteral.new }
      when "join"
        interpret_one_arg_method(method, args) do |arg|
          StringLiteral.new(elements.map(&.to_macro_id).join arg.to_macro_id)
        end
      when "last"
        interpret_argless_method(method, args) { elements.last? || NilLiteral.new }
      when "length"
        interpret_argless_method(method, args) { NumberLiteral.new(elements.length) }
      when "map"
        interpret_argless_method(method, args) do
          raise "map expects a block" unless block

          block_arg = block.args.first?

          ArrayLiteral.map(elements) do |elem|
            block_value = interpreter.accept elem.to_macro_var
            interpreter.define_var(block_arg.name, block_value) if block_arg
            interpreter.accept block.body
          end
        end
      when "select"
        interpret_argless_method(method, args) do
          raise "select expects a block" unless block

          block_arg = block.args.first?

          ArrayLiteral.new(elements.select do |elem|
            block_arg_value = interpreter.accept elem.to_macro_var
            interpreter.define_var(block_arg.name, block_arg_value) if block_arg
            interpreter.accept(block.body).truthy?
          end)
        end
      when "[]"
        case args.length
        when 1
          arg = args.first
          unless arg.is_a?(NumberLiteral)
            arg.raise "argument to [] must be a number, not #{arg.class_desc}:\n\n#{arg}"
          end

          index = arg.to_number.to_i
          value = elements[index]?
          if value
            value
          else
            NilLiteral.new
          end
        else
          raise "wrong number of arguments for [] (#{args.length} for 1)"
        end
      else
        super
      end
    end
  end

  class HashLiteral
    def interpret(method, args, block, interpreter)
      case method
      when "empty?"
        interpret_argless_method(method, args) { BoolLiteral.new(entries.empty?) }
      when "keys"
        interpret_argless_method(method, args) { ArrayLiteral.map entries, &.key }
      when "length"
        interpret_argless_method(method, args) { NumberLiteral.new(entries.length) }
      when "to_a"
        interpret_argless_method(method, args) do
          ArrayLiteral.map(entries) { |entry| TupleLiteral.new([entry.key, entry.value] of ASTNode) }
        end
      when "values"
        interpret_argless_method(method, args) { ArrayLiteral.map entries, &.value }
      when "[]"
        case args.length
        when 1
          key = args.first
          entry = entries.find &.key.==(key)
          entry.try(&.value) || NilLiteral.new
        else
          raise "wrong number of arguments for [] (#{args.length} for 1)"
        end
      when "[]="
        case args.length
        when 2
          key, value = args

          index = entries.index &.key.==(key)
          if index
            entries[index] = HashLiteral::Entry.new(key, value)
          else
            entries << HashLiteral::Entry.new(key, value)
          end

          value
        else
          raise "wrong number of arguments for []= (#{args.length} for 2)"
        end
      else
        super
      end
    end
  end

  class TupleLiteral
    def interpret(method, args, block, interpreter)
      case method
      when "empty?"
        interpret_argless_method(method, args) { BoolLiteral.new(elements.empty?) }
      when "length"
        interpret_argless_method(method, args) { NumberLiteral.new(elements.length) }
      when "[]"
        case args.length
        when 1
          arg = args.first
          unless arg.is_a?(NumberLiteral)
            arg.raise "argument to [] must be a number, not #{arg.class_desc}:\n\n#{arg}"
          end

          index = arg.to_number.to_i
          value = elements[index]?
          if value
            value
          else
            raise "tuple index out of bounds: #{index} in #{self}"
          end
        else
          raise "wrong number of arguments for [] (#{args.length} for 1)"
        end
      else
        super
      end
    end
  end

  class MetaVar
    def to_macro_id
      @name
    end

    def interpret(method, args, block, interpreter)
      case method
      when "name"
        interpret_argless_method(method, args) { StringLiteral.new(@name) }
      when "type"
        interpret_argless_method(method, args) do
          if type = @type
            TypeNode.new(type)
          else
            NilLiteral.new
          end
        end
      else
        super
      end
    end
  end

  class Block
    def interpret(method, args, block, interpreter)
      case method
      when "body"
        interpret_argless_method(method, args) { @body || Nop.new }
      when "args"
        interpret_argless_method(method, args) do
          ArrayLiteral.map(@args) { |arg| MacroId.new(arg.name) }
        end
      else
        super
      end
    end
  end

  class DeclareVar
    def interpret(method, args, block, interpreter)
      case method
      when "var"
        interpret_argless_method(method, args) do
          var = @var
          var = MacroId.new(var.name) if var.is_a?(Var)
          var
        end
      when "type"
        interpret_argless_method(method, args) { @declared_type }
      else
        super
      end
    end
  end

  class Def
    def interpret(method, args, block, interpreter)
      case method
      when "name"
        MacroId.new(name)
      when "body"
        body
      when "args"
        ArrayLiteral.map(self.args) { |arg| arg }
      when "receiver"
        receiver || Nop.new
      else
        super
      end
    end
  end

  class Arg
    def interpret(method, args, block, interpreter)
      case method
      when "name"
        MacroId.new(name)
      when "default_value"
        default_value || Nop.new
      when "restriction"
        restriction || Nop.new
      else
        super
      end
    end
  end

  class MacroId
    def interpret(method, args, block, interpreter)
      case method
      when "==", "!=", "stringify"
        return super
      end

      value = StringLiteral.new(@value).interpret(method, args, block, interpreter)
      value = MacroId.new(value.value) if value.is_a?(StringLiteral)
      value
    end
  end

  class SymbolLiteral
    def interpret(method, args, block, interpreter)
      case method
      when "==", "!=", "stringify"
        return super
      end

      value = StringLiteral.new(@value).interpret(method, args, block, interpreter)
      value = SymbolLiteral.new(value.value) if value.is_a?(StringLiteral)
      value
    end
  end

  class TypeNode
    def interpret(method, args, block, interpreter)
      case method
      when "abstract?"
        interpret_argless_method(method, args) { BoolLiteral.new(type.abstract) }
      when "name"
        interpret_argless_method(method, args) { StringLiteral.new(type.to_s) }
      when "instance_vars"
        interpret_argless_method(method, args) { TypeNode.instance_vars(type) }
      when "superclass"
        interpret_argless_method(method, args) { TypeNode.superclass(type) }
      when "subclasses"
        interpret_argless_method(method, args) { TypeNode.subclasses(type) }
      when "all_subclasses"
        interpret_argless_method(method, args) { TypeNode.all_subclasses(type) }
      else
        super
      end
    end

    def self.instance_vars(type)
      case type
      when CStructType
        is_struct = true
      when InstanceVarContainer
        is_struct = false
      else
        return ArrayLiteral.new
      end

      all_ivars = type.all_instance_vars
      ivars = Array(ASTNode).new(all_ivars.length)
      all_ivars.each do |name, ivar|
        # An instance var might not have a type, so we skip it
        if ivar_type = ivar.type?
          ivars.push MetaVar.new((is_struct ? name : name[1 .. -1]), ivar_type)
        end
      end

      ArrayLiteral.new(ivars)
    end

    def self.superclass(type)
      superclass = type.superclass
      superclass ? TypeNode.new(superclass) : NilLiteral.new
    rescue
      NilLiteral.new
    end

    def self.subclasses(type)
      ArrayLiteral.map(type.subclasses) { |subtype| TypeNode.new(subtype) }
    end

    def self.all_subclasses(type)
      ArrayLiteral.map(type.all_subclasses) { |subtype| TypeNode.new(subtype) }
    end
  end

  class SymbolLiteral
    def to_macro_id
      @value
    end
  end

  class Var
    def to_macro_id
      @name
    end
  end

  class Call
    def to_macro_id
      if !obj && !block && args.empty?
        @name
      else
        to_s
      end
    end

    def to_macro_var
      MacroId.new(to_macro_id)
    end
  end

  class InstanceVar
    def to_macro_id
      @name
    end
  end

  class Path
    def to_macro_id
      @names.join "::"
    end
  end
end
