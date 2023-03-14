# Implementation of commands that depend on the cursor location:
# `crystal tool implementations` and `crystal tool context`
#
# This is just the command-line part. The tools logic is in
# `crystal/tools/context.cr` and `crystal/tools/implementations.cr`

class Crystal::Command
  private def implementations
    cursor_command("tool implementations") do |location, config, result|
      ImplementationsVisitor.new(location).process(result)
    end
  end

  private def context
    cursor_command("tool context") do |location, config, result|
      ContextVisitor.new(location).process(result)
    end
  end

  private def expand
    cursor_command("tool expand", no_cleanup: true, wants_doc: true) do |location, config, result|
      ExpandVisitor.new(location).process(result)
    end
  end

  private def cursor_command(command, no_cleanup = false, wants_doc = false, &)
    config, result = compile_no_codegen command,
      cursor_command: true,
      no_cleanup: no_cleanup,
      wants_doc: wants_doc

    format = config.output_format

    begin
      loc = Location.parse(config.cursor_location.not_nil!, expand: true)
    rescue ex : ArgumentError
      error ex.message
    end

    result = @progress_tracker.stage("Tool (#{command.split(' ')[1]})") do
      yield loc, config, result
    end

    case format
    when "json"
      result.to_json(STDOUT)
    else
      result.to_text(STDOUT)
    end
  end
end
