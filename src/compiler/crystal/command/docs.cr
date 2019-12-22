# Implementation of the `crystal docs` command
#
# This is just the command-line part. Everything else
# is in `crystal/tools/doc/`

class Crystal::Command
  private VALID_OUTPUT_FORMATS = %w(html json)

  private def docs
    output_format = "html"
    output_directory = File.join(".", "docs")
    sitemap_base_url = nil
    sitemap_priority = "1.0"
    sitemap_changefreq = "never"

    compiler = Compiler.new

    OptionParser.parse(options) do |opts|
      opts.banner = <<-'BANNER'
        Usage: crystal docs [options]

        Generates API documentation from inline docstrings in all Crystal files inside ./src directory.

        Options:
        BANNER

      opts.on("--output=DIR", "-o DIR", "Set the output directory (default: #{output_directory})") do |value|
        output_directory = value
      end
      opts.on("--format=FORMAT", "-f FORMAT", "Set the output format [#{VALID_OUTPUT_FORMATS.join(", ")}] (default: #{output_format})") do |value|
        if !VALID_OUTPUT_FORMATS.includes? value
          STDERR.puts "Invalid format '#{value}'"
          abort opts
        end
        output_format = value
      end

      opts.on("--canonical-base-url=URL", "Deprecated option. Use --sitemap-base-url instead.") do |value|
        abort "Option --canonical-base-url is no longer supported.  Use --sitemap-base-url instead."
      end

      opts.on("--sitemap-base-url=URL", "-b URL", "Set the sitemap base URL and generates sitemap") do |value|
        sitemap_base_url = value
      end

      opts.on("--sitemap-priority=PRIO", "Set the sitemap priority (default: 1.0)") do |value|
        sitemap_priority = value
      end

      opts.on("--sitemap-changefreq=FREQ", "Set the sitemap changefreq (default: never)") do |value|
        sitemap_changefreq = value
      end

      opts.on("-D FLAG", "--define FLAG", "Define a compile-time flag") do |flag|
        compiler.flags << flag
      end

      opts.on("--error-trace", "Show full error trace") do
        compiler.show_error_trace = true
      end

      opts.on("--no-color", "Disable colored output") do
        @color = false
        compiler.color = false
      end

      opts.on("--prelude ", "Use given file as prelude") do |prelude|
        compiler.prelude = prelude
      end

      opts.on("-s", "--stats", "Enable statistics output") do
        @progress_tracker.stats = true
      end

      opts.on("-p", "--progress", "Enable progress output") do
        @progress_tracker.progress = true
      end

      opts.on("-t", "--time", "Enable execution time output") do
        @time = true
      end

      opts.on("-h", "--help", "Show this message") do
        puts opts
        exit
      end
    end

    if options.empty?
      sources = [Compiler::Source.new("require", %(require "./src/**"))]
      included_dirs = [] of String
    else
      filenames = options
      sources = gather_sources(filenames)
      included_dirs = sources.map { |source| File.dirname(source.filename) }
    end

    included_dirs << File.expand_path("./src")

    compiler.flags << "docs"
    compiler.wants_doc = true
    result = compiler.top_level_semantic sources

    Doc::Generator.new(result.program, included_dirs, output_directory, output_format, sitemap_base_url, sitemap_priority, sitemap_changefreq).run
  end
end
