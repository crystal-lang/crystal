module Reply
  private struct CharReader
    enum Sequence
      EOF
      UP
      DOWN
      RIGHT
      LEFT
      ENTER
      ESCAPE
      DELETE
      BACKSPACE
      CTRL_A
      CTRL_B
      CTRL_C
      CTRL_D
      CTRL_E
      CTRL_F
      CTRL_K
      CTRL_N
      CTRL_P
      CTRL_U
      CTRL_X
      CTRL_UP
      CTRL_DOWN
      CTRL_LEFT
      CTRL_RIGHT
      CTRL_ENTER
      CTRL_DELETE
      CTRL_BACKSPACE
      ALT_B
      ALT_D
      ALT_F
      ALT_ENTER
      ALT_BACKSPACE
      TAB
      SHIFT_TAB
      HOME
      END
    end

    def initialize(buffer_size = 8192)
      @slice_buffer = Bytes.new(buffer_size)
    end

    def read_char(from io : T = STDIN) forall T
      {% if flag?(:win32) && T <= IO::FileDescriptor %}
        handle = LibC._get_osfhandle(io.fd)
        raise RuntimeError.from_errno("_get_osfhandle") if handle == -1

        raw(io) do
          LibC.ReadConsoleA(LibC::HANDLE.new(handle), @slice_buffer, @slice_buffer.size, out nb_read, nil)

          parse_escape_sequence(@slice_buffer[0...nb_read])
        end
      {% else %}
        nb_read = raw(io, &.read(@slice_buffer))
        parse_escape_sequence(@slice_buffer[0...nb_read])
      {% end %}
    end

    private def parse_escape_sequence(chars : Bytes) : Char | Sequence | String?
      return String.new(chars) if chars.size > 6
      return Sequence::EOF if chars.empty?

      case chars[0]?
      when '\e'.ord
        case chars[1]?
        when '['.ord
          case chars[2]?
          when 'A'.ord then Sequence::UP
          when 'B'.ord then Sequence::DOWN
          when 'C'.ord then Sequence::RIGHT
          when 'D'.ord then Sequence::LEFT
          when 'Z'.ord then Sequence::SHIFT_TAB
          when '3'.ord
            if {chars[3]?, chars[4]?} == {';'.ord, '5'.ord}
              case chars[5]?
              when '~'.ord then Sequence::CTRL_DELETE
              end
            elsif chars[3]? == '~'.ord
              Sequence::DELETE
            end
          when '1'.ord
            if {chars[3]?, chars[4]?} == {';'.ord, '5'.ord}
              case chars[5]?
              when 'A'.ord then Sequence::CTRL_UP
              when 'B'.ord then Sequence::CTRL_DOWN
              when 'C'.ord then Sequence::CTRL_RIGHT
              when 'D'.ord then Sequence::CTRL_LEFT
              end
            elsif chars[3]? == '~'.ord # linux console HOME
              Sequence::HOME
            end
          when '4'.ord # linux console END
            if chars[3]? == '~'.ord
              Sequence::END
            end
          when 'H'.ord # xterm HOME
            Sequence::HOME
          when 'F'.ord # xterm END
            Sequence::END
          end
        when '\t'.ord
          Sequence::SHIFT_TAB
        when '\r'.ord
          Sequence::ALT_ENTER
        when 0x7f
          Sequence::ALT_BACKSPACE
        when 'O'.ord
          if chars[2]? == 'H'.ord # gnome terminal HOME
            Sequence::HOME
          elsif chars[2]? == 'F'.ord # gnome terminal END
            Sequence::END
          end
        when 'b'
          Sequence::ALT_B
        when 'd'
          Sequence::ALT_D
        when 'f'
          Sequence::ALT_F
        when Nil
          Sequence::ESCAPE
        end
      when '\r'.ord
        Sequence::ENTER
      when '\n'.ord
        {% if flag?(:win32) %}
          Sequence::CTRL_ENTER
        {% else %}
          Sequence::ENTER
        {% end %}
      when '\t'.ord
        Sequence::TAB
      when '\b'.ord
        Sequence::CTRL_BACKSPACE
      when ctrl('a')
        Sequence::CTRL_A
      when ctrl('b')
        Sequence::CTRL_B
      when ctrl('c')
        Sequence::CTRL_C
      when ctrl('d')
        Sequence::CTRL_D
      when ctrl('e')
        Sequence::CTRL_E
      when ctrl('f')
        Sequence::CTRL_F
      when ctrl('k')
        Sequence::CTRL_K
      when ctrl('n')
        Sequence::CTRL_N
      when ctrl('p')
        Sequence::CTRL_P
      when ctrl('u')
        Sequence::CTRL_U
      when ctrl('x')
        Sequence::CTRL_X
      when '\0'.ord
        Sequence::EOF
      when 0x7f
        Sequence::BACKSPACE
      else
        if chars.size == 1
          chars[0].chr
        end
      end || String.new(chars)
    end

    private def raw(io : T, &) forall T
      {% if T.has_method?(:raw) %}
        if io.tty?
          io.raw { yield io }
        else
          yield io
        end
      {% else %}
        yield io
      {% end %}
    end

    private def ctrl(k)
      (k.ord & 0x1f)
    end
  end
end

{% if flag?(:win32) %}
  lib LibC
    STD_INPUT_HANDLE = -10

    fun ReadConsoleA(hConsoleInput : Void*,
                     lpBuffer : Void*,
                     nNumberOfCharsToRead : UInt32,
                     lpNumberOfCharsRead : UInt32*,
                     pInputControl : Void*) : UInt8
  end
{% end %}
