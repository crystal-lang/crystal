require "../semantic/ast"
require "./macros"
require "semantic_version"

module Crystal
  class MacroInterpreter
    def interpret_top_level_call(node)
      interpret_top_level_call?(node) ||
        node.raise("undefined macro method: '#{node.name}'")
    end

    def interpret_top_level_call?(node)
      # Please order method names in lexicographical order, because OCD
      case node.name
      when "compare_versions"
        interpret_compare_versions(node)
      when "debug"
        interpret_debug(node)
      when "env"
        interpret_env(node)
      when "flag?"
        interpret_flag?(node)
      when "puts", "p"
        interpret_puts(node)
      when "pp"
        interpret_pp(node)
      when "skip_file"
        interpret_skip_file(node)
      when "system", "`"
        interpret_system(node)
      when "raise"
        interpret_raise(node)
      when "run"
        interpret_run(node)
      else
        nil
      end
    end

    def interpret_compare_versions(node)
      unless node.args.size == 2
        node.wrong_number_of_arguments "macro call 'compare_versions'", node.args.size, 2
      end

      first_arg = node.args[0]
      first = accept first_arg
      first_string = first.to_string("first argument to 'compare_versions'")

      second_arg = node.args[1]
      second = accept second_arg
      second_string = second.to_string("second argument to 'compare_versions'")

      first_version = begin
        SemanticVersion.parse(first_string)
      rescue ex
        first_arg.raise ex.message
      end

      second_version = begin
        SemanticVersion.parse(second_string)
      rescue ex
        second_arg.raise ex.message
      end

      @last = NumberLiteral.new(first_version <=> second_version)
    end

    def interpret_debug(node)
      if node.args.size >= 1
        node.args.first.accept self
        format = @last.truthy?
      elsif named_args = node.named_args
        format_arg = named_args.find { |arg| arg.name == "format" }
        if format_arg
          format_arg.value.accept self
          format = @last.truthy?
        end
      else
        format = true
      end

      if format
        begin
          @program.stdout.puts Crystal::Formatter.format(@str.to_s)
        rescue
          @program.stdout.puts @str
        end
      else
        @program.stdout.puts @str
      end

      @last = Nop.new
    end

    def interpret_env(node)
      if node.args.size == 1
        node.args[0].accept self
        cmd = @last.to_macro_id
        env_value = ENV[cmd]?
        @last = env_value ? StringLiteral.new(env_value) : NilLiteral.new
      else
        node.wrong_number_of_arguments "macro call 'env'", node.args.size, 1
      end
    end

    def interpret_flag?(node)
      if node.args.size == 1
        node.args[0].accept self
        flag = @last.to_macro_id
        @last = BoolLiteral.new(@program.has_flag?(flag))
      else
        node.wrong_number_of_arguments "macro call 'flag?'", node.args.size, 1
      end
    end

    def interpret_puts(node)
      node.args.each do |arg|
        arg.accept self
        @program.stdout.puts @last
      end

      @last = Nop.new
    end

    def interpret_pp(node)
      strings = [] of {String, String}

      node.args.each do |arg|
        arg.accept self
        strings.push({arg.to_s, @last.to_s})
      end

      max_size = strings.max_of &.[0].size
      strings.each do |left, right|
        @program.stdout.puts "#{left.ljust(max_size)} # => #{right}"
      end

      @last = Nop.new
    end

    def interpret_skip_file(node)
      raise SkipMacroException.new(@str.to_s)
    end

    def interpret_system(node)
      cmd = node.args.map do |arg|
        arg.accept self
        @last.to_macro_id
      end
      cmd = cmd.join " "

      result = `#{cmd}`
      if $?.success?
        @last = MacroId.new(result)
      elsif result.empty?
        node.raise "error executing command: #{cmd}, got exit status #{$?.exit_code}"
      else
        node.raise "error executing command: #{cmd}, got exit status #{$?.exit_code}:\n\n#{result}\n"
      end
    end

    def interpret_raise(node)
      msg = node.args.map do |arg|
        arg.accept self
        @last.to_macro_id
      end
      msg = msg.join " "

      node.raise msg, exception_type: MacroRaiseException
    end

    def interpret_run(node)
      if node.args.size == 0
        node.wrong_number_of_arguments "macro call 'run'", 0, "1+"
      end

      node.args.first.accept self
      filename = @last.to_macro_id
      original_filename = filename

      # Support absolute paths
      if filename.starts_with?("/")
        filename = "#{filename}.cr" unless filename.ends_with?(".cr")

        if File.exists?(filename)
          unless File.file?(filename)
            node.raise "error executing macro run: '#{filename}' is not a file"
          end
        else
          node.raise "error executing macro run: can't find file '#{filename}'"
        end
      else
        begin
          relative_to = @location.try &.original_filename
          found_filenames = @program.find_in_path(filename, relative_to)
        rescue ex
          node.raise "error executing macro run: #{ex.message}"
        end

        unless found_filenames
          node.raise "error executing macro run: can't find file '#{filename}'"
        end

        if found_filenames.size > 1
          node.raise "error executing macro run: '#{filename}' is a directory"
        end

        filename = found_filenames.first
      end

      run_args = [] of String
      node.args.each_with_index do |arg, i|
        next if i == 0

        arg.accept self
        run_args << @last.to_macro_id
      end

      result = @program.macro_run(filename, run_args)
      if result.status.success?
        @last = MacroId.new(result.stdout)
      else
        command = "#{original_filename} #{run_args.map(&.inspect).join " "}"

        message = IO::Memory.new
        message << "Error executing run (exit code: #{result.status.exit_code}): #{command}\n"

        if result.stdout.empty? && result.stderr.empty?
          message << "\nGot no output."
        else
          Colorize.reset(message)

          unless result.stdout.empty?
            message.puts
            message << "stdout:".colorize.mode(:bold)
            message.puts
            message.puts
            result.stdout.each_line do |line|
              message << "    "
              message << line
              message << '\n'
            end
            message << '\n'
          end

          unless result.stderr.empty?
            message.puts
            message << "stderr:".colorize.mode(:bold)
            message.puts
            message.puts
            result.stderr.each_line do |line|
              message << "    "
              message << line
              message << '\n'
            end
            message << '\n'
          end
        end

        node.raise message.to_s
      end
    end
  end

  class ASTNode
    def to_macro_id
      to_s
    end

    def to_string(context)
      case self
      when StringLiteral then return self.value
      when SymbolLiteral then return self.value
      when MacroId       then return self.value
      else
        raise "expected #{context} to be a StringLiteral, SymbolLiteral or MacroId, not #{class_desc}"
      end
    end

    def truthy?
      case self
      when NilLiteral, Nop
        false
      when BoolLiteral
        self.value
      else
        true
      end
    end

    def interpret(method, args, block, interpreter)
      case method
      when "id"
        interpret_argless_method("id", args) { MacroId.new(to_macro_id) }
      when "stringify"
        interpret_argless_method("stringify", args) { stringify }
      when "symbolize"
        interpret_argless_method("symbolize", args) { symbolize }
      when "class_name"
        interpret_argless_method("class_name", args) { class_name }
      when "raise"
        interpret_one_arg_method(method, args) do |arg|
          raise arg.to_s
        end
      when "filename"
        interpret_argless_method("filename", args) do
          filename = location.try &.original_filename
          filename ? StringLiteral.new(filename) : NilLiteral.new
        end
      when "line_number"
        interpret_argless_method("line_number", args) do
          line_number = location.try &.original_location.try &.line_number
          line_number ? NumberLiteral.new(line_number) : NilLiteral.new
        end
      when "column_number"
        interpret_argless_method("column_number", args) do
          column_number = location.try &.original_location.try &.column_number
          column_number ? NumberLiteral.new(column_number) : NilLiteral.new
        end
      when "end_line_number"
        interpret_argless_method("end_line_number", args) do
          line_number = end_location.try &.original_location.try &.line_number
          line_number ? NumberLiteral.new(line_number) : NilLiteral.new
        end
      when "end_column_number"
        interpret_argless_method("end_column_number", args) do
          column_number = end_location.try &.original_location.try &.column_number
          column_number ? NumberLiteral.new(column_number) : NilLiteral.new
        end
      when "=="
        interpret_one_arg_method(method, args) do |arg|
          BoolLiteral.new(self == arg)
        end
      when "!="
        interpret_one_arg_method(method, args) do |arg|
          BoolLiteral.new(self != arg)
        end
      when "!"
        BoolLiteral.new(!truthy?)
      else
        raise "undefined macro method '#{class_desc}##{method}'", exception_type: Crystal::UndefinedMacroMethodError
      end
    end

    def interpret_argless_method(method, args)
      interpret_check_args_size method, args, 0
      yield
    end

    def interpret_one_arg_method(method, args)
      interpret_check_args_size method, args, 1
      yield args.first
    end

    def interpret_two_args_method(method, args)
      interpret_check_args_size method, args, 2
      yield args[0], args[1]
    end

    def interpret_check_args_size(method, args, size)
      unless args.size == size
        wrong_number_of_arguments method, args.size, size
      end
    end

    def interpret_compare(other)
      raise "can't compare #{self} to #{other}"
    end

    def stringify
      StringLiteral.new(to_s)
    end

    def symbolize
      SymbolLiteral.new(to_s)
    end

    def class_name
      StringLiteral.new(class_desc)
    end
  end

  class NilLiteral
    def to_macro_id
      "nil"
    end
  end

  class BoolLiteral
    def to_macro_id
      @value ? "true" : "false"
    end
  end

  class NumberLiteral
    def interpret(method, args, block, interpreter)
      case method
      when ">"
        bool_bin_op(method, args) { |me, other| me > other }
      when ">="
        bool_bin_op(method, args) { |me, other| me >= other }
      when "<"
        bool_bin_op(method, args) { |me, other| me < other }
      when "<="
        bool_bin_op(method, args) { |me, other| me <= other }
      when "<=>"
        num_bin_op(method, args) { |me, other| me <=> other }
      when "+"
        if args.empty?
          self
        else
          num_bin_op(method, args) { |me, other| me + other }
        end
      when "-"
        if args.empty?
          num = to_number
          if num.is_a?(Int::Unsigned)
            raise "undefined method '-' for unsigned integer literal: #{self}"
          else
            NumberLiteral.new(-num)
          end
        else
          num_bin_op(method, args) { |me, other| me - other }
        end
      when "*"
        num_bin_op(method, args) { |me, other| me * other }
      when "/"
        num_bin_op(method, args) { |me, other| me / other }
      when "**"
        num_bin_op(method, args) { |me, other| me ** other }
      when "%"
        int_bin_op(method, args) { |me, other| me % other }
      when "&"
        int_bin_op(method, args) { |me, other| me & other }
      when "|"
        int_bin_op(method, args) { |me, other| me | other }
      when "^"
        int_bin_op(method, args) { |me, other| me ^ other }
      when "<<"
        int_bin_op(method, args) { |me, other| me << other }
      when ">>"
        int_bin_op(method, args) { |me, other| me >> other }
      when "~"
        if args.empty?
          num = to_number
          if num.is_a?(Int)
            NumberLiteral.new(~num)
          else
            raise "undefined method '~' for float literal: #{self}"
          end
        else
          wrong_number_of_arguments "NumberLiteral#~", args.size, 0
        end
      when "kind"
        SymbolLiteral.new(kind.to_s)
      else
        super
      end
    end

    def interpret_compare(other : NumberLiteral)
      to_number <=> other.to_number
    end

    def bool_bin_op(op, args)
      BoolLiteral.new(bin_op(op, args) { |me, other| yield me, other })
    end

    def num_bin_op(op, args)
      NumberLiteral.new(bin_op(op, args) { |me, other| yield me, other })
    end

    def int_bin_op(op, args)
      if @kind == :f32 || @kind == :f64
        raise "undefined method '#{op}' for float literal: #{self}"
      end

      NumberLiteral.new(bin_op(op, args) do |me, other|
        other_kind = args.first.as(NumberLiteral).kind
        if other_kind == :f32 || other_kind == :f64
          raise "argument to NumberLiteral##{op} can't be float literal: #{self}"
        end

        yield me.to_i, other.to_i
      end)
    end

    def bin_op(op, args)
      if args.size != 1
        wrong_number_of_arguments "NumberLiteral##{op}", args.size, 1
      end

      other = args.first
      unless other.is_a?(NumberLiteral)
        raise "can't #{op} with #{other}"
      end

      yield(to_number, other.to_number)
    end

    def to_number
      case @kind
      when :i8  then @value.to_i8
      when :i16 then @value.to_i16
      when :i32 then @value.to_i32
      when :i64 then @value.to_i64
      when :u8  then @value.to_u8
      when :u16 then @value.to_u16
      when :u32 then @value.to_u32
      when :u64 then @value.to_u64
      when :f32 then @value.to_f32
      when :f64 then @value.to_f64
      else
        raise "Unknown kind: #{@kind}"
      end
    end
  end

  class CharLiteral
    def to_macro_id
      @value.to_s
    end
  end

  class StringLiteral
    def interpret(method, args, block, interpreter)
      case method
      when "==", "!="
        case arg = args.first?
        when MacroId
          if method == "=="
            return BoolLiteral.new(@value == arg.value)
          else
            return BoolLiteral.new(@value != arg.value)
          end
        else
          return super
        end
      when "[]"
        interpret_one_arg_method(method, args) do |arg|
          case arg
          when RangeLiteral
            from, to = arg.from, arg.to
            from = interpreter.accept(from)
            to = interpreter.accept(to)

            unless from.is_a?(NumberLiteral)
              raise "range from in StringLiteral#[] must be a number, not #{from.class_desc}: #{from}"
            end

            unless to.is_a?(NumberLiteral)
              raise "range to in StringLiteral#[] must be a number, not #{to.class_desc}: #{from}"
            end

            from, to = from.to_number.to_i, to = to.to_number.to_i
            range = Range.new(from, to, arg.exclusive?)
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
              regex = Regex.new(arg_value.value, arg.options)
            else
              raise "regex interpolations not yet allowed in macros"
            end
            BoolLiteral.new(!!(@value =~ regex))
          else
            BoolLiteral.new(false)
          end
        end
      when ">"
        interpret_one_arg_method(method, args) do |arg|
          case arg
          when StringLiteral, MacroId
            return BoolLiteral.new(interpret_compare(arg) > 0)
          else
            raise "Can't compare StringLiteral with #{arg.class_desc}"
          end
        end
      when "<"
        interpret_one_arg_method(method, args) do |arg|
          case arg
          when StringLiteral, MacroId
            return BoolLiteral.new(interpret_compare(arg) < 0)
          else
            raise "Can't compare StringLiteral with #{arg.class_desc}"
          end
        end
      when "+"
        interpret_one_arg_method(method, args) do |arg|
          case arg
          when CharLiteral
            piece = arg.value
          when StringLiteral
            piece = arg.value
          else
            raise "StringLiteral#+ expects char or string, not #{arg.class_desc}"
          end
          StringLiteral.new(@value + piece)
        end
      when "camelcase"
        interpret_argless_method(method, args) { StringLiteral.new(@value.camelcase) }
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
      when "gsub"
        interpret_two_args_method(method, args) do |first, second|
          raise "first arguent to StringLiteral#gsub must be a regex, not #{first.class_desc}" unless first.is_a?(RegexLiteral)
          raise "second arguent to StringLiteral#gsub must be a string, not #{second.class_desc}" unless second.is_a?(StringLiteral)

          regex_value = first.value
          if regex_value.is_a?(StringLiteral)
            regex = Regex.new(regex_value.value, first.options)
          else
            raise "regex interpolations not yet allowed in macros"
          end

          StringLiteral.new(value.gsub(regex, second.value))
        end
      when "identify"
        interpret_argless_method(method, args) { StringLiteral.new(@value.tr(":", "_")) }
      when "includes?"
        interpret_one_arg_method(method, args) do |arg|
          case arg
          when CharLiteral
            piece = arg.value
          when StringLiteral
            piece = arg.value
          else
            raise "StringLiteral#includes? expects char or string, not #{arg.class_desc}"
          end
          BoolLiteral.new(@value.includes?(piece))
        end
      when "size"
        interpret_argless_method(method, args) { NumberLiteral.new(@value.size) }
      when "lines"
        interpret_argless_method(method, args) { ArrayLiteral.map(@value.lines) { |value| StringLiteral.new(value) } }
      when "split"
        case args.size
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
          wrong_number_of_arguments "StringLiteral#split", args.size, "0..1"
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
      when "to_i"
        case args.size
        when 0
          value = @value.to_i64?
        when 1
          arg = args.first
          raise "argument to StringLiteral#to_i must be a number, not #{arg.class_desc}" unless arg.is_a?(NumberLiteral)

          value = @value.to_i64?(arg.to_number.to_i)
        else
          wrong_number_of_arguments "StringLiteral#to_i", args.size, "0..1"
        end

        if value
          NumberLiteral.new(value)
        else
          raise "StringLiteral#to_i: #{@value} is not an integer"
        end
      when "tr"
        interpret_two_args_method(method, args) do |first, second|
          raise "first arguent to StringLiteral#tr must be a string, not #{first.class_desc}" unless first.is_a?(StringLiteral)
          raise "second arguent to StringLiteral#tr must be a string, not #{second.class_desc}" unless second.is_a?(StringLiteral)
          StringLiteral.new(@value.tr(first.value, second.value))
        end
      when "underscore"
        interpret_argless_method(method, args) { StringLiteral.new(@value.underscore) }
      when "upcase"
        interpret_argless_method(method, args) { StringLiteral.new(@value.upcase) }
      else
        super
      end
    end

    def interpret_compare(other : StringLiteral | MacroId)
      value <=> other.value
    end

    def to_macro_id
      @value
    end
  end

  class StringInterpolation
    def interpret(method, args, block, interpreter)
      case method
      when "expressions"
        interpret_argless_method(method, args) { ArrayLiteral.new(expressions) }
      else
        super
      end
    end
  end

  class ArrayLiteral
    def interpret(method, args, block, interpreter)
      case method
      when "of"
        interpret_argless_method(method, args) { @of || Nop.new }
      when "type"
        interpret_argless_method(method, args) { @name || Nop.new }
      else
        value = intepret_array_or_tuple_method(self, ArrayLiteral, method, args, block, interpreter)
        value || super
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
      when "size"
        interpret_argless_method(method, args) { NumberLiteral.new(entries.size) }
      when "to_a"
        interpret_argless_method(method, args) do
          ArrayLiteral.map(entries) { |entry| TupleLiteral.new([entry.key, entry.value] of ASTNode) }
        end
      when "values"
        interpret_argless_method(method, args) { ArrayLiteral.map entries, &.value }
      when "map"
        interpret_argless_method(method, args) do
          raise "map expects a block" unless block

          block_arg_key = block.args[0]?
          block_arg_value = block.args[1]?

          ArrayLiteral.map(entries) do |entry|
            interpreter.define_var(block_arg_key.name, entry.key) if block_arg_key
            interpreter.define_var(block_arg_value.name, entry.value) if block_arg_value
            interpreter.accept block.body
          end
        end
      when "double_splat"
        case args.size
        when 0
          to_double_splat
        when 1
          interpret_one_arg_method(method, args) do |arg|
            if entries.empty?
              to_double_splat
            else
              unless arg.is_a?(Crystal::StringLiteral)
                arg.raise "argument to double_splat must be a StringLiteral, not #{arg.class_desc}"
              end
              to_double_splat(arg.value)
            end
          end
        else
          wrong_number_of_arguments "double_splat", args.size, 0..1
        end
      when "[]"
        case args.size
        when 1
          key = args.first
          entry = entries.find &.key.==(key)
          entry.try(&.value) || NilLiteral.new
        else
          wrong_number_of_arguments "HashLiteral#[]", args.size, 1
        end
      when "[]="
        case args.size
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
          wrong_number_of_arguments "HashLiteral#[]=", args.size, 2
        end
      when "of_key"
        interpret_argless_method(method, args) { @of.try(&.key) || Nop.new }
      when "of_value"
        interpret_argless_method(method, args) { @of.try(&.value) || Nop.new }
      when "type"
        interpret_argless_method(method, args) { @name || Nop.new }
      else
        super
      end
    end

    private def to_double_splat(trailing_string = "")
      MacroId.new(entries.join(", ") do |entry|
        "#{entry.key} => #{entry.value}"
      end + trailing_string)
    end
  end

  class NamedTupleLiteral
    def interpret(method, args, block, interpreter)
      case method
      when "empty?"
        interpret_argless_method(method, args) { BoolLiteral.new(entries.empty?) }
      when "keys"
        interpret_argless_method(method, args) { ArrayLiteral.map(entries) { |entry| MacroId.new(entry.key) } }
      when "size"
        interpret_argless_method(method, args) { NumberLiteral.new(entries.size) }
      when "to_a"
        interpret_argless_method(method, args) do
          ArrayLiteral.map(entries) { |entry| TupleLiteral.new([MacroId.new(entry.key), entry.value] of ASTNode) }
        end
      when "values"
        interpret_argless_method(method, args) { ArrayLiteral.map entries, &.value }
      when "map"
        interpret_argless_method(method, args) do
          raise "map expects a block" unless block

          block_arg_key = block.args[0]?
          block_arg_value = block.args[1]?

          ArrayLiteral.map(entries) do |entry|
            interpreter.define_var(block_arg_key.name, MacroId.new(entry.key)) if block_arg_key
            interpreter.define_var(block_arg_value.name, entry.value) if block_arg_value
            interpreter.accept block.body
          end
        end
      when "double_splat"
        case args.size
        when 0
          to_double_splat
        when 1
          interpret_one_arg_method(method, args) do |arg|
            if entries.empty?
              to_double_splat
            else
              unless arg.is_a?(Crystal::StringLiteral)
                arg.raise "argument to double_splat must be a StringLiteral, not #{arg.class_desc}"
              end
              to_double_splat(arg.value)
            end
          end
        else
          wrong_number_of_arguments "double_splat", args.size, 0..1
        end
      when "[]"
        case args.size
        when 1
          key = args.first

          case key
          when SymbolLiteral
            key = key.value
          when MacroId
            key = key.value
          when StringLiteral
            key = key.value
          else
            return NilLiteral.new
          end

          entry = entries.find &.key.==(key)
          entry.try(&.value) || NilLiteral.new
        else
          wrong_number_of_arguments "NamedTupleLiteral#[]", args.size, 1
        end
      when "[]="
        case args.size
        when 2
          key, value = args

          case key
          when SymbolLiteral
            key = key.value
          when MacroId
            key = key.value
          when StringLiteral
            key = key.value
          else
            raise "expected 'NamedTupleLiteral#[]=' first argument to be a SymbolLiteral or MacroId, not #{key.class_desc}"
          end

          index = entries.index &.key.==(key)
          if index
            entries[index] = NamedTupleLiteral::Entry.new(key, value)
          else
            entries << NamedTupleLiteral::Entry.new(key, value)
          end

          value
        else
          wrong_number_of_arguments "NamedTupleLiteral#[]=", args.size, 2
        end
      else
        super
      end
    end

    private def to_double_splat(trailing_string = "")
      MacroId.new(entries.join(", ") do |entry|
        if Symbol.needs_quotes?(entry.key)
          "#{entry.key.inspect}: #{entry.value}"
        else
          "#{entry.key}: #{entry.value}"
        end
      end + trailing_string)
    end
  end

  class TupleLiteral
    def interpret(method, args, block, interpreter)
      value = intepret_array_or_tuple_method(self, TupleLiteral, method, args, block, interpreter)
      value || super
    end
  end

  class RangeLiteral
    def interpret(method, args, block, interpreter)
      case method
      when "begin"
        interpret_argless_method(method, args) { self.from }
      when "end"
        interpret_argless_method(method, args) { self.to }
      when "excludes_end?"
        interpret_argless_method(method, args) { BoolLiteral.new(self.exclusive?) }
      when "map"
        raise "map expects a block" unless block

        block_arg = block.args.first?

        interpret_map(method, args, interpreter) do |num|
          interpreter.define_var(block_arg.name, NumberLiteral.new(num)) if block_arg
          interpreter.accept block.body
        end
      when "to_a"
        interpret_map(method, args, interpreter) do |num|
          NumberLiteral.new(num)
        end
      else
        super
      end
    end

    def interpret_map(method, args, interpreter)
      interpret_argless_method(method, args) do
        ArrayLiteral.map(interpret_to_range(interpreter)) do |num|
          yield num
        end
      end
    end

    def interpret_to_range(interpreter)
      from = self.from
      to = self.to

      from = interpreter.accept(from)
      to = interpreter.accept(to)

      unless from.is_a?(NumberLiteral)
        raise "range begin must be a NumberLiteral, not #{from.class_desc}"
      end

      unless to.is_a?(NumberLiteral)
        raise "range end must be a NumberLiteral, not #{to.class_desc}"
      end

      from = from.to_number.to_i
      to = to.to_number.to_i

      self.exclusive? ? (from...to) : (from..to)
    end
  end

  class RegexLiteral
    def interpret(method, args, block, interpreter)
      case method
      when "source"
        interpret_argless_method(method, args) { @value }
      when "options"
        interpret_argless_method(method, args) do
          options = [] of Symbol
          options << :i if @options.ignore_case?
          options << :m if @options.multiline?
          options << :x if @options.extended?
          ArrayLiteral.map(options) { |opt| SymbolLiteral.new(opt.to_s) }
        end
      else
        super
      end
    end
  end

  class MetaVar < ASTNode
    def to_macro_id
      @name
    end

    def interpret(method, args, block, interpreter)
      case method
      when "name"
        interpret_argless_method(method, args) { MacroId.new(@name) }
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
        interpret_argless_method(method, args) { @body }
      when "args"
        interpret_argless_method(method, args) do
          ArrayLiteral.map(@args) { |arg| MacroId.new(arg.name) }
        end
      when "splat_index"
        interpret_argless_method(method, args) do
          @splat_index ? NumberLiteral.new(@splat_index.not_nil!) : NilLiteral.new
        end
      else
        super
      end
    end
  end

  class Expressions
    def interpret(method, args, block, interpreter)
      case method
      when "expressions"
        interpret_argless_method(method, args) do
          ArrayLiteral.map(@expressions) { |expression| expression }
        end
      else
        super
      end
    end
  end

  class BinaryOp
    def interpret(method, args, block, interpreter)
      case method
      when "left"
        interpret_argless_method(method, args) { @left }
      when "right"
        interpret_argless_method(method, args) { @right }
      else
        super
      end
    end
  end

  class TypeDeclaration
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
      when "value"
        interpret_argless_method(method, args) { @value || Nop.new }
      else
        super
      end
    end
  end

  class UninitializedVar
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

  class Union
    def interpret(method, args, block, interpreter)
      case method
      when "types"
        interpret_argless_method(method, args) { ArrayLiteral.new(@types) }
      else
        super
      end
    end
  end

  class Arg
    def interpret(method, args, block, interpreter)
      case method
      when "name"
        interpret_argless_method(method, args) { MacroId.new(external_name) }
      when "internal_name"
        interpret_argless_method(method, args) { MacroId.new(name) }
      when "default_value"
        interpret_argless_method(method, args) { default_value || Nop.new }
      when "restriction"
        interpret_argless_method(method, args) { restriction || Nop.new }
      else
        super
      end
    end
  end

  class Def
    def interpret(method, args, block, interpreter)
      case method
      when "name"
        interpret_argless_method(method, args) { MacroId.new(@name) }
      when "args"
        interpret_argless_method(method, args) { ArrayLiteral.map @args, &.itself }
      when "splat_index"
        interpret_argless_method(method, args) do
          @splat_index ? NumberLiteral.new(@splat_index.not_nil!) : NilLiteral.new
        end
      when "double_splat"
        interpret_argless_method(method, args) { @double_splat || Nop.new }
      when "block_arg"
        interpret_argless_method(method, args) { @block_arg || Nop.new }
      when "return_type"
        interpret_argless_method(method, args) { @return_type || Nop.new }
      when "body"
        interpret_argless_method(method, args) { @body }
      when "receiver"
        interpret_argless_method(method, args) { @receiver || Nop.new }
      when "visibility"
        interpret_argless_method(method, args) do
          visibility_to_symbol(@visibility)
        end
      else
        super
      end
    end
  end

  class Macro
    def interpret(method, args, block, interpreter)
      case method
      when "name"
        interpret_argless_method(method, args) { MacroId.new(@name) }
      when "args"
        interpret_argless_method(method, args) { ArrayLiteral.map @args, &.itself }
      when "splat_index"
        interpret_argless_method(method, args) do
          @splat_index ? NumberLiteral.new(@splat_index.not_nil!) : NilLiteral.new
        end
      when "double_splat"
        interpret_argless_method(method, args) { @double_splat || Nop.new }
      when "block_arg"
        interpret_argless_method(method, args) { @block_arg || Nop.new }
      when "body"
        interpret_argless_method(method, args) { @body }
      when "visibility"
        interpret_argless_method(method, args) do
          visibility_to_symbol(@visibility)
        end
      else
        super
      end
    end
  end

  class UnaryExpression
    def interpret(method, args, block, interpreter)
      case method
      when "exp"
        interpret_argless_method(method, args) { @exp }
      else
        super
      end
    end
  end

  class VisibilityModifier
    def interpret(method, args, block, interpreter)
      case method
      when "exp"
        interpret_argless_method(method, args) { @exp }
      when "visibility"
        interpret_argless_method(method, args) do
          visibility_to_symbol(@modifier)
        end
      else
        super
      end
    end
  end

  class IsA
    def interpret(method, args, block, interpreter)
      case method
      when "receiver"
        interpret_argless_method(method, args) { @obj }
      when "arg"
        interpret_argless_method(method, args) { @const }
      else
        super
      end
    end
  end

  class RespondsTo
    def interpret(method, args, block, interpreter)
      case method
      when "receiver"
        interpret_argless_method(method, args) { @obj }
      when "name"
        interpret_argless_method(method, args) { StringLiteral.new(@name) }
      else
        super
      end
    end
  end

  class Require
    def interpret(method, args, block, interpreter)
      case method
      when "path"
        interpret_argless_method(method, args) { StringLiteral.new(@string) }
      else
        super
      end
    end
  end

  class MacroId
    def interpret(method, args, block, interpreter)
      case method
      when "==", "!="
        case arg = args.first?
        when StringLiteral, SymbolLiteral
          if method == "=="
            return BoolLiteral.new(@value == arg.value)
          else
            return BoolLiteral.new(@value != arg.value)
          end
        else
          return super
        end
      when "stringify", "class_name", "symbolize"
        return super
      end

      value = StringLiteral.new(@value).interpret(method, args, block, interpreter)
      value = MacroId.new(value.value) if value.is_a?(StringLiteral)
      value
    rescue UndefinedMacroMethodError
      raise "undefined macro method '#{class_desc}##{method}'", exception_type: Crystal::UndefinedMacroMethodError
    end

    def interpret_compare(other : MacroId | StringLiteral)
      value <=> other.value
    end
  end

  class SymbolLiteral
    def interpret(method, args, block, interpreter)
      case method
      when "==", "!="
        case arg = args.first?
        when MacroId
          if method == "=="
            return BoolLiteral.new(@value == arg.value)
          else
            return BoolLiteral.new(@value != arg.value)
          end
        else
          return super
        end
      when "stringify", "class_name", "symbolize"
        return super
      end

      value = StringLiteral.new(@value).interpret(method, args, block, interpreter)
      value = SymbolLiteral.new(value.value) if value.is_a?(StringLiteral)
      value
    rescue UndefinedMacroMethodError
      raise "undefined macro method '#{class_desc}##{method}'", exception_type: Crystal::UndefinedMacroMethodError
    end
  end

  class TypeNode
    def interpret(method, args, block, interpreter)
      case method
      when "abstract?"
        interpret_argless_method(method, args) { BoolLiteral.new(type.abstract?) }
      when "union?"
        interpret_argless_method(method, args) { BoolLiteral.new(type.is_a?(UnionType)) }
      when "union_types"
        interpret_argless_method(method, args) { TypeNode.union_types(type) }
      when "name"
        interpret_argless_method(method, args) { MacroId.new(type.devirtualize.to_s) }
      when "type_vars"
        interpret_argless_method(method, args) { TypeNode.type_vars(type) }
      when "instance_vars"
        interpret_argless_method(method, args) { TypeNode.instance_vars(type) }
      when "ancestors"
        interpret_argless_method(method, args) { TypeNode.ancestors(type) }
      when "superclass"
        interpret_argless_method(method, args) { TypeNode.superclass(type) }
      when "subclasses"
        interpret_argless_method(method, args) { TypeNode.subclasses(type) }
      when "all_subclasses"
        interpret_argless_method(method, args) { TypeNode.all_subclasses(type) }
      when "constants"
        interpret_argless_method(method, args) { TypeNode.constants(type) }
      when "constant"
        interpret_one_arg_method(method, args) do |arg|
          value = arg.to_string("argument to 'TypeNode#constant'")
          TypeNode.constant(type, value)
        end
      when "has_constant?"
        interpret_one_arg_method(method, args) do |arg|
          value = arg.to_string("argument to 'TypeNode#has_constant?'")
          TypeNode.has_constant?(type, value)
        end
      when "methods"
        interpret_argless_method(method, args) { TypeNode.methods(type) }
      when "has_method?"
        interpret_one_arg_method(method, args) do |arg|
          value = arg.to_string("argument to 'TypeNode#has_method?'")
          TypeNode.has_method?(type, value)
        end
      when "has_attribute?"
        interpret_one_arg_method(method, args) do |arg|
          value = arg.to_string("argument to 'TypeNode#has_attribute?'")
          BoolLiteral.new(!!type.has_attribute?(value))
        end
      when "size"
        interpret_argless_method(method, args) do
          type = self.type.instance_type
          case type
          when TupleInstanceType
            NumberLiteral.new(type.tuple_types.size)
          when NamedTupleInstanceType
            NumberLiteral.new(type.entries.size)
          else
            raise "undefined method 'size' for TypeNode of type #{type} (must be a tuple or named tuple type)"
          end
        end
      when "keys"
        interpret_argless_method(method, args) do
          type = self.type.instance_type
          if type.is_a?(NamedTupleInstanceType)
            ArrayLiteral.map(type.entries) { |entry| MacroId.new(entry.name) }
          else
            raise "undefined method 'keys' for TypeNode of type #{type} (must be a named tuple type)"
          end
        end
      when "[]"
        interpret_one_arg_method(method, args) do |arg|
          type = self.type.instance_type
          case type
          when NamedTupleInstanceType
            case arg
            when SymbolLiteral
              key = arg.value
            when MacroId
              key = arg.value
            else
              return NilLiteral.new
            end
            index = type.name_index(key)
            unless index
              return NilLiteral.new
            end
            TypeNode.new(type.entries[index].type)
          when TupleInstanceType
            case arg
            when NumberLiteral
              index = arg.to_number.to_i
              type = type.tuple_types[index]?
              unless type
                return NilLiteral.new
              end
              TypeNode.new(type)
            else
              return NilLiteral.new
            end
          else
            raise "undefined method '[]' for TypeNode of type #{type} (must be a tuple or named tuple type)"
          end
        end
      when "class"
        interpret_argless_method(method, args) { TypeNode.new(type.metaclass) }
      when "instance"
        interpret_argless_method(method, args) { TypeNode.new(type.instance_type) }
      when "<", "<=", ">", ">="
        interpret_one_arg_method(method, args) do |arg|
          unless arg.is_a?(TypeNode)
            raise "TypeNode##{method} expects TypeNode, not #{arg.class_desc}"
          end

          self_type = self.type
          other_type = arg.type
          case method
          when "<"
            value = self_type != other_type && self_type.implements?(other_type)
          when "<="
            value = self_type.implements?(other_type)
          when ">"
            value = self_type != other_type && other_type.implements?(self_type)
          else # ">="
            value = other_type.implements?(self_type)
          end
          BoolLiteral.new(!!value)
        end
      when "overrides?"
        interpret_two_args_method(method, args) do |arg1, arg2|
          unless arg1.is_a?(TypeNode)
            raise "TypeNode##{method} expects TypeNode as a first argument, not #{arg1.class_desc}"
          end

          value = arg2.to_string("second argument to 'TypeNode#overrides?")
          TypeNode.overrides?(type, arg1.type, value)
        end
      else
        super
      end
    end

    def self.type_vars(type)
      if type.is_a?(GenericClassInstanceType)
        if type.is_a?(TupleInstanceType)
          ArrayLiteral.map(type.tuple_types) do |tuple_type|
            TypeNode.new(tuple_type)
          end
        else
          ArrayLiteral.map(type.type_vars.values) do |type_var|
            if type_var.is_a?(Var)
              TypeNode.new(type_var.type)
            else
              type_var
            end
          end
        end
      elsif type.is_a?(GenericType)
        ArrayLiteral.map(type.as(GenericType).type_vars) do |type_var|
          MacroId.new(type_var)
        end
      else
        ArrayLiteral.new
      end
    end

    def self.instance_vars(type)
      if type.is_a?(InstanceVarContainer)
        ArrayLiteral.map(type.all_instance_vars) do |name, ivar|
          MetaVar.new(name[1..-1], ivar.type)
        end
      else
        ArrayLiteral.new
      end
    end

    def self.ancestors(type)
      ArrayLiteral.map(type.ancestors) { |ancestor| TypeNode.new(ancestor) }
    end

    def self.superclass(type)
      superclass = type.superclass
      superclass ? TypeNode.new(superclass) : NilLiteral.new
    rescue
      NilLiteral.new
    end

    def self.subclasses(type)
      ArrayLiteral.map(type.devirtualize.subclasses) { |subtype| TypeNode.new(subtype) }
    end

    def self.all_subclasses(type)
      ArrayLiteral.map(type.devirtualize.all_subclasses) { |subtype| TypeNode.new(subtype) }
    end

    def self.union_types(type)
      raise "undefined method 'union_types' for TypeNode of type #{type} (must be a union type)" unless type.is_a?(UnionType)
      ArrayLiteral.map(type.union_types) { |uniontype| TypeNode.new(uniontype) }
    end

    def self.constants(type)
      names = type.types.map { |name, member_type| MacroId.new(name).as(ASTNode) }
      ArrayLiteral.new names
    end

    def self.has_constant?(type, name)
      BoolLiteral.new(type.types.has_key?(name))
    end

    def self.constant(type, name)
      type = type.types[name]?
      case type
      when Const
        type.value
      when Type
        TypeNode.new(type)
      else
        NilLiteral.new
      end
    end

    def self.methods(type)
      defs = [] of ASTNode
      type.defs.try &.each do |name, metadatas|
        metadatas.each do |metadata|
          defs << metadata.def
        end
      end
      ArrayLiteral.new(defs)
    end

    def self.has_method?(type, name)
      BoolLiteral.new(!!type.has_def?(name))
    end

    def self.overrides?(type, target, method)
      overrides = type.lookup_defs(method).any? do |a_def|
        a_def.owner != target && a_def.macro_owner != target && !target.implements?(a_def.owner)
      end
      BoolLiteral.new(!!overrides)
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
    def interpret(method, args, block, interpreter)
      case method
      when "name"
        interpret_argless_method(method, args) { MacroId.new(name) }
      when "receiver"
        interpret_argless_method(method, args) { obj || Nop.new }
      when "args"
        interpret_argless_method(method, args) { ArrayLiteral.map self.args, &.itself }
      when "named_args"
        interpret_argless_method(method, args) do
          if named_args = self.named_args
            ArrayLiteral.map(named_args) { |arg| arg }
          else
            Nop.new
          end
        end
      when "block"
        interpret_argless_method(method, args) { self.block || Nop.new }
      when "block_arg"
        interpret_argless_method(method, args) { self.block_arg || Nop.new }
      else
        super
      end
    end

    def to_macro_id
      if !obj && !block && args.empty?
        @name
      else
        to_s
      end
    end
  end

  class NamedArgument
    def interpret(method, args, block, interpreter)
      case method
      when "name"
        interpret_argless_method(method, args) { MacroId.new(name) }
      when "value"
        interpret_argless_method(method, args) { value }
      else
        super
      end
    end
  end

  class If
    def interpret(method, args, block, interpreter)
      case method
      when "cond"
        interpret_argless_method(method, args) { @cond }
      when "then"
        interpret_argless_method(method, args) { @then }
      when "else"
        interpret_argless_method(method, args) { @else }
      else
        super
      end
    end
  end

  class Case
    def interpret(method, args, block, interpreter)
      case method
      when "cond"
        interpret_argless_method(method, args) { cond || Nop.new }
      when "whens"
        interpret_argless_method(method, args) { ArrayLiteral.map whens, &.itself }
      when "else"
        interpret_argless_method(method, args) { self.else || Nop.new }
      else
        super
      end
    end
  end

  class When
    def interpret(method, args, block, interpreter)
      case method
      when "conds"
        interpret_argless_method(method, args) { ArrayLiteral.new(conds) }
      when "body"
        interpret_argless_method(method, args) { body }
      else
        super
      end
    end
  end

  class Assign
    def interpret(method, args, block, interpreter)
      case method
      when "target"
        interpret_argless_method(method, args) { target }
      when "value"
        interpret_argless_method(method, args) { value }
      else
        super
      end
    end
  end

  class MultiAssign
    def interpret(method, args, block, interpreter)
      case method
      when "targets"
        interpret_argless_method(method, args) { ArrayLiteral.new(targets) }
      when "values"
        interpret_argless_method(method, args) { ArrayLiteral.new(values) }
      else
        super
      end
    end
  end

  class InstanceVar
    def to_macro_id
      @name
    end

    def interpret(method, args, block, interpreter)
      case method
      when "name"
        interpret_argless_method(method, args) { MacroId.new(@name) }
      else
        super
      end
    end
  end

  class ReadInstanceVar
    def interpret(method, args, block, interpreter)
      case method
      when "obj"
        interpret_argless_method(method, args) { @obj }
      when "name"
        interpret_argless_method(method, args) { MacroId.new(@name) }
      else
        super
      end
    end
  end

  class ClassVar
    def to_macro_id
      @name
    end

    def interpret(method, args, block, interpreter)
      case method
      when "name"
        interpret_argless_method(method, args) { MacroId.new(@name) }
      else
        super
      end
    end
  end

  class Global
    def to_macro_id
      @name
    end

    def interpret(method, args, block, interpreter)
      case method
      when "name"
        interpret_argless_method(method, args) { MacroId.new(@name) }
      else
        super
      end
    end
  end

  class Path
    def interpret(method, args, block, interpreter)
      case method
      when "names"
        interpret_argless_method(method, args) do
          ArrayLiteral.map(@names) { |name| MacroId.new(name) }
        end
      when "global"
        interpret_argless_method(method, args) { BoolLiteral.new(@global) }
      when "resolve"
        interpret_argless_method(method, args) { interpreter.resolve(self) }
      when "resolve?"
        interpret_argless_method(method, args) { interpreter.resolve?(self) || NilLiteral.new }
      else
        super
      end
    end

    def to_macro_id
      @names.join "::"
    end
  end

  class While
    def interpret(method, args, block, interpreter)
      case method
      when "cond"
        interpret_argless_method(method, args) { @cond }
      when "body"
        interpret_argless_method(method, args) { @body }
      else
        super
      end
    end
  end

  class Cast
    def interpret(method, args, block, interpreter)
      case method
      when "obj"
        interpret_argless_method(method, args) { obj }
      when "to"
        interpret_argless_method(method, args) { to }
      else
        super
      end
    end
  end

  class NilableCast
    def interpret(method, args, block, interpreter)
      case method
      when "obj"
        interpret_argless_method(method, args) { obj }
      when "to"
        interpret_argless_method(method, args) { to }
      else
        super
      end
    end
  end

  class Splat
    def interpret(method, args, block, interpreter)
      case method
      when "exp"
        interpret_argless_method(method, args) { exp }
      else
        super
      end
    end
  end

  class Generic
    def interpret(method, args, block, interpreter)
      case method
      when "name"
        interpret_argless_method(method, args) { name }
      when "type_vars"
        interpret_argless_method(method, args) { ArrayLiteral.new(type_vars) }
      when "named_args"
        interpret_argless_method(method, args) do
          if named_args = @named_args
            NamedTupleLiteral.new(named_args.map { |arg| NamedTupleLiteral::Entry.new(arg.name, arg.value) })
          else
            NilLiteral.new
          end
        end
      else
        super
      end
    end
  end
end

private def intepret_array_or_tuple_method(object, klass, method, args, block, interpreter)
  case method
  when "any?"
    object.interpret_argless_method(method, args) do
      raise "any? expects a block" unless block

      block_arg = block.args.first?

      Crystal::BoolLiteral.new(object.elements.any? do |elem|
        interpreter.define_var(block_arg.name, elem) if block_arg
        interpreter.accept(block.body).truthy?
      end)
    end
  when "all?"
    object.interpret_argless_method(method, args) do
      raise "all? expects a block" unless block

      block_arg = block.args.first?

      Crystal::BoolLiteral.new(object.elements.all? do |elem|
        interpreter.define_var(block_arg.name, elem) if block_arg
        interpreter.accept(block.body).truthy?
      end)
    end
  when "splat"
    case args.size
    when 0
      Crystal::MacroId.new(object.elements.join ", ")
    when 1
      object.interpret_one_arg_method(method, args) do |arg|
        if object.elements.empty?
          Crystal::MacroId.new("")
        else
          unless arg.is_a?(Crystal::StringLiteral)
            arg.raise "argument to splat must be a StringLiteral, not #{arg.class_desc}"
          end
          Crystal::MacroId.new((object.elements.join ", ") + arg.value)
        end
      end
    end
  when "empty?"
    object.interpret_argless_method(method, args) { Crystal::BoolLiteral.new(object.elements.empty?) }
  when "find"
    object.interpret_argless_method(method, args) do
      raise "find expects a block" unless block

      block_arg = block.args.first?

      found = object.elements.find do |elem|
        interpreter.define_var(block_arg.name, elem) if block_arg
        interpreter.accept(block.body).truthy?
      end
      found ? found : Crystal::NilLiteral.new
    end
  when "first"
    object.interpret_argless_method(method, args) { object.elements.first? || Crystal::NilLiteral.new }
  when "includes?"
    object.interpret_one_arg_method(method, args) do |arg|
      Crystal::BoolLiteral.new(object.elements.includes?(arg))
    end
  when "join"
    object.interpret_one_arg_method(method, args) do |arg|
      Crystal::StringLiteral.new(object.elements.map(&.to_macro_id).join arg.to_macro_id)
    end
  when "last"
    object.interpret_argless_method(method, args) { object.elements.last? || Crystal::NilLiteral.new }
  when "size"
    object.interpret_argless_method(method, args) { Crystal::NumberLiteral.new(object.elements.size) }
  when "map"
    object.interpret_argless_method(method, args) do
      raise "map expects a block" unless block

      block_arg = block.args.first?

      klass.map(object.elements) do |elem|
        interpreter.define_var(block_arg.name, elem) if block_arg
        interpreter.accept block.body
      end
    end
  when "select"
    object.interpret_argless_method(method, args) do
      raise "select expects a block" unless block
      filter(object, klass, block, interpreter)
    end
  when "reject"
    object.interpret_argless_method(method, args) do
      raise "reject expects a block" unless block
      filter(object, klass, block, interpreter, keep: false)
    end
  when "shuffle"
    klass.new(object.elements.shuffle)
  when "sort"
    klass.new(object.elements.sort { |x, y| x.interpret_compare(y) })
  when "uniq"
    klass.new(object.elements.uniq)
  when "[]"
    case args.size
    when 1
      arg = args.first
      case arg
      when Crystal::NumberLiteral
        index = arg.to_number.to_i
        value = object.elements[index]? || Crystal::NilLiteral.new
      when Crystal::RangeLiteral
        range = arg.interpret_to_range(interpreter)
        begin
          klass.new(object.elements[range])
        rescue ex
          object.raise ex.message
        end
      else
        arg.raise "argument to [] must be a number or range, not #{arg.class_desc}:\n\n#{arg}"
      end
    when 2
      from, to = args

      from = interpreter.accept(from)
      to = interpreter.accept(to)

      unless from.is_a?(Crystal::NumberLiteral)
        from.raise "expected first argument to RangeLiteral#[] to be a number, not #{from.class_desc}"
      end

      unless to.is_a?(Crystal::NumberLiteral)
        to.raise "expected second argument to RangeLiteral#[] to be a number, not #{from.class_desc}"
      end

      from = from.to_number.to_i
      to = to.to_number.to_i

      begin
        klass.new(object.elements[from, to])
      rescue ex
        object.raise ex.message
      end
    else
      object.wrong_number_of_arguments "#{klass}#[]", args.size, 1
    end
  when "[]="
    object.interpret_two_args_method(method, args) do |index_node, value|
      unless index_node.is_a?(Crystal::NumberLiteral)
        index_node.raise "expected index argument to ArrayLiteral#[]= to be a number, not #{index_node.class_desc}"
      end

      index = index_node.to_number.to_i
      index += object.elements.size if index < 0

      unless 0 <= index < object.elements.size
        index_node.raise "index out of bounds (index: #{index}, size: #{object.elements.size}"
      end

      object.elements[index] = value
      value
    end
  when "unshift"
    case args.size
    when 1
      object.elements.unshift(args.first)
      object
    else
      object.wrong_number_of_arguments "#{klass}#unshift", args.size, 1
    end
  when "push", "<<"
    case args.size
    when 1
      object.elements << args.first
      object
    else
      object.wrong_number_of_arguments "#{klass}##{method}", args.size, 1
    end
  when "+"
    object.interpret_one_arg_method(method, args) do |arg|
      case arg
      when Crystal::TupleLiteral
        other_elements = arg.elements
      when Crystal::ArrayLiteral
        other_elements = arg.elements
      else
        arg.raise "argument to `#{klass}#+` must be a tuple or array, not #{arg.class_desc}:\n\n#{arg}"
      end
      klass.new(object.elements + other_elements)
    end
  else
    nil
  end
end

private def visibility_to_symbol(visibility)
  visibility_name =
    case visibility
    when .private?
      "private"
    when .protected?
      "protected"
    else
      "public"
    end
  Crystal::SymbolLiteral.new(visibility_name)
end

def filter(object, klass, block, interpreter, keep = true)
  block_arg = block.args.first?

  klass.new(object.elements.select do |elem|
    interpreter.define_var(block_arg.name, elem) if block_arg
    block_result = interpreter.accept(block.body).truthy?
    keep ? block_result : !block_result
  end)
end
