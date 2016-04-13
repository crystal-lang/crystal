require "json"
require "./command/*"

class Crystal::Command
  USAGE = <<-USAGE
    Usage: crystal [command] [switches] [program file] [--] [arguments]

    Command:
        init                     generate a new project
        build                    compile program
        deps                     install project dependencies
        docs                     generate documentation
        env                      print Crystal environment information
        eval                     eval code from args or standard input
        play                     starts crystal playground server
        run (default)            compile and run program
        spec                     compile and run specs (in spec directory)
        tool                     run a tool
        help, --help, -h         show this help
        version, --version, -v   show version
    USAGE

  COMMANDS_USAGE = <<-USAGE
    Usage: crystal tool [tool] [switches] [program file] [--] [arguments]

    Tool:
        context                  show context for given location
        format                   format project, directories and/or files
        hierarchy                show type hierarchy
        implementations          show implementations for given call in location
        types                    show type of main variables
        --help, -h               show this help
    USAGE

  VALID_EMIT_VALUES = %w(asm llvm-bc llvm-ir obj)

  def self.run(options = ARGV)
    new(options).run
  end

  private getter options

  def initialize(@options : Array(String))
    @color = true
  end

  def run
    command = options.first?

    if command
      case
      when "init".starts_with?(command)
        options.shift
        init
      when "build".starts_with?(command)
        options.shift
        build
      when "play".starts_with?(command)
        options.shift
        playground
      when "deps".starts_with?(command)
        options.shift
        deps
      when "docs".starts_with?(command)
        options.shift
        docs
      when command == "env"
        options.shift
        env
      when command == "eval"
        options.shift
        eval
      when "run".starts_with?(command)
        options.shift
        run_command
      when "spec/".starts_with?(command)
        options.shift
        run_specs
      when "tool".starts_with?(command)
        options.shift
        tool
      when "help".starts_with?(command), "--help" == command, "-h" == command
        puts USAGE
        exit
      when "version".starts_with?(command), "--version" == command, "-v" == command
        puts "Crystal #{Crystal.version_string}"
        exit
      else
        if File.file?(command)
          run_command
        else
          error "unknown command: #{command}"
        end
      end
    else
      puts USAGE
      exit
    end
  rescue ex : Crystal::Exception
    ex.color = @color
    if @config.try(&.output_format) == "json"
      puts ex.to_json
    else
      puts ex
    end
    exit 1
  rescue ex : OptionParser::Exception
    error ex.message
  rescue ex
    puts ex
    ex.backtrace.each do |frame|
      puts frame
    end
    puts
    error "you've found a bug in the Crystal compiler. Please open an issue, including source code that will allow us to reproduce the bug: https://github.com/crystal-lang/crystal/issues"
  end

  private def tool
    tool = options.first?
    if tool
      case
      when "context".starts_with?(tool)
        options.shift
        context
      when "format".starts_with?(tool)
        options.shift
        format
      when "hierarchy".starts_with?(tool)
        options.shift
        hierarchy
      when "implementations".starts_with?(tool)
        options.shift
        implementations
      when "types".starts_with?(tool)
        options.shift
        types
      when "--help" == tool, "-h" == tool
        puts COMMANDS_USAGE
        exit
      else
        error "unknown tool: #{tool}"
      end
    else
      puts COMMANDS_USAGE
      exit
    end
  end

  private def init
    Init.run(options)
  end

  private def build
    config = create_compiler "build"
    config.compile
  end

  private def env
    if ARGV.size == 1 && {"--help", "-h"}.includes?(ARGV[0])
      puts <<-USAGE
      Usage: crystal env [var ...]

      Prints Crystal environment information.

      By default it prints information as a shell script.
      If one or more variable names is given as arguments,
      it prints the value of each named variable on its own line.
      USAGE

      exit
    end

    vars = {
      "CRYSTAL_PATH":    CrystalPath::DEFAULT_PATH,
      "CRYSTAL_VERSION": Config::VERSION || "",
    }

    if ARGV.empty?
      vars.each do |key, value|
        puts "#{key}=#{value.inspect}"
      end
    else
      ARGV.each do |key|
        puts vars[key]?
      end
    end
  end

  private def eval
    if options.empty?
      program_source = STDIN.gets_to_end
      program_args = [] of String
    else
      double_dash_index = options.index("--")
      if double_dash_index
        program_source = options[0...double_dash_index].join " "
        program_args = options[double_dash_index + 1..-1]
      else
        program_source = options.join " "
        program_args = [] of String
      end
    end

    compiler = Compiler.new
    sources = [Compiler::Source.new("eval", program_source)]

    output_filename = tempfile "eval"

    result = compiler.compile sources, output_filename
    execute output_filename, program_args
  end

  private def hierarchy
    config, result = compile_no_codegen "tool hierarchy", hierarchy: true
    Crystal.print_hierarchy result.program, config.hierarchy_exp
  end

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

  private def cursor_command(command)
    config, result = compile_no_codegen command, cursor_command: true

    format = config.output_format

    file = ""
    line = ""
    col = ""

    loc = config.cursor_location.not_nil!.split(':')
    if loc.size == 3
      file, line, col = loc
    end

    file = File.expand_path(file)

    result = yield Location.new(line.to_i, col.to_i, file), config, result

    case format
    when "json"
      result.to_json(STDOUT)
    else
      result.to_text(STDOUT)
    end
  end

  private def run_command
    config = create_compiler "run", run: true
    if config.specified_output
      config.compile
      return
    end

    output_filename = tempfile(config.output_filename)

    result = config.compile output_filename
    execute output_filename, config.arguments unless config.compiler.no_codegen?
  end

  private def run_specs
    # Assume spec files end with ".cr" and optionally with a colon and a number
    # (for the target line number). Everything else is an option we forward.
    filenames = options.select { |option| option =~ /\.cr(\:\d+)?\Z/ }
    options.reject! { |option| filenames.includes?(option) }

    locations = [] of {String, String}

    if filenames.empty?
      target_filenames = Dir["spec/**/*_spec.cr"]
    else
      target_filenames = [] of String
      filenames.each do |filename|
        if filename =~ /\A(.+?)\:(\d+)\Z/
          file, line = $1, $2
          unless File.file?(file)
            error "'#{file}' is not a file"
          end
          target_filenames << file
          locations << {file, line}
        else
          if Dir.exists?(filename)
            target_filenames.concat Dir["#{filename}/**/*_spec.cr"]
          elsif File.file?(filename)
            target_filenames << filename
          else
            error "'#{filename}' is not a file"
          end
        end
      end
    end

    if target_filenames.size == 1
      if locations.size == 1
        # This is in case other spec runners use `-l`, we keep compatibility
        options << "-l" << locations.first[1]
      end
    else
      locations.each do |loc|
        options << "--location" << "#{loc[0]}:#{loc[1]}"
      end
    end

    source = target_filenames.map { |filename| %(require "./#{filename}") }.join("\n")
    sources = [Compiler::Source.new("spec", source)]

    output_filename = tempfile "spec"

    compiler = Compiler.new
    result = compiler.compile sources, output_filename
    execute output_filename, options
  end

  private def deps
    path_to_shards = `which shards`.chomp
    if path_to_shards.empty?
      error "`shards` executable is missing. Please install shards: https://github.com/ysbaddaden/shards"
    end

    status = Process.run(path_to_shards, args: options, output: true, error: true)
    exit status.exit_code unless status.success?
  end

  private def docs
    if options.empty?
      sources = [Compiler::Source.new("require", %(require "./src/**"))]
      included_dirs = [] of String
    else
      filenames = options
      sources = gather_sources(filenames)
      included_dirs = sources.map { |source| File.dirname(source.filename) }
    end

    included_dirs << File.expand_path("./src")

    output_filename = tempfile "docs"

    compiler = Compiler.new
    compiler.wants_doc = true
    result = compiler.compile sources, output_filename
    Crystal.generate_docs result.program, included_dirs
  end

  private def types
    config, result = compile_no_codegen "tool types"
    Crystal.print_types result.original_node
  end

  private def playground
    server = Playground::Server.new

    OptionParser.parse(options) do |opts|
      opts.banner = "Usage: crystal play [options] [file]\n\nOptions:"

      opts.on("-p PORT", "--port PORT", "Runs the playground on the specified port") do |port|
        server.port = port.to_i
      end

      opts.on("-b HOST", "--binding HOST", "Binds the playground to the specified IP") do |host|
        server.host = host
      end

      opts.on("-v", "--verbose", "Display detailed information of executed code") do
        server.logger.level = Logger::Severity::DEBUG
      end

      opts.on("-h", "--help", "Show this message") do
        puts opts
        exit 1
      end

      opts.unknown_args do |before, after|
        if before.size > 0
          server.source = gather_sources([before.first]).first
        end
      end
    end

    server.start
  end

  private def compile_no_codegen(command, wants_doc = false, hierarchy = false, cursor_command = false)
    config = create_compiler command, no_codegen: true, hierarchy: hierarchy, cursor_command: cursor_command
    config.compiler.no_codegen = true
    config.compiler.wants_doc = wants_doc
    {config, config.compile}
  end

  private def execute(output_filename, run_args)
    begin
      Process.run(output_filename, args: run_args, input: true, output: true, error: true) do |process|
        Signal::INT.trap do
          process.kill
          exit
        end
      end
      status = $?
    ensure
      File.delete output_filename
    end

    if status.normal_exit?
      exit status.exit_code
    else
      case status.exit_signal
      when Signal::KILL
        STDERR.puts "Program was killed"
      when Signal::SEGV
        STDERR.puts "Program exited because of a segmentation fault (11)"
      else
        STDERR.puts "Program received and didn't handle signal #{status.exit_signal} (#{status.exit_signal.value})"
      end

      exit 1
    end
  end

  private def tempfile(basename)
    Crystal.tempfile(basename)
  end

  record(CompilerConfig,
    compiler : Compiler,
    sources : Array(Compiler::Source),
    output_filename : String,
    original_output_filename : String,
    arguments : Array(String),
    specified_output : Bool,
    hierarchy_exp : String?,
    cursor_location : String?,
    output_format : String?) do
    def compile(output_filename = self.output_filename)
      compiler.original_output_filename = original_output_filename
      compiler.compile sources, output_filename
    end
  end

  private def create_compiler(command, no_codegen = false, run = false, hierarchy = false, cursor_command = false)
    compiler = Compiler.new
    link_flags = [] of String
    opt_filenames = nil
    opt_arguments = nil
    opt_output_filename = nil
    specified_output = false
    hierarchy_exp = nil
    cursor_location = nil
    output_format = nil

    option_parser = OptionParser.parse(options) do |opts|
      opts.banner = "Usage: crystal #{command} [options] [programfile] [--] [arguments]\n\nOptions:"

      unless no_codegen
        unless run
          opts.on("--cross-compile flags", "cross-compile") do |cross_compile|
            compiler.cross_compile_flags = cross_compile
          end
        end
        opts.on("-d", "--debug", "Add symbolic debug info") do
          compiler.debug = true
        end
      end

      opts.on("-D FLAG", "--define FLAG", "Define a compile-time flag") do |flag|
        compiler.add_flag flag
      end

      unless no_codegen
        opts.on("--emit [#{VALID_EMIT_VALUES.join("|")}]", "Comma separated list of types of output for the compiler to emit") do |emit_values|
          compiler.emit = validate_emit_values(emit_values.split(',').map(&.strip))
        end
      end

      if hierarchy
        opts.on("-e NAME", "Filter types by NAME regex") do |exp|
          hierarchy_exp = exp
        end
      end

      if cursor_command
        opts.on("-c LOC", "--cursor LOC", "Cursor location with LOC as path/to/file.cr:line:column") do |cursor|
          cursor_location = cursor
        end
      end

      opts.on("-f text|json", "--format text|json", "Output format text (default) or json") do |f|
        output_format = f
      end

      opts.on("-h", "--help", "Show this message") do
        puts opts
        exit 1
      end

      unless no_codegen
        opts.on("--ll", "Dump ll to .crystal directory") do
          compiler.dump_ll = true
        end
        opts.on("--link-flags FLAGS", "Additional flags to pass to the linker") do |some_link_flags|
          link_flags << some_link_flags
        end
        opts.on("--mcpu CPU", "Target specific cpu type") do |cpu|
          compiler.mcpu = cpu
        end
      end

      opts.on("--no-color", "Disable colored output") do
        @color = false
        compiler.color = false
      end

      unless no_codegen
        opts.on("--no-codegen", "Don't do code generation") do
          compiler.no_codegen = true
        end
        opts.on("-o ", "Output filename") do |an_output_filename|
          opt_output_filename = an_output_filename
          specified_output = true
        end
      end

      opts.on("--prelude ", "Use given file as prelude") do |prelude|
        compiler.prelude = prelude
      end

      unless no_codegen
        opts.on("--release", "Compile in release mode") do
          compiler.release = true
        end
        opts.on("-s", "--stats", "Enable statistics output") do
          compiler.stats = true
        end
        opts.on("--single-module", "Generate a single LLVM module") do
          compiler.single_module = true
        end
        opts.on("--threads ", "Maximum number of threads to use") do |n_threads|
          compiler.n_threads = n_threads.to_i
        end
        unless run
          opts.on("--target TRIPLE", "Target triple") do |triple|
            compiler.target_triple = triple
          end
        end
        opts.on("--verbose", "Display executed commands") do
          compiler.verbose = true
        end
      end

      opts.unknown_args do |before, after|
        opt_filenames = before
        opt_arguments = after
      end
    end

    compiler.link_flags = link_flags.join(" ") unless link_flags.empty?

    output_filename = opt_output_filename
    filenames = opt_filenames.not_nil!
    arguments = opt_arguments.not_nil!

    if filenames.size == 0 || (cursor_command && cursor_location.nil?)
      puts option_parser
      exit 1
    end

    sources = gather_sources(filenames)
    first_filename = sources.first.filename
    first_file_ext = File.extname(first_filename)
    original_output_filename = File.basename(first_filename, first_file_ext)

    # Check if we'll overwrite the main source file
    if first_file_ext.empty? && !output_filename && !no_codegen && !run && first_filename == File.expand_path(original_output_filename)
      error "compilation will overwrite source file '#{Crystal.relative_filename(first_filename)}', either change its extension to '.cr' or specify an output file with '-o'"
    end

    output_filename ||= original_output_filename
    output_format ||= "text"

    if !no_codegen && !run && Dir.exists?(output_filename)
      error "can't use `#{output_filename}` as output filename because it's a directory"
    end

    @config = CompilerConfig.new compiler, sources, output_filename, original_output_filename, arguments, specified_output, hierarchy_exp, cursor_location, output_format
  end

  private def gather_sources(filenames)
    filenames.map do |filename|
      unless File.file?(filename)
        error "File #{filename} does not exist"
      end
      filename = File.expand_path(filename)
      Compiler::Source.new(filename, File.read(filename))
    end
  end

  private def validate_emit_values(values)
    values.each do |value|
      unless VALID_EMIT_VALUES.includes?(value)
        error "invalid emit value '#{value}'"
      end
    end
    values
  end

  private def error(msg, exit_code = 1)
    # This is for the case where the main command is wrong
    @color = false if ARGV.includes?("--no-color")
    Crystal.error msg, @color, exit_code: exit_code
  end
end
