require "../spec_helper"

private ANSI_ESCAPE = /\e\[[0-9;]*m/

private def strip_diagnostic_ansi(value : String) : String
  value.gsub(ANSI_ESCAPE, "")
end

private def normalize_colored_line_markers(value : String) : String
  value.gsub(/^ > (?=[1-3] \|)/m, "   ")
end

private def render_diagnostic(error : Crystal::CodeError, color : Bool) : String
  error.color = color
  error.to_s
end

private def capture_type_error(code : String, *, filename = nil) : Crystal::TypeException
  expect_raises(Crystal::TypeException) do
    semantic(code, filename: filename)
  end
end

describe "compiler diagnostic syntax highlighting" do
  it "fails open when diagnostic highlight spans are invalid" do
    text = "answer = 42"
    invalid_highlights = [
      [Crystal::DiagnosticMessage::Highlight.new(-1, 1, :syntax)],
      [Crystal::DiagnosticMessage::Highlight.new(0, -1, :syntax)],
      [Crystal::DiagnosticMessage::Highlight.new(text.bytesize + 1, 0, :syntax)],
      [Crystal::DiagnosticMessage::Highlight.new(text.bytesize - 1, 2, :syntax)],
      [
        Crystal::DiagnosticMessage::Highlight.new(5, 1, :syntax),
        Crystal::DiagnosticMessage::Highlight.new(3, 1, :syntax),
      ],
      [
        Crystal::DiagnosticMessage::Highlight.new(0, 6, :syntax),
        Crystal::DiagnosticMessage::Highlight.new(5, 1, :syntax),
      ],
    ]

    invalid_highlights.each do |highlights|
      Crystal::DiagnosticMessage.new(text, highlights).render(true).should eq(text)
    end
  end

  it "fails open when numbered source metadata is inconsistent" do
    source = "answer = 42"
    numbered_source = Crystal.with_line_numbers(source)
    invalid_highlights = [
      Crystal::DiagnosticMessage::Highlight.new(
        0,
        numbered_source.bytesize,
        :blue,
        numbered_source: source
      ),
      Crystal::DiagnosticMessage::Highlight.new(
        0,
        numbered_source.bytesize,
        :syntax,
        numbered_source: "different = 1"
      ),
    ]

    invalid_highlights.each do |highlight|
      Crystal::DiagnosticMessage.new(numbered_source, [highlight]).render(true).should eq(numbered_source)
    end
  end

  it "renders non-syntax spans without changing plain text" do
    text = "first second"
    message = Crystal::DiagnosticMessage.new(text, [
      Crystal::DiagnosticMessage::Highlight.new(0, 5, :blue),
      Crystal::DiagnosticMessage::Highlight.new(6, 6, :yellow_bold),
    ])

    message.render(false).should eq(text)
    message.render(true).should eq("\e[34mfirst\e[39m \e[33;1msecond\e[39;22m")
  end

  it "highlights raw source before adding line numbers" do
    source = <<-CRYSTAL
      text = <<-TEXT
        hello
      TEXT
      answer = 42
      CRYSTAL
    numbered_source = Crystal.with_line_numbers(source)
    highlight = Crystal::DiagnosticMessage::Highlight.new(
      0,
      numbered_source.bytesize,
      :syntax,
      numbered_source: source
    )
    message = Crystal::DiagnosticMessage.new(numbered_source, [highlight])

    highlighted = message.render(true)

    strip_diagnostic_ansi(highlighted).should eq(numbered_source)
    highlighted.should contain("\e[93m  hello\e[39m")
    highlighted.should contain("\e[93mTEXT\e[39m")
    highlighted.should contain("answer \e[91m=\e[39m \e[35m42\e[39m")
  end

  it "highlights overload signatures without changing the raw message or JSON" do
    error = capture_type_error <<-CRYSTAL
      class Widget
        def convert(value : Int32 | Float64)
        end

        def convert(value : String)
        end
      end

      Widget.new.convert(true)
      CRYSTAL

    raw_message = error.message.should_not be_nil
    raw_message.should contain("Widget#convert(value : Int32 | Float64)")
    raw_message.should_not contain("\e[")
    error.to_json.should_not contain("\e[")

    plain = render_diagnostic(error, false)
    highlighted = render_diagnostic(error, true)

    strip_diagnostic_ansi(highlighted).should eq(plain)
    highlighted.should contain("\e[36mWidget\e[39m#convert(value : \e[36mInt32\e[39m \e[91m|\e[39m \e[36mFloat64\e[39m)")
    highlighted.should_not contain("\e[90m#convert")
  end

  it "highlights top-level overload signatures" do
    error = capture_type_error <<-CRYSTAL
      def diagnostic_convert(value : Int32)
      end

      def diagnostic_convert(value : String)
      end

      diagnostic_convert(true)
      CRYSTAL

    highlighted = render_diagnostic(error, true)

    highlighted.should contain("diagnostic_convert(value : \e[36mInt32\e[39m)")
    highlighted.should_not contain("\e[90m")
  end

  it "highlights ordinary source excerpts using the surrounding lexical context" do
    source = <<-CRYSTAL
      text = <<-TEXT
        total: 42
      TEXT
      answer = 42 + "two"
      CRYSTAL

    with_tempfile("diagnostic-source.cr") do |path|
      File.write(path, source)

      error = Crystal::TypeException.new("incompatible values", 4, 1, path, 6)
      plain = render_diagnostic(error, false)
      highlighted = render_diagnostic(error, true)

      strip_diagnostic_ansi(highlighted).should eq(plain)
      highlighted.should contain("\e[35m42\e[39m")
      highlighted.should contain(%(\e[93m"two"\e[39m))

      contextual_error = Crystal::TypeException.new("incompatible values", 2, 3, path, 5)
      contextual = render_diagnostic(contextual_error, true)

      contextual.should contain("\e[93mtotal: 42\e[39m")
      contextual.should_not contain("total: \e[35m42\e[39m")
    end
  end

  it "highlights macro definitions and multiline expansions without coloring line numbers as source" do
    definition = <<-CRYSTAL
      macro broken
        nil
      end

      broken
      CRYSTAL
    expansion = <<-CRYSTAL
      text = <<-TEXT
        hello
      TEXT
      answer = 42
      CRYSTAL

    with_tempfile("diagnostic-macro.cr") do |path|
      File.write(path, definition)
      a_macro = Crystal::Macro.new("broken").at(Crystal::Location.new(path, 1, 1)).as(Crystal::Macro)
      virtual_file = Crystal::VirtualFile.new(a_macro, expansion, Crystal::Location.new(path, 5, 1))
      error = Crystal::TypeException.new("bad expansion", 4, 10, virtual_file, 2)

      plain = render_diagnostic(error, false)
      highlighted = render_diagnostic(error, true)

      normalize_colored_line_markers(strip_diagnostic_ansi(highlighted)).should eq(plain)
      highlighted.should contain("Called macro defined in")
      highlighted.should contain("Which expanded to:")
      highlighted.should contain("\e[91mmacro\e[39m broken")
      highlighted.should contain("answer \e[91m=\e[39m \e[35m42\e[39m")
      highlighted.should contain("\e[93m  hello\e[39m")
      highlighted.should contain("\e[93mTEXT\e[39m")
      highlighted.should match(/\e\[39m\n(?:\e\[2m)? > 3 \| (?:\e\[22m)?\e\[93m/)
    end
  end

  it "uses surrounding lexical context for macro definition locations" do
    definition = <<-CRYSTAL
      text = <<-TEXT
        macro broken
      TEXT
      CRYSTAL

    with_tempfile("diagnostic-contextual-macro.cr") do |path|
      File.write(path, definition)
      a_macro = Crystal::Macro.new("broken").at(Crystal::Location.new(path, 2, 3)).as(Crystal::Macro)
      virtual_file = Crystal::VirtualFile.new(a_macro, "nil", Crystal::Location.new(path, 1, 1))
      error = Crystal::TypeException.new("bad expansion", 1, 1, virtual_file, 1)

      highlighted = render_diagnostic(error, true)

      highlighted.should contain("\e[93mmacro broken\e[39m")
      highlighted.should_not contain("\e[91mmacro\e[39m broken")
    end
  end

  it "bounds highlighted macro expansions without losing multiline context" do
    definition = <<-CRYSTAL
      macro broken
        nil
      end

      broken
      CRYSTAL
    expansion_lines = [
      "text = <<-TEXT",
      "  hello",
      "  world",
      "TEXT",
    ]
    expansion_lines.concat(Array.new(5_001, %(unterminated = ")))
    expansion = expansion_lines.join('\n')

    with_tempfile("diagnostic-bounded-macro.cr") do |path|
      File.write(path, definition)
      a_macro = Crystal::Macro.new("broken").at(Crystal::Location.new(path, 1, 1)).as(Crystal::Macro)
      virtual_file = Crystal::VirtualFile.new(a_macro, expansion, Crystal::Location.new(path, 5, 1))
      error = Crystal::TypeException.new("bad expansion", 3, 3, virtual_file, 2)
      error.error_trace = false

      highlighted = render_diagnostic(error, true)

      highlighted.should contain("\e[93m  hello\e[39m")
      highlighted.should contain("\e[93m  world\e[39m")
      highlighted.should_not contain("unterminated")
    end
  end

  it "highlights source excerpts in specialized method and nil traces" do
    source = %(answer = 42 + "two"\n)

    with_tempfile("diagnostic-trace.cr") do |path|
      File.write(path, source)
      node = parse(source, filename: path)
      method_error = Crystal::MethodTraceException.new(nil, [node] of Crystal::ASTNode, nil, true)
      nil_reason = Crystal::NilReason.new("@answer", :used_before_initialized, [node] of Crystal::ASTNode)
      nil_error = Crystal::MethodTraceException.new(nil, [] of Crystal::ASTNode, nil_reason, true)

      {method_error, nil_error}.each do |error|
        plain = render_diagnostic(error, false)
        highlighted = render_diagnostic(error, true)

        strip_diagnostic_ansi(highlighted).should eq(plain)
        highlighted.should contain("\e[35m42\e[39m")
        highlighted.should contain(%(\e[93m"two"\e[39m))
      end
    end
  end

  it "uses surrounding lexical context in specialized method and nil traces" do
    source = <<-CRYSTAL
      text = <<-TEXT
        total: 42
      TEXT
      CRYSTAL

    with_tempfile("diagnostic-contextual-trace.cr") do |path|
      File.write(path, source)
      location = Crystal::Location.new(path, 2, 3)
      node = Crystal::NumberLiteral.new("42").at(location).as(Crystal::ASTNode)
      method_error = Crystal::MethodTraceException.new(nil, [node], nil, true)
      nil_reason = Crystal::NilReason.new("@answer", :used_before_initialized, [node])
      nil_error = Crystal::MethodTraceException.new(nil, [] of Crystal::ASTNode, nil_reason, true)

      {method_error, nil_error}.each do |error|
        highlighted = render_diagnostic(error, true)
        highlighted.should contain("\e[93m  total: 42\e[39m")
        highlighted.should_not contain("total: \e[35m42\e[39m")
      end
    end
  end

  it "highlights every ordinary source frame in a nested semantic trace" do
    source = <<-CRYSTAL
      def inner(value : Int32)
      end

      def outer(flag : Bool)
        inner("bad")
      end

      outer(true)
      CRYSTAL

    with_tempfile("diagnostic-nested-trace.cr") do |path|
      File.write(path, source)
      error = capture_type_error(source, filename: path)
      error.error_trace = true

      plain = render_diagnostic(error, false)
      highlighted = render_diagnostic(error, true)

      strip_diagnostic_ansi(highlighted).should eq(plain)
      highlighted.should contain(%(inner(\e[93m"bad"\e[39m)))
      highlighted.should contain("outer(\e[35mtrue\e[39m)")
    end
  end

  it "highlights syntax-error source excerpts" do
    source = "answer = 42; end\n"

    with_tempfile("diagnostic-syntax-error.cr") do |path|
      File.write(path, source)
      error = expect_raises(Crystal::SyntaxException) do
        parse(source, filename: path)
      end

      plain = render_diagnostic(error, false)
      highlighted = render_diagnostic(error, true)

      strip_diagnostic_ansi(highlighted).should eq(plain)
      highlighted.should contain("\e[35m42\e[39m")
      highlighted.should contain("\e[91mend\e[39m")
    end
  end

  it "highlights specialized method_missing expansions while keeping serialization ANSI-free" do
    error = capture_type_error <<-CRYSTAL
      class Widget
        macro method_missing(call)
          def other
            text = <<-TEXT
              hello
            TEXT
            42
          end
        end
      end

      Widget.new.missing
      CRYSTAL

    raw_message = error.message.should_not be_nil
    raw_message.should contain("The method_missing macro expanded to:")
    raw_message.should_not contain("\e[")
    error.to_json.should_not contain("\e[")

    plain = render_diagnostic(error, false)
    highlighted = render_diagnostic(error, true)

    strip_diagnostic_ansi(highlighted).should eq(plain)
    highlighted.should contain("\e[91mdef\e[39m \e[92mother\e[39m")
    highlighted.should match(/\e\[93m\s+hello\e\[39m/)
    highlighted.should match(/\e\[93m\s*TEXT\e\[39m/)
    highlighted.should contain("\e[35m42\e[39m")
    highlighted.should contain("\e[91mend\e[39m")
  end
end
