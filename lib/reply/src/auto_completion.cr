require "./term_cursor"
require "./term_size"
require "colorize"

module Reply
  # Interface of auto-completion.
  #
  # It provides following important methods:
  #
  # * `complete_on`: Trigger the auto-completion given a *word_on_cursor* and expression before.
  # Stores the list of entries, and returns the *replacement* string.
  #
  # * `name_filter=`: Update the filtering of entries.
  #
  # * `display_entries`: Displays on screen the stored entries.
  # Highlight the one selected. (initially `nil`).
  #
  # * `selection_next`/`selection_previous`: Increases/decrease the selected entry.
  #
  # * `open`/`close`: Toggle display, clear entries if close.
  #
  # * `clear`: Like `close`, but display a empty space instead of nothing.
  private class AutoCompletion
    getter? open = false
    getter? cleared = false
    @selection_pos : Int32? = nil

    @title = ""
    @all_entries = [] of String
    getter entries = [] of String
    property name_filter = ""

    def initialize(&@auto_complete : String, String -> {String, Array(String)})
      @display_title = ->default_display_title(IO, String)
      @display_entry = ->default_display_entry(IO, String, String)
      @display_selected_entry = ->default_display_selected_entry(IO, String)
    end

    def complete_on(current_word : String, expression_before : String) : String?
      @title, @all_entries = @auto_complete.call(current_word, expression_before)
      self.name_filter = current_word

      @entries.empty? ? nil : common_root(@entries)
    end

    def name_filter=(@name_filter)
      @selection_pos = nil
      @entries = @all_entries.select(&.starts_with?(@name_filter))
    end

    # If open, displays completion entries by columns, minimizing the height.
    # Highlight the selected entry (initially `nil`).
    #
    # If cleared, displays `clear_size` space.
    #
    # If closed, do nothing.
    #
    # Returns the actual displayed height.
    def display_entries(io, color? = true, width = Term::Size.width, max_height = 10, min_height = 0) : Int32 # ameba:disable Metrics/CyclomaticComplexity
      if cleared?
        min_height.times { io.puts }
        return min_height
      end

      return 0 unless open?
      return 0 if max_height <= 1

      height = 0

      # Print title:
      if color?
        @display_title.call(io, @title)
      else
        io << @title << ":"
      end
      io.puts
      height += 1

      if @entries.empty?
        (min_height - height).times { io.puts }
        return {height, min_height}.max
      end

      nb_rows = compute_nb_row(@entries, max_nb_row: max_height - height, width: width)

      columns = @entries.in_groups_of(nb_rows, filled_up_with: "")
      column_widths = columns.map &.max_of &.size.+(2)

      nb_cols = nb_colomns_in_width(column_widths, width)

      col_start = 0
      if pos = @selection_pos
        col_end = pos // nb_rows

        if col_end >= nb_cols
          nb_cols = nb_colomns_in_width(column_widths[..col_end].reverse_each, width)

          col_start = col_end - nb_cols + 1
        end
      end

      nb_rows.times do |r|
        nb_cols.times do |c|
          c += col_start

          entry = columns[c][r]
          col_width = column_widths[c]

          # `...` on the last column and row:
          if (r == nb_rows - 1) && (c - col_start == nb_cols - 1) && columns[c + 1]?
            entry += ".."
          end

          # Entry to display:
          entry_str = entry.ljust(col_width)

          if r + c*nb_rows == @selection_pos
            # Colorize selection:
            if color?
              @display_selected_entry.call(io, entry_str)
            else
              io << ">" + entry_str[...-1] # if no color, remove last spaces to let place to '*'.
            end
          else
            # Display entry_str, with @name_filter prefix in bright:
            unless entry.empty?
              if color?
                io << @display_entry.call(io, @name_filter, entry_str.lchop(@name_filter))
              else
                io << entry_str
              end
            end
          end
        end
        io << Term::Cursor.clear_line_after if color?
        io.puts
      end

      height += nb_rows

      (min_height - height).times { io.puts }

      {height, min_height}.max
    end

    # Increases selected entry.
    def selection_next
      return nil if @entries.empty?

      if (pos = @selection_pos).nil?
        new_pos = 0
      else
        new_pos = (pos + 1) % @entries.size
      end
      @selection_pos = new_pos
      @entries[new_pos]
    end

    # Decreases selected entry.
    def selection_previous
      return nil if @entries.empty?

      if (pos = @selection_pos).nil?
        new_pos = 0
      else
        new_pos = (pos - 1) % @entries.size
      end
      @selection_pos = new_pos
      @entries[new_pos]
    end

    def open
      @open = true
      @cleared = false
    end

    def close
      @selection_pos = nil
      @entries.clear
      @name_filter = ""
      @all_entries.clear
      @open = false
      @cleared = false
    end

    def clear
      close
      @cleared = true
    end

    def set_display_title(&@display_title : IO, String ->)
    end

    def set_display_entry(&@display_entry : IO, String, String ->)
    end

    def set_display_selected_entry(&@display_selected_entry : IO, String ->)
    end

    protected def default_display_title(io, title)
      io << title.colorize.underline << ":"
    end

    protected def default_display_entry(io, entry_matched, entry_remaining)
      io << entry_matched.colorize.bright << entry_remaining
    end

    protected def default_display_selected_entry(io, entry)
      io << entry.colorize.bright.on_dark_gray
    end

    private def nb_colomns_in_width(column_widths, width)
      nb_cols = 0
      w = 0
      column_widths.each do |col_width|
        w += col_width
        break if w > width
        nb_cols += 1
      end
      nb_cols
    end

    # Computes the min number of rows required to display entries:
    # * if all entries cannot fit in `max_nb_row` rows, returns `max_nb_row`,
    # * if there are less than 10 entries, returns `entries.size` because in this case, it's more convenient to display them in one column.
    private def compute_nb_row(entries, max_nb_row, width)
      if entries.size > 10
        # test possible nb rows: (1 to max_nb_row)
        1.to max_nb_row do |r|
          w = 0
          # Sum the width of each given column:
          entries.each_slice(r, reuse: true) do |col|
            w += col.max_of &.size + 2
          end

          # If *w* goes past *width*, we found min row required:
          return r if w < width
        end
      end

      {entries.size, max_nb_row}.min
    end

    # Finds the common root text between given entries.
    private def common_root(entries)
      return "" if entries.empty?
      return entries[0] if entries.size == 1

      i = 0
      entry_iterators = entries.map &.each_char

      loop do
        char_on_first_entry = entries[0][i]?
        same = entry_iterators.all? do |entry|
          entry.next == char_on_first_entry
        end
        i += 1
        break if !same
      end
      entries[0][...(i - 1)]
    end
  end
end
