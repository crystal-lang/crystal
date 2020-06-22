class Crystal::Program
  # Temporary files which are generated by macro runs that need to be
  # deleted after the compilation is finished.
  getter tempfiles = [] of String

  # Returns a `MacroExpander` to expand macro code into crystal code.
  getter(macro_expander) { MacroExpander.new self }

  # A cache of compiled "macro run" files.
  # The keys are filenames that were compiled, the values are executable
  # filenames ready to be run (so they don't need to be compiled twice),
  # together with the time it took to compile them and whether a previous
  # compilation was reused.
  # The elapsed time is only needed for stats.
  record CompiledMacroRun, filename : String, elapsed : Time::Span, reused : Bool
  property compiled_macros_cache = {} of String => CompiledMacroRun

  def expand_macro(a_macro : Macro, call : Call, scope : Type, path_lookup : Type? = nil, a_def : Def? = nil)
    check_call_to_deprecated_macro a_macro, call

    interpreter = MacroInterpreter.new self, scope, path_lookup || scope, a_macro, call, a_def, in_macro: true
    a_macro.body.accept interpreter
    {interpreter.to_s, interpreter.macro_expansion_pragmas}
  end

  def expand_macro(node : ASTNode, scope : Type, path_lookup : Type? = nil, free_vars = nil, a_def : Def? = nil)
    interpreter = MacroInterpreter.new self, scope, path_lookup || scope, node.location, def: a_def, in_macro: false
    interpreter.free_vars = free_vars
    node.accept interpreter
    {interpreter.to_s, interpreter.macro_expansion_pragmas}
  end

  def parse_macro_source(generated_source, macro_expansion_pragmas, the_macro, node, vars, current_def = nil, inside_type = false, inside_exp = false, mode : Parser::ParseMode = :normal, visibility : Visibility = :public)
    parse_macro_source generated_source, macro_expansion_pragmas, the_macro, node, vars, current_def, inside_type, inside_exp, visibility, &.parse(mode)
  end

  def parse_macro_source(generated_source, macro_expansion_pragmas, the_macro, node, vars, current_def = nil, inside_type = false, inside_exp = false, visibility : Visibility = :public)
    begin
      parser = Parser.new(generated_source, @program.string_pool, [vars.dup])
      parser.filename = VirtualFile.new(the_macro, generated_source, node.location)
      parser.macro_expansion_pragmas = macro_expansion_pragmas
      parser.visibility = visibility
      parser.def_nest = 1 if current_def && !current_def.is_a?(External)
      parser.fun_nest = 1 if current_def && current_def.is_a?(External)
      parser.type_nest = 1 if inside_type
      parser.wants_doc = @program.wants_doc?
      generated_node = yield parser
      normalize(generated_node, inside_exp: inside_exp, current_def: current_def)
    end
  end

  record MacroRunResult, stdout : String, stderr : String, status : Process::Status

  def macro_run(filename, args)
    compiled_macro_run = @compiled_macros_cache[filename] ||= macro_compile(filename)
    compiled_file = compiled_macro_run.filename

    out_io = IO::Memory.new
    err_io = IO::Memory.new
    Process.run(compiled_file, args: args, output: out_io, error: err_io)
    MacroRunResult.new(out_io.to_s, err_io.to_s, $?)
  end

  record RequireWithTimestamp, filename : String, epoch : Int64 do
    include JSON::Serializable
  end

  def macro_compile(filename)
    time = Time.monotonic

    source = File.read(filename)

    # We store the executable relative to the cache directory for 'filename',
    # that way if it's already there from a previous compilation, and no file
    # that this program uses changes, we can simply avoid recompiling it again
    #
    # NOTE: it could happen that a macro run program runs macros that could
    # change the program behaviour even if files don't change, but this is
    # discouraged (and we should strongly document it) because it prevents
    # incremental compiles.
    program_dir = CacheDir.instance.directory_for(filename)
    executable_path = File.join(program_dir, "macro_run")
    recorded_requires_path = File.join(program_dir, "recorded_requires")
    requires_path = File.join(program_dir, "requires")

    {% unless flag?(:win32) %}
      # First, update times for the program dir, so it remains in the cache longer
      # (this is specially useful if a macro run program is used by multiple programs)
      now = Time.utc
      File.utime(now, now, program_dir)
    {% end %}

    if can_reuse_previous_compilation?(filename, executable_path, recorded_requires_path, requires_path)
      elapsed_time = Time.monotonic - time
      return CompiledMacroRun.new(executable_path, elapsed_time, true)
    end

    compiler = Compiler.new

    # Although release takes longer, once the bc is cached in .crystal
    # the subsequent times will make program execution faster.
    compiler.release = true

    # Don't cleanup old directories after compiling: it might happen
    # that in doing so we remove the directory associated with the current
    # compilation (for example if we have more than 10 macro runs, the current
    # directory will be the oldest).
    compiler.cleanup = false

    # No need to generate debug info for macro run programs
    compiler.debug = Crystal::Debug::None

    result = compiler.compile Compiler::Source.new(filename, source), executable_path

    # Write the new files from which 'filename' depends into the cache dir
    # (here we store how to obtain these files, because a require might use
    # '/*' or '/**' and we need to recompile if a file is added or removed)
    File.open(recorded_requires_path, "w") do |file|
      result.program.recorded_requires.to_json(file)
    end

    # Together with their timestamp
    # (this is the list of all effective files that were required)
    requires_with_timestamps = result.program.requires.map do |required_file|
      epoch = File.info(required_file).modification_time.to_unix
      RequireWithTimestamp.new(required_file, epoch)
    end

    File.open(requires_path, "w") do |file|
      requires_with_timestamps.to_json(file)
    end

    elapsed_time = Time.monotonic - time
    CompiledMacroRun.new(executable_path, elapsed_time, false)
  end

  private def can_reuse_previous_compilation?(filename, executable_path, recorded_requires_path, requires_path)
    return false unless File.exists?(executable_path)
    return false unless File.exists?(recorded_requires_path)
    return false unless File.exists?(requires_path)

    recorded_requires =
      begin
        Array(Program::RecordedRequire).from_json(File.read(recorded_requires_path))
      rescue JSON::Error
        return false
      end

    requires_with_timestamps =
      begin
        Array(RequireWithTimestamp).from_json(File.read(requires_path))
      rescue JSON::Error
        return false
      end

    # From the recorded requires we reconstruct the effective required files.
    # We start with the target filename
    required_files = Set{filename}
    recorded_requires.map do |recorded_require|
      begin
        files = @program.find_in_path(recorded_require.filename, recorded_require.relative_to)
        required_files.concat(files) if files
      rescue Crystal::CrystalPath::NotFoundError
        # Maybe the file is gone
        next
      end
    end

    new_requires_with_timestamps = required_files.map do |required_file|
      epoch = File.info(required_file).modification_time.to_unix
      RequireWithTimestamp.new(required_file, epoch)
    end

    # Quick check: if there are a different number of files, something changed
    if requires_with_timestamps.size != new_requires_with_timestamps.size
      return false
    end

    # Sort both requires and check if they are the same
    requires_with_timestamps.sort_by! &.filename
    new_requires_with_timestamps.sort_by! &.filename
    requires_with_timestamps == new_requires_with_timestamps
  end
end
