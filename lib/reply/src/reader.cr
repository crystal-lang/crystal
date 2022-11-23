require "./history"
require "./expression_editor"
require "./char_reader"
require "./auto_completion"

module Reply
  # Reader for your REPL.
  #
  # Create a subclass of it and override methods to customize behavior.
  #
  # ```
  # class MyReader < Reply::Reader
  #   def prompt(io, line_number, color?)
  #     io << "reply> "
  #   end
  # end
  # ```
  #
  # Run the REPL with `run`:
  #
  # ```
  # reader = MyReader.new
  #
  # reader.run do |expression|
  #   # Eval expression here
  #   puts " => #{expression}"
  # end
  # ```
  #
  # Or with `read_next`:
  # ```
  # loop do
  #   expression = reader.read_next
  #   break unless expression
  #
  #   # Eval expression here
  #   puts " => #{expression}"
  # end
  # ```
  class Reader
    # General architecture:
    #
    # ```
    # SDTIN -> CharReader -> Reader -> ExpressionEditor -> STDOUT
    #                        ^    ^
    #                        |    |
    #                   History  AutoCompletion
    # ```

    getter history = History.new
    getter editor : ExpressionEditor
    @auto_completion : AutoCompletion
    @char_reader = CharReader.new
    getter line_number = 1

    delegate :color?, :color=, :lines, :output, :output=, to: @editor
    delegate :word_delimiters, :word_delimiters=, to: @editor

    def initialize
      @editor = ExpressionEditor.new do |expr_line_number, color?|
        String.build do |io|
          prompt(io, @line_number + expr_line_number, color?)
        end
      end

      @auto_completion = AutoCompletion.new(&->auto_complete(String, String))
      @auto_completion.set_display_title(&->auto_completion_display_title(IO, String))
      @auto_completion.set_display_entry(&->auto_completion_display_entry(IO, String, String))
      @auto_completion.set_display_selected_entry(&->auto_completion_display_selected_entry(IO, String))

      @editor.set_header do |io, previous_height|
        @auto_completion.display_entries(io, color?, max_height: {10, Term::Size.height - 1}.min, min_height: previous_height)
      end

      @editor.set_highlight(&->highlight(String))

      if file = self.history_file
        @history.load(file)
      end
    end

    # Override to customize the prompt.
    #
    # Toggle the colorization following *color?*.
    #
    # default: `$:001> `
    def prompt(io : IO, line_number : Int32, color? : Bool)
      io << "$:"
      io << sprintf("%03d", line_number)
      io << "> "
    end

    # Override to enable expression highlighting.
    #
    # default: uncolored `expression`
    def highlight(expression : String)
      expression
    end

    # Override this method to makes the interface continue on multiline, depending of the expression.
    #
    # default: `false`
    def continue?(expression : String)
      false
    end

    # Override to enable reformatting after submitting.
    #
    # default: unchanged `expression`
    def format(expression : String)
      nil
    end

    # Override to return the expected indentation level in function of expression before cursor.
    #
    # default: `0`
    def indentation_level(expression_before_cursor : String)
      0
    end

    # Override to select with expression is saved in history.
    #
    # default: `!expression.blank?`
    def save_in_history?(expression : String)
      !expression.blank?
    end

    # Override to indicate the `Path|String|IO` where the history is saved. If `nil`, the history is not persistent.
    #
    # default: `nil`
    def history_file
      nil
    end

    # Override to integrate auto-completion.
    #
    # *current_word* is picked following `word_delimiters`.
    # It expects to return `Tuple` with:
    # * a title : `String`
    # * the auto-completion results : `Array(String)`
    #
    # default: `{"", [] of String}`
    def auto_complete(current_word : String, expression_before : String)
      return "", [] of String
    end

    # Override to customize how title is displayed.
    #
    # default: `title` underline + `":"`
    def auto_completion_display_title(io : IO, title : String)
      @auto_completion.default_display_title(io, title)
    end

    # Override to customize how entry is displayed.
    #
    # Entry is split in two (`entry_matched` + `entry_remaining`). `entry_matched` correspond
    # to the part already typed when auto-completion was triggered.
    #
    # default: `entry_matched` bright + `entry_remaining` normal.
    def auto_completion_display_entry(io : IO, entry_matched : String, entry_remaining : String)
      @auto_completion.default_display_entry(io, entry_matched, entry_remaining)
    end

    # Override to customize how the selected entry is displayed.
    #
    # default: `entry` bright on dark grey
    def auto_completion_display_selected_entry(io : IO, entry : String)
      @auto_completion.default_display_selected_entry(io, entry)
    end

    # Override to enable line re-indenting.
    #
    # This methods is called each time a character is entered.
    #
    # You should return either:
    # * `nil`: keep the line as it
    # * `Int32` value: re-indent the line by an amount equal to the returned value, relatively to `indentation_level`.
    #   (0 to follow `indentation_level`)
    #
    # See `example/crystal_repl`.
    #
    # default: `nil`
    def reindent_line(line : String)
      nil
    end

    def read_next(from io : IO = STDIN) : String? # ameba:disable Metrics/CyclomaticComplexity
      @editor.prompt_next

      loop do
        read = @char_reader.read_char(from: io)

        @editor.width, @editor.height = Term::Size.size
        case read
        in Char             then on_char(read)
        in String           then on_string(read)
        in .enter?          then on_enter { |line| return line }
        in .up?             then on_up
        in .ctrl_p?         then on_up
        in .down?           then on_down
        in .ctrl_n?         then on_down
        in .left?           then on_left
        in .ctrl_b?         then on_left
        in .right?          then on_right
        in .ctrl_f?         then on_right
        in .ctrl_up?        then on_ctrl_up { |line| return line }
        in .ctrl_down?      then on_ctrl_down { |line| return line }
        in .ctrl_left?      then on_ctrl_left { |line| return line }
        in .ctrl_right?     then on_ctrl_right { |line| return line }
        in .tab?            then on_tab
        in .shift_tab?      then on_tab(shift_tab: true)
        in .escape?         then on_escape
        in .alt_enter?      then on_enter(alt_enter: true) { }
        in .ctrl_enter?     then on_enter(ctrl_enter: true) { }
        in .alt_backspace?  then @editor.update { word_back }
        in .ctrl_backspace? then @editor.update { word_back }
        in .backspace?      then on_back
        in .home?, .ctrl_a? then on_begin
        in .end?, .ctrl_e?  then on_end
        in .delete?         then @editor.update { delete }
        in .ctrl_k?         then @editor.update { delete_after_cursor }
        in .ctrl_u?         then @editor.update { delete_before_cursor }
        in .alt_f?          then @editor.move_word_forward
        in .alt_b?          then @editor.move_word_backward
        in .ctrl_delete?    then @editor.update { delete_word }
        in .alt_d?          then @editor.update { delete_word }
        in .ctrl_c?         then on_ctrl_c
        in .ctrl_d?
          if @editor.empty?
            output.puts
            return nil
          else
            @editor.update { delete }
          end
        in .eof?, .ctrl_x?
          output.puts
          return nil
        end

        if read.is_a?(CharReader::Sequence) && (read.tab? || read.enter? || read.alt_enter? || read.shift_tab? || read.escape? || read.backspace? || read.ctrl_c?)
        else
          if @auto_completion.open?
            auto_complete_insert_char(read)
            @editor.update
          end
        end
      end
    end

    def read_loop(& : String -> _)
      loop do
        yield read_next || break
      end
    end

    # Reset the line number and close auto-completion results.
    def reset
      @line_number = 1
      @auto_completion.close
    end

    # Clear the history and the `history_file`.
    def clear_history
      @history.clear
      if file = self.history_file
        @history.save(file)
      end
    end

    private def on_char(char)
      @editor.update do
        @editor << char
        line = @editor.current_line.rstrip(' ')

        if @editor.x == line.size
          # Re-indent line after typing a char.
          if shift = self.reindent_line(line)
            indent = self.indentation_level(@editor.expression_before_cursor)
            new_indent = (indent + shift).clamp 0..
            @editor.current_line = "  "*new_indent + @editor.current_line.lstrip(' ')
          end
        end
      end
    end

    private def on_string(string)
      @editor.update do
        @editor << string
      end
    end

    private def on_enter(alt_enter = false, ctrl_enter = false, &)
      @auto_completion.close
      if alt_enter || ctrl_enter || (@editor.cursor_on_last_line? && continue?(@editor.expression))
        @editor.update do
          insert_new_line(indent: self.indentation_level(@editor.expression_before_cursor))
        end
      else
        submit_expr
        yield @editor.expression
      end
    end

    private def on_up
      has_moved = @editor.move_cursor_up

      if !has_moved && (new_lines = @history.up(@editor.lines))
        @editor.replace(new_lines)
        @editor.move_cursor_to_end
      end
    end

    private def on_down
      has_moved = @editor.move_cursor_down

      if !has_moved && (new_lines = @history.down(@editor.lines))
        @editor.replace(new_lines)
        @editor.move_cursor_to_end_of_line(y: 0)
      end
    end

    private def on_left
      @editor.move_cursor_left
    end

    private def on_right
      @editor.move_cursor_right
    end

    private def on_back
      auto_complete_remove_char if @auto_completion.open?
      @editor.update { back }
    end

    # If overridden, can yield an expression to giveback to `run`.
    # This is made because the `PryInterface` in `IC` can override these hotkeys and yield
    # command like `step`/`next`.
    #
    # TODO: It need a proper design to override hotkeys.
    private def on_ctrl_up(& : String ->)
      @editor.scroll_down
    end

    private def on_ctrl_down(& : String ->)
      @editor.scroll_up
    end

    private def on_ctrl_left(& : String ->)
      @editor.move_word_backward
    end

    private def on_ctrl_right(& : String ->)
      @editor.move_word_forward
    end

    private def on_ctrl_c
      @auto_completion.close
      @editor.end_editing
      output.puts "^C"
      @history.set_to_last
      @editor.prompt_next
    end

    private def on_tab(shift_tab = false)
      line = @editor.current_line

      # Retrieve the word under the cursor
      word_begin, word_end = @editor.current_word_begin_end
      current_word = line[word_begin..word_end]

      if @auto_completion.open?
        if shift_tab
          replacement = @auto_completion.selection_previous
        else
          replacement = @auto_completion.selection_next
        end
      else
        # Get whole expression before cursor, allow auto-completion to deduce the receiver type
        expr = @editor.expression_before_cursor(x: word_begin)

        # Compute auto-completion, return `replacement` (`nil` if no entry, full name if only one entry, or the begin match of entries otherwise)
        replacement = @auto_completion.complete_on(current_word, expr)

        if replacement && @auto_completion.entries.size >= 2
          @auto_completion.open
        end
      end

      # Replace the current_word by the replacement word
      if replacement
        @editor.update { @editor.current_word = replacement }
      end
    end

    private def on_escape
      @auto_completion.close
      @editor.update
    end

    private def on_begin
      @editor.move_cursor_to_begin
    end

    private def on_end
      @editor.move_cursor_to_end
    end

    private def auto_complete_insert_char(char)
      if char.is_a? Char && !char.in?(@editor.word_delimiters)
        @auto_completion.name_filter = @editor.current_word
      elsif @editor.expression_scrolled? || char.is_a?(String)
        @auto_completion.close
      else
        @auto_completion.clear
      end
    end

    private def auto_complete_remove_char
      char = @editor.current_line[@editor.x - 1]?
      if !char.in?(@editor.word_delimiters)
        @auto_completion.name_filter = @editor.current_word[...-1]
      else
        @auto_completion.clear
      end
    end

    private def submit_expr(*, history = true)
      formated = format(@editor.expression).try &.split('\n')
      @editor.end_editing(replacement: formated)

      @line_number += @editor.lines.size
      if history && save_in_history?(@editor.expression)
        @history << @editor.lines
      else
        @history.set_to_last
      end
      if file = self.history_file
        @history.save(file)
      end
    end
  end
end
