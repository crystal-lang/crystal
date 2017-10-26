# Implementation of the `crystal docs` command
#
# This is just the command-line part. Everything else
# is in `crystal/tools/doc.cr`

class Crystal::Command
  private def docs
    output_directory = File.join(".", "docs")

    OptionParser.parse(options) do |opts|
      opts.banner = <<-'BANNER'
        Usage: crystal docs [options]

        Generates API documentation from inline docstrings in all Crystal files inside ./src directory.

        Options:
        BANNER

      opts.on("--output=DIR", "-o DIR", "Set the output directory (default: #{output_directory})") do |value|
        output_directory = value
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

    Doc::Generator.new(result.program, included_dirs, output_directory).run
  end
end
