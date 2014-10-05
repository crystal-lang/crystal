module Crystal::Command
  def self.run(options = ARGV)
    compiler = Compiler.new
    inline_exps = [] of String
    link_flags = [] of String
    opt_filenames = nil
    opt_arguments = nil
    opt_output_filename = nil
    run = false
    browser = false
    print_types = false
    print_hierarchy = false

    option_parser = OptionParser.parse(options) do |opts|
      opts.banner = "Usage: crystal [switches] [--] [programfile] [arguments]"
      opts.on("--browser", "Opens an http server to browse the code") do
        browser = true
      end
      opts.on("--cross-compile flags", "cross-compile") do |cross_compile|
        compiler.cross_compile_flags = cross_compile
      end
      opts.on("-d", "--debug", "Add symbolic debug info") do
        compiler.debug = true
      end
      opts.on("-e 'command'", "One line script. Several -e's allowed. Omit [programfile]") do |inline_exp|
        inline_exps << inline_exp
      end
      opts.on("-h", "--help", "Show this message") do
        puts opts
        exit 1
      end
      opts.on("--hierarchy", "Prints types hierarchy") do
        print_hierarchy = true
      end
      opts.on("--ll", "Dump ll to .crystal directory") do
        compiler.dump_ll = true
      end
      opts.on("--link-flags FLAGS", "Additional flags to pass to the linker") do |some_link_flags|
        link_flags << some_link_flags
      end
      opts.on("--mcpu CPU", "Target specific cpu type") do |cpu|
        compiler.mcpu = cpu
      end
      opts.on("--no-build", "Disable build output") do
        compiler.no_build = true
      end
      opts.on("-o ", "Output filename") do |an_output_filename|
        opt_output_filename = an_output_filename
      end
      opts.on("--prelude ", "Use given file as prelude") do |prelude|
        compiler.prelude = prelude
      end
      opts.on("--release", "Compile in release mode") do
        compiler.release = true
      end
      opts.on("--run", "Execute program") do
        run = true
      end
      opts.on("-s", "--stats", "Enable statistis output") do
        compiler.stats = true
      end
      opts.on("--single-module", "Generate a single LLVM module") do
        compiler.single_module = true
      end
      opts.on("-t", "--types", "Prints types of global variables") do
        print_types = true
      end
      opts.on("--threads ", "Maximum number of threads to use") do |n_threads|
        compiler.n_threads = n_threads.to_i
      end
      opts.on("--target TRIPLE", "Target triple") do |triple|
        compiler.target_triple = triple
      end
      opts.on("-v", "--version", "Print Crystal version") do
        puts "Crystal #{Crystal.version_string}"
        exit
      end
      opts.on("--verbose", "Display executed commands") do
        compiler.verbose = true
      end
      opts.unknown_args do |before, after|
        opt_filenames = before
        opt_arguments = after
      end
    end

    compiler.link_flags = link_flags.join(" ") unless link_flags.empty?

    inline_exp = inline_exps.empty? ? nil : inline_exps.join "\n"
    output_filename = opt_output_filename
    filenames = opt_filenames.not_nil!
    arguments = opt_arguments.not_nil!

    if inline_exp
      run = true
    else
      if filenames.length == 0
        puts option_parser
        exit 1
      end
    end

    sources = gather_sources(filenames, inline_exp)
    output_filename ||= output_filename_from_sources(sources)

    if run
      tempfile = Tempfile.new "crystal-run-#{output_filename}"
      output_filename = tempfile.path
      tempfile.close
    end

    result = compiler.compile sources, output_filename

    Crystal.print_types result.original_node if print_types
    Crystal.print_hierarchy result.program   if print_hierarchy
    Browser.open(result.original_node)       if browser
    run output_filename, arguments           if run
  rescue ex : Crystal::Exception
    puts ex
    exit 1
  rescue ex : OptionParser::Exception
    print "Error: ".colorize.red.bold
    puts ex.message.colorize.bold
    exit 1
  rescue ex
    puts ex
    ex.backtrace.each do |frame|
      puts frame
    end
    puts
    print "Error: ".colorize.red.bold
    puts "you've found a bug in the Crystal compiler. Please open an issue: https://github.com/manastech/crystal/issues".colorize.bright
    exit 2
  end

  private def self.gather_sources(filenames, inline_exp)
    if inline_exp
      [Compiler::Source.new("-e", inline_exp)]
    else
      filenames.map do |filename|
        unless File.exists?(filename)
          puts "File #{filename} does not exist"
          exit 1
        end
        filename = File.expand_path(filename)
        Compiler::Source.new(filename, File.read(filename))
      end
    end
  end

  private def self.output_filename_from_sources(sources)
    first_filename = sources.first.filename
    File.basename(first_filename, File.extname(first_filename))
  end

  private def self.run(output_filename, run_args)
    # TODO: fix system to make output flush on newline if it's a tty
    exit_status = C.system("#{output_filename} #{run_args.map(&.inspect).join " "}")
    if exit_status != 0
      puts "Program terminated abnormally with error code: #{exit_status}"
    end
    File.delete output_filename
  end
end
