require "./builder"

module Colorize
  # Output escape sequence to reset.
  def self.reset(io)
    io << reset
  end

  # Return escape sequence to reset.
  def self.reset
    "\e[0m"
  end

  # Keep last style for nesting `.surround`.
  @@last_style : Builder? = nil

  # Colorize the content in the block with this style.
  #
  # It outputs an escape sequence, then invokes the block. After all, it outputs reset escape sequence if needed.
  #
  # This method has a stack internally, so it keeps colorizing if nested.

  # :nodoc:
  def self.surround(style, io = STDOUT) : Nil
    last_style = @@last_style
    if style.when.colorizable_io?(io) && style != last_style
      must_reset = write_style style, io, reset: !(last_style.nil? || last_style.all_default?)
    end
    @@last_style = style

    begin
      yield io
    ensure
      @@last_style = last_style
      if must_reset
        if last_style
          write_style last_style, io, reset: !style.all_default?
        else
          reset io
        end
      end
    end
  end

  # Write escape sequence to colorize with *style*.
  # If *reset* is `true`, it invokes `#reset` before applying *style*.
  #
  # It is used by `Style` and `Object` internally.

  # :nodoc:
  def self.write_style(style, io, reset = false)
    return false if style.all_default? && !reset

    io << "\e["

    printed = false

    if reset
      io << "0"
      printed = true
    end

    unless style.fore.default?
      io << ";" if printed
      io << style.fore.fore_code
      printed = true
    end

    unless style.back.default?
      io << ";" if printed
      io << style.back.back_code
      printed = true
    end

    unless style.mode.none?
      style.mode.codes do |i|
        io << ";" if printed
        io << i
        printed = true
      end
    end

    io << "m"

    true
  end
end
