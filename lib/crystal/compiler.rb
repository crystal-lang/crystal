require 'fileutils'
require 'tempfile'

module Crystal
  class Compiler
    include Crystal

    attr_reader :command

    def initialize
      require 'optparse'

      OptionParser.new do |opts|
        opts.banner = "Usage: crystal [switches] [--] [programfile] [arguments]"

        @options = {}
        opts.on("-e 'command'", "one line script. Several -e's allowed. Omit [programfile]") do |command|
          @options[:command] ||= []
          @options[:command] << command
          @options[:execute] = true
        end
        opts.on('-graph ', 'Render type graph') do
          @options[:graph] = true
        end
        opts.on('-types', 'Prints types of global variables') do
          @options[:types] = true
        end
        opts.on('--html DIR', 'Dump program to HTML in DIR directory') do |dir|
          @options[:html] = dir
        end
        opts.on('--hierarchy [FILTER]', 'Render hierarchy graph') do |filter|
          @options[:hierarchy] = filter || ""
        end
        opts.on("-h", "--help", "Show this message") do
          puts opts
          exit
        end
        opts.on('-ll', 'Dump ll to standard output') do
          @options[:dump_ll] = true
        end
        opts.on('-no-build', 'Disable build output') do
          @options[:no_build] = true
        end
        opts.on('-debug', 'Produce debugging information') do
          @options[:debug] = true
        end
        opts.on('-o ', 'Output filename') do |output|
          @options[:output_filename] = output
        end
        opts.on('-O ', 'Optimization level') do |opt|
          @options[:opt_level] = opt
        end
        opts.on('-prof', 'Enable profiling output') do
          @options[:prof] = true
        end
        opts.on('-run ', 'Execute program') do
          @options[:run] = true
          @options[:execute] = true
        end
        opts.on('-stats', 'Enable statistics output') do
          @options[:stats] = true
        end
      end.parse!

      if !@options[:output_filename]
        if @options[:run] || @options[:command] || ::ARGV.length == 0
          @tempfile = Tempfile.new('crystal')
          @options[:output_filename] = @tempfile.path
          @options[:execute] = true
          @options[:args] = []
          if ::ARGV.length > 1
            @options[:args] = ::ARGV[1 .. -1]
            ::ARGV.replace([::ARGV[0]])
          end
        elsif ::ARGV.length > 0
          @options[:output_filename] = File.basename(::ARGV[0], File.extname(::ARGV[0]))
        end
      end
    end

    def compile
      if @options[:stats]
        require 'benchmark'
        Benchmark.bm(20, 'TOTAL:') do |bm|
          @options[:bm] = bm
          @options[:total_bm] = Benchmark::Tms.new
          compile_with_stats_and_profile
          [@options[:total_bm]]
        end
      else
        compile_with_stats_and_profile
      end
    end

    def compile_with_stats_and_profile
      begin
        program = Program.new
        source = @options[:command] ? @options[:command].join(";") : ARGF.read
        filename = File.expand_path(ARGF.filename) unless ARGF.filename == '-'

        node = nil
        src_node = nil
        with_stats_or_profile('parse') do
          parser = Parser.new(source)
          parser.filename = filename
          src_node = node = parser.parse
        end

        require_node = Require.new("prelude")
        node = node ? Expressions.new([require_node, node]) : require_node

        with_stats_or_profile('normalize') do
          node = program.normalize node
        end
        program.infer_type node, @options

        if html_dir = @options[:html]
          FileUtils.mkpath html_dir
          FileUtils.rm Dir[File.join(html_dir, "*.html")]
          src_node.to_html(html_dir, 'main.html')
        end

        graph node, program, @options[:output_filename] if @options[:graph]
        graph_hierarchy program, @options[:hierarchy], @options[:output_filename] if @options[:hierarchy]
        print_types node if @options[:types]
        exit 0 if @options[:no_build]

        llvm_mod = nil
        with_stats_or_profile('codegen') do
          llvm_mod = program.build node, filename, @options[:debug]
        end
      rescue Crystal::Exception => ex
        puts ex.to_s(source)
        exit 1
      rescue Exception => ex
        puts ex
        puts ex.backtrace
        exit 1
      end

      llvm_mod.dump if @options[:dump_ll]

      reader, writer = IO.pipe
      Thread.new do
        llvm_mod.write_bitcode(writer)
        writer.close
      end

      o_flag = @options[:output_filename] ? "-o #{@options[:output_filename]} " : ''

      if @options[:debug]
        obj_file = "#{@options[:output_filename]}.o"

        pid = spawn "llc | clang -x assembler -c -o #{obj_file} -", in: reader
        Process.waitpid pid

        `clang #{o_flag} #{obj_file} #{lib_flags(program)}`
      else
        opt_cmd = @options[:opt_level] ? "opt -O#{@options[:opt_level]} |" : ""
        pid = spawn "#{opt_cmd} llc | clang -x assembler #{o_flag}- #{lib_flags(program)}", in: reader
        Process.waitpid pid
      end

      if @options[:execute]
        puts `#{@options[:output_filename]} #{@options[:args].join ' '}`
        @tempfile.delete
      end
    end

    def with_stats_or_profile(description, &block)
      if @options[:prof]
        node = Profiler.profile_to("#{description}.html", &block)
      elsif @options[:stats]
        @options[:total_bm] += @options[:bm].report(description, &block)
      else
        block.call
      end
    end

    def lib_flags(mod)
      libs = mod.library_names
      flags = ""
      if libs.length > 0
        flags << " -Wl"
        libs.each do |lib|
          flags << ",-l"
          flags << lib
        end
      end
      flags
    end
  end
end
