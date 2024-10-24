# Implementation of the `crystal tool format` command
#
# This is just the command-line part. The formatter
# logic is in `crystal/tools/formatter.cr`.

class Crystal::Command
  private def typer
    prelude = "prelude"
    type_blocks = false
    type_splats = false
    type_double_splats = false
    stats = false
    progress = false
    error_trace = false

    OptionParser.parse(options) do |opts|
      opts.banner = <<-USAGE
        Usage: typer [options] entrypoint [def_descriptor [def_descriptor [...]]]

        A def_descriptor comes in 4 formats:

        * A directory name ('src/')
        * A file ('src/my_project.cr')
        * A line number in a file ('src/my_project.cr:3')
        * The location of the def method to be typed, specifically ('src/my_project.cr:3:3')

        If a `def` definition matches a provided def_descriptor, then it will be typed if type restrictions are missing.
        If no dev_descriptors are provided, then 'src' is tried, or all files under current directory (and sub directories, recursive)
        are typed if no 'src' directory exists.

        Options:
        USAGE

      opts.on("-h", "--help", "Show this message") do
        puts opts
        exit
      end

      opts.on("--prelude [PRELUDE]", "Use given file as prelude. Use empty string to skip prelude entirely.") do |new_prelude|
        prelude = new_prelude
      end

      opts.on("--include-blocks", "Enable adding types to named block arguments (these usually get typed with Proc(Nil) and isn't helpful)") do
        type_blocks = true
      end

      opts.on("--include-splats", "Enable adding types to splats") do
        type_splats = true
      end

      opts.on("--include-double-splats", "Enable adding types to double splats") do
        type_double_splats = true
      end

      opts.on("--stats", "Enable statistics output") do
        stats = true
      end

      opts.on("--progress", "Enable progress output") do
        progress = true
      end

      opts.on("--error-trace", "Show full error trace") do
        error_trace = true
      end
    end

    entrypoint = options.shift
    def_locators = options

    results = SourceTyper.new(
      entrypoint,
      def_locators,
      type_blocks,
      type_splats,
      type_double_splats,
      prelude,
      stats,
      progress,
      error_trace
    ).run

    if results.empty?
      puts "No type restrictions added"
    else
      results.each do |filename, file_contents|
        # pp! filename, file_contents
        File.write(filename, file_contents)
      end
    end
  end
end
