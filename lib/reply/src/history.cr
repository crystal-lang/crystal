module Reply
  class History
    getter history = Deque(Array(String)).new
    getter max_size = 10_000
    @index = 0

    # Hold the history lines being edited, always contains one element more than @history
    # because it can also contain the current line (not yet in history)
    @edited_history = [nil] of Array(String)?

    def <<(lines)
      lines = lines.dup # make history elements independent

      if l = @history.delete_element(lines)
        # re-insert duplicate elements at the end
        @history.push(l)
      else
        # delete oldest entries until history size is `max_size`
        while @history.size >= max_size
          @history.delete_at(0)
        end

        @history.push(lines)
      end
      set_to_last
    end

    def clear
      @history.clear
      @edited_history.clear.push(nil)
      @index = 0
    end

    def up(current_edited_lines : Array(String))
      unless @index == 0
        @edited_history[@index] = current_edited_lines

        @index -= 1
        (@edited_history[@index]? || @history[@index]).dup
      end
    end

    def down(current_edited_lines : Array(String))
      unless @index == @history.size
        @edited_history[@index] = current_edited_lines

        @index += 1
        (@edited_history[@index]? || @history[@index]).dup
      end
    end

    def max_size=(max_size)
      @max_size = max_size.clamp 1..
    end

    def load(file : Path | String)
      File.touch(file) unless File.exists?(file)
      File.open(file, "r") { |f| load(f) }
    end

    def load(io : IO)
      str = io.gets_to_end
      if str.empty?
        @history = Deque(Array(String)).new
      else
        history =
          str.gsub(/(\\\n|\\\\)/, {
            "\\\n": '\e', # replace temporary `\\n` by `\e` because we first split by `\n` but want to avoid `\\n`. (`\e` could not exist in a history line)
            "\\\\": '\\', # replace `\\` by `\`.
          })
            .split('\n')        # split each expression
            .map(&.split('\e')) # split each expression by lines

        @history = Deque(Array(String)).new(history)
      end

      @edited_history.clear
      (@history.size + 1).times do
        @edited_history << nil
      end
      @index = @history.size
    end

    def save(file : Path | String)
      File.open(file, "w") { |f| save(f) }
    end

    def save(io : IO)
      @history.join(io, '\n') do |entry, io2|
        entry.join(io2, "\\\n") do |line, io3|
          io3 << line.gsub('\\', "\\\\")
        end
      end
    end

    # Sets the index to last added value
    protected def set_to_last
      @index = @history.size
      @edited_history.fill(nil).push(nil)
    end
  end
end

class Deque(T)
  # Add this method because unlike `Array`, `Deque#delete` return a Boolean instead of the element.
  def delete_element(obj) : T?
    internal_delete { |i| i == obj }
  end
end
