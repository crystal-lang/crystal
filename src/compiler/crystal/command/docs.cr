# Implementation of the `crystal docs` command
#
# This is just the command-line part. Everything else
# is in `crystal/tools/doc/`

class Crystal::Command
  private VALID_OUTPUT_FORMATS = %w(html json)

  private def docs
    output_format = "html"
    output_directory = File.join(".", "docs")
    canonical_base_url = nil

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
          puts opts
          exit
        end
        output_format = value
      end

      opts.on("--canonical-base-url=URL", "-b URL", "Set the canonical base url") do |value|
        canonical_base_url = value
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

    compiler = Compiler.new
    compiler.wants_doc = true
    result = compiler.top_level_semantic sources

    Doc::Generator.new(result.program, included_dirs, output_directory, output_format, canonical_base_url).run
  end
end
