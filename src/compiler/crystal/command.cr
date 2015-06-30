module Crystal
  def self.tempfile(basename)
    Dir.mkdir_p Config.cache_dir
    File.join(Config.cache_dir, "crystal-run-#{basename}.tmp")
  end
end

module Crystal::Command
  USAGE = <<-USAGE
Usage: crystal [command] [switches] [program file] [--] [arguments]

Command:
    init                     generate new crystal project
    build                    compile program file
    browser                  open an http server to browse program file
    deps                     install project dependencies
    docs                     generate documentation
    eval                     eval code
    hierarchy                show type hierarchy
    run (default)            compile and run program file
    spec                     compile and run specs (in spec directory)
    types                    show type of main variables
    ast                      show ast
    --help                   show this help
    --version, -v            show version
USAGE

  VALID_EMIT_VALUES = %w(asm llvm-bc llvm-ir obj)

  @@color = true

  def self.run(options = ARGV)
    command = options.first?

    if command
      if File.file?(command)
        run_command options
      else
        case
        when "init".starts_with?(command)
          options.shift
          init options
        when "build".starts_with?(command)
          options.shift
          build options
        when "browser" == command
          options.shift
          browser options
        when "deps".starts_with?(command)
          options.shift
          deps options
        when "docs".starts_with?(command)
          options.shift
          docs options
        when "eval".starts_with?(command)
          options.shift
          eval options
        when "hierarchy".starts_with?(command)
          options.shift
          hierarchy options
        when "run".starts_with?(command)
          options.shift
          run_command options
        when "spec/".starts_with?(command)
          options.shift
          run_specs options
        when "types".starts_with?(command)
          options.shift
          types options
        when "ast".starts_with?(command)
          options.shift
          ast options
        when "--help" == command
          puts USAGE
          exit
        when "--version" == command, "-v" == command
          puts "Crystal #{Crystal.version_string}"
          exit
        else
          error "unknown command: #{command}"
        end
      end
    else
      puts USAGE
      exit
    end
  rescue ex : Crystal::Exception
    ex.color = @@color
    puts ex
    exit 1
  rescue ex
    puts ex
    ex.backtrace.each do |frame|
      puts frame
    end
    puts
    error "you've found a bug in the Crystal compiler. Please open an issue: https://github.com/manastech/crystal/issues"
  end

  private def self.init(options)
    Init.run(options)
  end

  private def self.build(options)
    config = create_compiler "build", options
    config.compile
  end

  private def self.browser(options)
    config, result = compile_no_build "browser", options
    Browser.open result.original_node
  end

  private def self.eval(args)
    if args.empty?
      program_source = STDIN.read
      program_args = [] of String
    else
      double_dash_index = args.index("--")
      if double_dash_index
        program_source = args[0 ... double_dash_index].join " "
        program_args = args[double_dash_index + 1 .. -1]
      else
        program_source = args.join " "
        program_args = [] of String
      end
    end

    compiler = Compiler.new
    sources = [Compiler::Source.new("eval", program_source)]

    output_filename = tempfile "eval"

    result = compiler.compile sources, output_filename
    execute output_filename, program_args
  end

  private def self.hierarchy(options)
    config, result = compile_no_build "hierarchy", options, hierarchy: true
    Crystal.print_hierarchy result.program, config.hierarchy_exp
  end

  private def self.run_command(options)
    config = create_compiler "run", options, run: true
    if config.specified_output
      config.compile
      return
    end

    output_filename = tempfile(config.output_filename)

    result = config.compile output_filename
    execute output_filename, config.arguments unless config.compiler.no_build?
  end

  private def self.run_specs(options)
    target_filename_and_line_number = options.first?
    if target_filename_and_line_number
      splitted = target_filename_and_line_number.split ':', 2
      target_filename = splitted[0]
      if File.file?(target_filename)
        options.shift
        cwd = Dir.working_directory
        if target_filename.starts_with?(cwd)
          target_filename = "#{target_filename[cwd.length .. -1]}"
        end
        if splitted.length == 2
          target_line = splitted[1]
          options << "-l" << target_line
        end
      elsif File.directory?(target_filename)
        target_filename = "#{target_filename}/**"
      else
        error "'#{target_filename}' is not a file"
      end
    else
      target_filename = "spec/**"
    end

    sources = [Compiler::Source.new("spec", %(require "./#{target_filename}"))]

    output_filename = tempfile "spec"

    compiler = Compiler.new
    result = compiler.compile sources, output_filename
    execute output_filename, options
  end

  private def self.deps(options)
    gather_sources(["./Projectfile"])

    sources = Compiler::Source.new("require", %(require "crystal/project_cli"))

    output_filename = tempfile "deps"

    compiler = Compiler.new
    compiler.compile sources, output_filename
    execute output_filename, options
  end

  private def self.docs(options)
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

  private def self.types(options)
    config, result = compile_no_build "types", options
    Crystal.print_types result.original_node
  end

  private def self.ast(options)
    config, result = compile_no_build "ast", options
    Crystal.print_ast result.original_node
  end

  private def self.compile_no_build(command, options, wants_doc = false, hierarchy = false)
    config = create_compiler command, options, no_build: true, hierarchy: hierarchy
    config.compiler.no_build = true
    config.compiler.wants_doc = wants_doc
    {config, config.compile}
  end

  private def self.execute(output_filename, run_args)
    # TODO: fix system to make output flush on newline if it's a tty
    exit_status = LibC.system("#{output_filename} #{run_args.map(&.inspect).join " "}")
    if exit_status != 0
      puts "Program terminated abnormally with error code: #{exit_status}"
      exit 1
    end
    File.delete output_filename
  end

  private def self.tempfile(basename)
    Crystal.tempfile(basename)
  end

  record CompilerConfig, compiler, sources, output_filename, original_output_filename, arguments, specified_output, hierarchy_exp do
    def compile(output_filename = self.output_filename)
      compiler.original_output_filename = original_output_filename
      compiler.compile sources, output_filename
    end
  end

  private def self.create_compiler(command, options, no_build = false, run = false, hierarchy = false)
    compiler = Compiler.new
    link_flags = [] of String
    opt_filenames = nil
    opt_arguments = nil
    opt_output_filename = nil
    specified_output = false
    hierarchy_exp = nil

    option_parser = OptionParser.parse(options) do |opts|
      opts.banner = "Usage: crystal #{command} [options] [programfile] [--] [arguments]\n\nOptions:"

      unless no_build
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

      unless no_build
        opts.on("--emit [#{VALID_EMIT_VALUES.join("|")}]", "Comma separated list of types of output for the compiler to emit") do |emit_values|
          compiler.emit = validate_emit_values(emit_values.split(',').map(&.strip))
        end
      end

      if hierarchy
        opts.on("-e NAME", "Filter types by NAME regex") do |exp|
          hierarchy_exp = exp
        end
      end

      opts.on("-h", "--help", "Show this message") do
        puts opts
        exit 1
      end

      unless no_build
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
        @@color = false
        compiler.color = false
      end

      unless no_build
        opts.on("--no-build", "Disable build output") do
          compiler.no_build = true
        end
        opts.on("-o ", "Output filename") do |an_output_filename|
          opt_output_filename = an_output_filename
          specified_output = true
        end
      end

      opts.on("--prelude ", "Use given file as prelude") do |prelude|
        compiler.prelude = prelude
      end

      unless no_build
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

    if filenames.length == 0
      puts option_parser
      exit 1
    end

    sources = gather_sources(filenames)
    original_output_filename = output_filename_from_sources(sources)
    output_filename ||= original_output_filename

    CompilerConfig.new compiler, sources, output_filename, original_output_filename, arguments, specified_output, hierarchy_exp
  rescue ex : OptionParser::Exception
    error ex.message
  end

  private def self.gather_sources(filenames)
    filenames.map do |filename|
      unless File.file?(filename)
        error "File #{filename} does not exist"
      end
      filename = File.expand_path(filename)
      Compiler::Source.new(filename, File.read(filename))
    end
  end

  private def self.output_filename_from_sources(sources)
    first_filename = sources.first.filename
    File.basename(first_filename, File.extname(first_filename))
  end

  private def self.validate_emit_values(values)
    values.each do |value|
      unless VALID_EMIT_VALUES.includes?(value)
        error "invalid emit value '#{value}'"
      end
    end
    values
  end

  private def self.error(msg)
    # This is for the case where the main command is wrong
    @@color = false if ARGV.includes?("--no-color")

    print colorize("Error: ").red.bold
    puts colorize(msg).toggle(@@color).bold
    exit 1
  end

  private def self.colorize(obj)
    obj.colorize.toggle(@@color)
  end
end
