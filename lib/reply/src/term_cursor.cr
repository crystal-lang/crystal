# from https://github.com/crystal-term/cursor
module Reply::Term
  module Cursor
    extend self

    ESC      = "\e"
    CSI      = "\e["
    DEC_RST  = "l"
    DEC_SET  = "h"
    DEC_TCEM = "?25"

    # Make cursor visible
    def show
      CSI + DEC_TCEM + DEC_SET
    end

    # Hide cursor
    def hide
      CSI + DEC_TCEM + DEC_RST
    end

    # Switch off cursor for the block
    def invisible(stream = STDOUT, &block)
      stream.print(hide)
      yield
    ensure
      stream.print(show)
    end

    # Save current position
    def save
      # TODO: Should be CSI + "s" on Windows
      ESC + "7"
    end

    # Restore cursor position
    def restore
      # TODO: Should be CSI + "u" on Windows
      ESC + "8"
    end

    # Query cursor current position
    def current
      CSI + "6n"
    end

    # Set the cursor absolute position
    def move_to(row : Int32? = nil, column : Int32? = nil)
      return CSI + "H" if row.nil? && column.nil?
      CSI + "#{(column || 0) + 1};#{(row || 0) + 1}H"
    end

    # Move cursor relative to its current position
    def move(x, y)
      (x < 0 ? backward(-x) : (x > 0 ? forward(x) : "")) +
        (y < 0 ? down(-y) : (y > 0 ? up(y) : ""))
    end

    # Move cursor up by n
    def up(n : Int32? = nil)
      CSI + "#{(n || 1)}A"
    end

    # :ditto:
    def cursor_up(n)
      up(n)
    end

    # Move the cursor down by n
    def down(n : Int32? = nil)
      CSI + "#{(n || 1)}B"
    end

    # :ditto:
    def cursor_down(n)
      down(n)
    end

    # Move the cursor backward by n
    def backward(n : Int32? = nil)
      CSI + "#{n || 1}D"
    end

    # :ditto:
    def cursor_backward(n)
      backward(n)
    end

    # Move the cursor forward by n
    def forward(n : Int32? = nil)
      CSI + "#{n || 1}C"
    end

    # :ditto:
    def cursor_forward(n)
      forward(n)
    end

    # Cursor moves to nth position horizontally in the current line
    def column(n : Int32? = nil)
      CSI + "#{n || 1}G"
    end

    # Cursor moves to the nth position vertically in the current column
    def row(n : Int32? = nil)
      CSI + "#{n || 1}d"
    end

    # Move cursor down to beginning of next line
    def next_line
      CSI + 'E' + column(1)
    end

    # Move cursor up to beginning of previous line
    def prev_line
      CSI + 'A' + column(1)
    end

    # Erase n characters from the current cursor position
    def clear_char(n : Int32? = nil)
      CSI + "#{n}X"
    end

    # Erase the entire current line and return to beginning of the line
    def clear_line
      CSI + "2K" + column(1)
    end

    # Erase from the beginning of the line up to and including
    # the current cursor position.
    def clear_line_before
      CSI + "1K"
    end

    # Erase from the current position (inclusive) to
    # the end of the line
    def clear_line_after
      CSI + "0K"
    end

    # Clear a number of lines
    def clear_lines(n, direction = :up)
      n.times.reduce([] of String) do |acc, i|
        dir = direction == :up ? up : down
        acc << clear_line + ((i == n - 1) ? "" : dir)
      end.join
    end

    # Clear a number of rows
    def clear_rows(n, direction = :up)
      clear_lines(n, direction)
    end

    # Clear screen down from current position
    def clear_screen_down
      CSI + "J"
    end

    # Clear screen up from current position
    def clear_screen_up
      CSI + "1J"
    end

    # Clear the screen with the background colour and moves the cursor to home
    def clear_screen
      CSI + "2J"
    end

    # Scroll display up one line
    def scroll_up
      ESC + "M"
    end

    # Scroll display down one line
    def scroll_down
      ESC + "D"
    end
  end
end
