{% skip_file if flag?(:win32) %}
# FIXME: We skip all these specs because the file descriptor is blocking, making
# the spec to hang out, and we cannot change it. # (`blocking=` is not implemented on window)

require "./spec_helper"

module Reply
  describe Reader do
    it "reads char" do
      reader = SpecHelper.reader
      pipe_out, pipe_in = IO.pipe

      spawn do
        reader.read_next(from: pipe_out).should eq "a"
        reader.read_next(from: pipe_out).should eq "♥💎"
      end

      SpecHelper.send(pipe_in, 'a')
      SpecHelper.send(pipe_in, '\n')
      SpecHelper.send(pipe_in, '♥')
      SpecHelper.send(pipe_in, '💎')
      SpecHelper.send(pipe_in, '\n')
    end

    it "reads string" do
      reader = SpecHelper.reader
      pipe_out, pipe_in = IO.pipe

      spawn do
        reader.read_next(from: pipe_out).should eq "Hello"
        reader.read_next(from: pipe_out).should eq "class Foo\n  def foo\n    42\n  end\nend"
      end

      SpecHelper.send(pipe_in, "Hello")
      SpecHelper.send(pipe_in, '\n')

      SpecHelper.send(pipe_in, <<-END)
        class Foo
          def foo
            42
          end
        end
        END
      SpecHelper.send(pipe_in, '\n')
    end

    it "uses directional arrows" do
      reader = SpecHelper.reader
      pipe_out, pipe_in = IO.pipe

      spawn do
        reader.read_next(from: pipe_out)
      end

      SpecHelper.send(pipe_in, <<-END)
        class Foo
          def foo
            42
          end
        end
        END
      SpecHelper.send(pipe_in, "\e[A") # up
      SpecHelper.send(pipe_in, "\e[C") # right
      SpecHelper.send(pipe_in, "\e[B") # down
      SpecHelper.send(pipe_in, "\e[D") # left
      reader.editor.verify(x: 2, y: 4)

      SpecHelper.send(pipe_in, '\0')
    end

    it "uses ctrl-n & ctrl-p" do
      reader = SpecHelper.reader
      pipe_out, pipe_in = IO.pipe

      spawn do
        reader.read_next(from: pipe_out)
        reader.read_next(from: pipe_out)
        reader.read_next(from: pipe_out)
      end

      SpecHelper.send(pipe_in, "x = 42")
      SpecHelper.send(pipe_in, '\n')
      SpecHelper.send(pipe_in, <<-END)
        puts "Hello",
          "World"
        END
      SpecHelper.send(pipe_in, '\n')

      SpecHelper.send(pipe_in, '\u0010') # ctrl-p (up)
      reader.editor.verify(%(puts "Hello",\n  "World"))

      SpecHelper.send(pipe_in, '\u0010') # ctrl-p (up)
      SpecHelper.send(pipe_in, '\u0010') # ctrl-p (up)
      reader.editor.verify("x = 42")

      SpecHelper.send(pipe_in, '\u000e') # ctrl-n (down)
      reader.editor.verify(%(puts "Hello",\n  "World"))

      SpecHelper.send(pipe_in, '\0')
    end

    it "uses ctrl-f & ctrl-b" do
      reader = SpecHelper.reader
      pipe_out, pipe_in = IO.pipe

      spawn do
        reader.read_next(from: pipe_out)
      end

      SpecHelper.send(pipe_in, "x=42")
      reader.editor.verify(x: 4, y: 0)

      SpecHelper.send(pipe_in, '\u0006') # ctrl-f (right)
      reader.editor.verify(x: 4, y: 0)

      SpecHelper.send(pipe_in, '\u0002') # ctrl-b (left)
      reader.editor.verify(x: 3, y: 0)

      SpecHelper.send(pipe_in, '\u0002') # ctrl-b (left)
      SpecHelper.send(pipe_in, '\u0002') # ctrl-b (left)
      SpecHelper.send(pipe_in, '\u0002') # ctrl-b (left)
      reader.editor.verify(x: 0, y: 0)

      SpecHelper.send(pipe_in, '\u0002') # ctrl-b (left)
      reader.editor.verify(x: 0, y: 0)

      SpecHelper.send(pipe_in, '\u0006') # ctrl-f (right)
      reader.editor.verify(x: 1, y: 0)

      SpecHelper.send(pipe_in, '\0')
    end

    it "uses back" do
      reader = SpecHelper.reader
      pipe_out, pipe_in = IO.pipe

      spawn do
        reader.read_next(from: pipe_out).should eq "Hey"
        reader.read_next(from: pipe_out).should eq "ab"
        reader.read_next(from: pipe_out).should eq ""
      end

      SpecHelper.send(pipe_in, "Hello")
      SpecHelper.send(pipe_in, '\u{7f}') # back
      SpecHelper.send(pipe_in, '\u{7f}')
      SpecHelper.send(pipe_in, '\u{7f}')
      SpecHelper.send(pipe_in, 'y')
      SpecHelper.send(pipe_in, '\n')

      SpecHelper.send(pipe_in, "a\nb")
      SpecHelper.send(pipe_in, "\e[D") # left
      SpecHelper.send(pipe_in, '\u{7f}')
      SpecHelper.send(pipe_in, '\n')

      SpecHelper.send(pipe_in, "")
      SpecHelper.send(pipe_in, '\u{7f}')
      SpecHelper.send(pipe_in, '\n')
    end

    it "deletes" do
      reader = SpecHelper.reader
      pipe_out, pipe_in = IO.pipe

      spawn do
        reader.read_next(from: pipe_out).should eq "Hey"
        reader.read_next(from: pipe_out).should eq "ab"
        reader.read_next(from: pipe_out).should eq ""
      end

      SpecHelper.send(pipe_in, "Hello")
      SpecHelper.send(pipe_in, "\e[D") # left
      SpecHelper.send(pipe_in, "\e[D")
      SpecHelper.send(pipe_in, "\e[D")
      SpecHelper.send(pipe_in, "\e[3~") # delete
      SpecHelper.send(pipe_in, "\e[3~")
      SpecHelper.send(pipe_in, "\e[3~")
      SpecHelper.send(pipe_in, 'y')
      SpecHelper.send(pipe_in, '\n')

      SpecHelper.send(pipe_in, "a\nb")
      SpecHelper.send(pipe_in, "\e[D")
      SpecHelper.send(pipe_in, "\e[D")
      SpecHelper.send(pipe_in, "\e[3~")
      SpecHelper.send(pipe_in, '\n')

      SpecHelper.send(pipe_in, "")
      SpecHelper.send(pipe_in, "\e[3~")
      SpecHelper.send(pipe_in, '\n')
    end

    it "deletes or eof" do
      reader = SpecHelper.reader
      pipe_out, pipe_in = IO.pipe

      channel = Channel(Symbol).new
      spawn do
        reader.read_next(from: pipe_out).should be_nil
        channel.send(:finished)
      end

      SpecHelper.send(pipe_in, "a\nb")
      SpecHelper.send(pipe_in, '\u0001') # ctrl-a (move cursor to begin)
      reader.editor.verify("a\nb")

      SpecHelper.send(pipe_in, '\u0004') # ctrl-d (delete or eof)
      reader.editor.verify("\nb")

      SpecHelper.send(pipe_in, '\u0004') # ctrl-d (delete or eof)
      reader.editor.verify("b")

      SpecHelper.send(pipe_in, '\u0004') # ctrl-d (delete or eof)
      reader.editor.verify("")

      SpecHelper.send(pipe_in, '\u0004') # ctrl-d (delete or eof)
      channel.receive.should eq :finished
    end

    it "uses tabulation" do
      reader = SpecHelper.reader
      pipe_out, pipe_in = IO.pipe

      spawn do
        reader.read_next(from: pipe_out)
      end

      SpecHelper.send(pipe_in, "42.")
      reader.auto_completion.verify(open: false)

      SpecHelper.send(pipe_in, '\t')
      reader.auto_completion.verify(open: true, entries: %w(hello world hey))
      reader.editor.verify("42.")

      SpecHelper.send(pipe_in, 'w')
      reader.auto_completion.verify(open: true, entries: %w(world), name_filter: "w")
      reader.editor.verify("42.w")

      SpecHelper.send(pipe_in, '\u{7f}') # back
      reader.auto_completion.verify(open: true, entries: %w(hello world hey))
      reader.editor.verify("42.")

      SpecHelper.send(pipe_in, 'h')
      reader.auto_completion.verify(open: true, entries: %w(hello hey), name_filter: "h")
      reader.editor.verify("42.h")

      SpecHelper.send(pipe_in, '\t')
      reader.auto_completion.verify(open: true, entries: %w(hello hey), name_filter: "h", selection_pos: 0)
      reader.editor.verify("42.hello")

      SpecHelper.send(pipe_in, '\t')
      reader.auto_completion.verify(open: true, entries: %w(hello hey), name_filter: "h", selection_pos: 1)
      reader.editor.verify("42.hey")

      SpecHelper.send(pipe_in, '\t')
      reader.auto_completion.verify(open: true, entries: %w(hello hey), name_filter: "h", selection_pos: 0)
      reader.editor.verify("42.hello")

      SpecHelper.send(pipe_in, "\e\t") # shit_tab
      reader.auto_completion.verify(open: true, entries: %w(hello hey), name_filter: "h", selection_pos: 1)
      reader.editor.verify("42.hey")

      SpecHelper.send(pipe_in, '\u{7f}') # back
      SpecHelper.send(pipe_in, 'l')
      SpecHelper.send(pipe_in, '\t')
      reader.auto_completion.verify(open: true, entries: %w(hello), name_filter: "hel", selection_pos: 0)
      reader.editor.verify("42.hello")

      SpecHelper.send(pipe_in, ' ')
      reader.auto_completion.verify(open: false, cleared: true)
      reader.editor.verify("42.hello ")

      SpecHelper.send(pipe_in, '\0')
    end

    it "roll over auto completion entries with equal" do
      reader = SpecHelper.reader(SpecReaderWithEqual)
      pipe_out, pipe_in = IO.pipe

      spawn do
        reader.read_next(from: pipe_out)
      end

      SpecHelper.send(pipe_in, '\t')
      reader.auto_completion.verify(open: true, entries: %w(hello world= hey))
      reader.editor.verify("")

      SpecHelper.send(pipe_in, '\t')
      reader.auto_completion.verify(open: true, entries: %w(hello world= hey), selection_pos: 0)
      reader.editor.verify("hello")

      SpecHelper.send(pipe_in, '\t')
      reader.auto_completion.verify(open: true, entries: %w(hello world= hey), selection_pos: 1)
      reader.editor.verify("world=")

      SpecHelper.send(pipe_in, '\t')
      reader.auto_completion.verify(open: true, entries: %w(hello world= hey), selection_pos: 2)
      reader.editor.verify("hey")

      SpecHelper.send(pipe_in, '\0')
    end

    it "uses escape" do
      reader = SpecHelper.reader
      pipe_out, pipe_in = IO.pipe

      spawn do
        reader.read_next(from: pipe_out)
      end

      SpecHelper.send(pipe_in, "42.")
      reader.auto_completion.verify(open: false)

      SpecHelper.send(pipe_in, '\t')
      reader.auto_completion.verify(open: true, entries: %w(hello world hey))

      SpecHelper.send(pipe_in, '\e') # escape
      reader.auto_completion.verify(open: false)
    end

    it "uses alt-enter" do
      reader = SpecHelper.reader
      pipe_out, pipe_in = IO.pipe

      spawn do
        reader.read_next(from: pipe_out).should eq "Hello\nWorld"
      end

      SpecHelper.send(pipe_in, "Hello")
      SpecHelper.send(pipe_in, "\e\r") # alt-enter
      SpecHelper.send(pipe_in, "World")
      reader.editor.verify("Hello\nWorld")
      SpecHelper.send(pipe_in, "\n")
    end

    it "uses ctrl-c" do
      reader = SpecHelper.reader
      pipe_out, pipe_in = IO.pipe

      spawn do
        reader.read_next(from: pipe_out).should be_nil
      end

      SpecHelper.send(pipe_in, "Hello")
      SpecHelper.send(pipe_in, '\u{3}') # ctrl-c
      reader.editor.verify("")

      SpecHelper.send(pipe_in, '\0')
    end

    it "uses ctrl-d & ctrl-x" do
      reader = SpecHelper.reader
      pipe_out, pipe_in = IO.pipe

      spawn do
        reader.read_next(from: pipe_out).should be_nil
        reader.read_next(from: pipe_out).should be_nil
      end

      SpecHelper.send(pipe_in, "Hello")
      SpecHelper.send(pipe_in, '\u{4}') # ctrl-d

      SpecHelper.send(pipe_in, "World")
      SpecHelper.send(pipe_in, '\u{24}') # ctrl-x
    end

    it "uses ctrl-u & ctrl-k" do
      reader = SpecHelper.reader
      pipe_out, pipe_in = IO.pipe

      spawn do
        reader.read_next(from: pipe_out)
      end

      SpecHelper.send(pipe_in, <<-END)
        Lorem ipsum
        dolor sit
        amet.
        END
      SpecHelper.send(pipe_in, '\u0010') # ctrl-p (up)
      reader.editor.verify(x: 5, y: 1)

      SpecHelper.send(pipe_in, '\u000b') # ctrl-k (delete after)
      reader.editor.verify(<<-END, x: 5, y: 1)
        Lorem ipsum
        dolor
        amet.
        END

      SpecHelper.send(pipe_in, '\u000b') # ctrl-k (delete after)
      reader.editor.verify(<<-END, x: 5, y: 1)
        Lorem ipsum
        doloramet.
        END

      SpecHelper.send(pipe_in, '\u0015') # ctrl-u (delete before)
      reader.editor.verify(<<-END, x: 0, y: 1)
        Lorem ipsum
        amet.
        END

      SpecHelper.send(pipe_in, '\u000b') # ctrl-k (delete after)
      reader.editor.verify(<<-END, x: 0, y: 1)
        Lorem ipsum

        END
      SpecHelper.send(pipe_in, '\u0015') # ctrl-u (delete before)
      SpecHelper.send(pipe_in, '\u0015') # ctrl-u (delete before)
      reader.editor.verify("", x: 0, y: 0)

      SpecHelper.send(pipe_in, '\u000b') # ctrl-k (delete after)
      SpecHelper.send(pipe_in, '\u0015') # ctrl-u (delete before)
      reader.editor.verify("", x: 0, y: 0)
    end

    it "moves word forward" do
      reader = SpecHelper.reader
      pipe_out, pipe_in = IO.pipe

      spawn do
        reader.read_next(from: pipe_out)
      end

      SpecHelper.send(pipe_in, <<-END)
        lorem   ipsum
        +"dolor", sit:
        amet()
        END

      SpecHelper.send(pipe_in, '\u0001') # ctrl-a (move cursor to begin)
      reader.editor.verify(x: 0, y: 0)

      SpecHelper.send(pipe_in, "\ef") # Alt-f (move_word_forward)
      reader.editor.verify(x: 5, y: 0)

      SpecHelper.send(pipe_in, "\ef") # Alt-f (move_word_forward)
      reader.editor.verify(x: 13, y: 0)

      SpecHelper.send(pipe_in, "\e[1;5C") # Ctrl-right (move_word_forward)
      reader.editor.verify(x: 7, y: 1)

      SpecHelper.send(pipe_in, "\e[1;5C") # Ctrl-right (move_word_forward)
      reader.editor.verify(x: 13, y: 1)

      SpecHelper.send(pipe_in, "\e[1;5C") # Ctrl-right (move_word_forward)
      reader.editor.verify(x: 14, y: 1)

      SpecHelper.send(pipe_in, "\ef") # Alt-f (move_word_forward)
      reader.editor.verify(x: 4, y: 2)

      SpecHelper.send(pipe_in, "\ef") # Alt-f (move_word_forward)
      reader.editor.verify(x: 6, y: 2)

      SpecHelper.send(pipe_in, "\ef") # Alt-f (move_word_forward)
      reader.editor.verify(x: 6, y: 2)

      SpecHelper.send(pipe_in, "\0")
    end

    it "moves word backward" do
      reader = SpecHelper.reader
      pipe_out, pipe_in = IO.pipe

      spawn do
        reader.read_next(from: pipe_out)
      end

      SpecHelper.send(pipe_in, <<-END)
        lorem   ipsum
        +"dolor", sit:
        amet()
        END

      reader.editor.verify(x: 6, y: 2)

      SpecHelper.send(pipe_in, "\eb") # Alt-b (move_word_backward)
      reader.editor.verify(x: 0, y: 2)

      SpecHelper.send(pipe_in, "\eb") # Alt-b (move_word_backward)
      reader.editor.verify(x: 10, y: 1)

      SpecHelper.send(pipe_in, "\e[1;5D") # Ctrl-left (move_word_backward)
      reader.editor.verify(x: 2, y: 1)

      SpecHelper.send(pipe_in, "\e[1;5D") # Ctrl-left (move_word_backward)
      reader.editor.verify(x: 0, y: 1)

      SpecHelper.send(pipe_in, "\e[1;5D") # Ctrl-left (move_word_backward)
      reader.editor.verify(x: 8, y: 0)

      SpecHelper.send(pipe_in, "\eb") # Alt-b (move_word_backward)
      reader.editor.verify(x: 0, y: 0)

      SpecHelper.send(pipe_in, "\eb") # Alt-b (move_word_backward)
      reader.editor.verify(x: 0, y: 0)

      SpecHelper.send(pipe_in, "\0")
    end

    it "uses delete word and word back" do
      reader = SpecHelper.reader
      pipe_out, pipe_in = IO.pipe

      spawn do
        reader.read_next(from: pipe_out)
      end

      SpecHelper.send(pipe_in, <<-END)
        lorem   ipsum
        +"dolor", sit:
        amet()
        END

      SpecHelper.send(pipe_in, "\e[A") # up
      reader.editor.verify(x: 6, y: 1)

      SpecHelper.send(pipe_in, '\b') # Ctrl-backspace (delete_word)
      reader.editor.verify(<<-END, x: 2, y: 1)
        lorem   ipsum
        +"r", sit:
        amet()
        END

      SpecHelper.send(pipe_in, '\b') # Ctrl-backspace (delete_word)
      reader.editor.verify(<<-END, x: 0, y: 1)
        lorem   ipsum
        r", sit:
        amet()
        END

      SpecHelper.send(pipe_in, '\b') # Ctrl-backspace (delete_word)
      reader.editor.verify(<<-END, x: 8, y: 0)
        lorem   r", sit:
        amet()
        END

      SpecHelper.send(pipe_in, "\ed") # Alt-d (word_back)
      reader.editor.verify(<<-END, x: 8, y: 0)
        lorem   ", sit:
        amet()
        END

      SpecHelper.send(pipe_in, "\ed")     # Alt-d (word_back)
      SpecHelper.send(pipe_in, "\e[3;5~") # Ctrl-delete (word_back)
      SpecHelper.send(pipe_in, "\e[3;5~") # Ctrl-delete (word_back)
      reader.editor.verify(<<-END, x: 8, y: 0)
        lorem   ()
        END

      SpecHelper.send(pipe_in, '\b')       # Ctrl-backspace (delete_word)
      SpecHelper.send(pipe_in, "\e\u007f") # Alt-backspace (delete_word)
      reader.editor.verify(<<-END, x: 0, y: 0)
        ()
        END

      SpecHelper.send(pipe_in, "\ed") # Alt-d (word_back)
      SpecHelper.send(pipe_in, "\ed") # Alt-d (word_back)
      reader.editor.verify("", x: 0, y: 0)

      SpecHelper.send(pipe_in, "\0")
    end

    it "sets history to last after empty entry" do
      reader = SpecHelper.reader
      pipe_out, pipe_in = IO.pipe

      spawn do
        reader.read_next(from: pipe_out).should eq "a"
        reader.read_next(from: pipe_out).should eq "b"
        reader.read_next(from: pipe_out).should eq ""
        reader.read_next(from: pipe_out)
      end

      SpecHelper.send(pipe_in, 'a')
      SpecHelper.send(pipe_in, '\n')
      SpecHelper.send(pipe_in, 'b')
      SpecHelper.send(pipe_in, '\n')

      SpecHelper.send(pipe_in, "\e[A") # up
      reader.editor.verify("b")
      SpecHelper.send(pipe_in, "\e[A") # up
      reader.editor.verify("a")

      SpecHelper.send(pipe_in, "\u{7f}") # back
      SpecHelper.send(pipe_in, '\n')
      reader.editor.verify("")

      SpecHelper.send(pipe_in, "\e[A") # up
      reader.editor.verify("b")
      SpecHelper.send(pipe_in, "\e[A") # up
      reader.editor.verify("a")

      SpecHelper.send(pipe_in, '\0')
    end

    it "resets" do
      reader = SpecHelper.reader
      pipe_out, pipe_in = IO.pipe

      spawn do
        reader.read_next(from: pipe_out)
        reader.read_next(from: pipe_out)
      end

      SpecHelper.send(pipe_in, "Hello\nWorld")
      SpecHelper.send(pipe_in, '\n')
      reader.line_number.should eq 3

      reader.reset
      reader.line_number.should eq 1

      SpecHelper.send(pipe_in, '\0')
    end
  end
end
