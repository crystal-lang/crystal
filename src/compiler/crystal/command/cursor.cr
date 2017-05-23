# Implementation of commands that depend on the cursor location:
# `crystal tool implementations` and `crystal tool context`
#
# This is just the command-line part. The tools logic is in
# `crystal/tools/context.cr` and `crystal/tools/implementations.cr`

class Crystal::Command
  private def implementations
    cursor_command("tool implementations") do |location, config, result|
      result = ImplementationsVisitor.new(location).process(result)
    end
  end

  private def context
    cursor_command("tool context") do |location, config, result|
      result = ContextVisitor.new(location).process(result)
    end
  end

  private def expand
    cursor_command("tool expand", no_cleanup: true, wants_doc: true) do |location, config, result|
      result = ExpandVisitor.new(location).process(result)
    end
  end

  private def cursor_command(command, no_cleanup = false, wants_doc = false)
    config, result = compile_no_codegen command, cursor_command: true, no_cleanup: no_cleanup, wants_doc: wants_doc

    format = config.output_format

    file = ""
    line = ""
    col = ""

    loc = config.cursor_location.not_nil!.split(':')
    if loc.size != 3
      error "cursor location must be file:line:column"
    end

    file, line, col = loc

    line_number = line.to_i? || 0
    if line_number <= 0
      error "line must be a positive integer, not #{line}"
    end

    column_number = col.to_i? || 0
    if column_number <= 0
      error "column must be a positive integer, not #{col}"
    end

    file = File.expand_path(file)

    result = @progress_tracker.stage("Tool (#{command.split(' ')[1]})") do
      yield Location.new(file, line_number, column_number), config, result
    end

    case format
    when "json"
      result.to_json(STDOUT)
    else
      result.to_text(STDOUT)
    end
  end
end
