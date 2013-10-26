require 'fileutils'
require 'tempfile'
require 'digest/md5'

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
        opts.on('--html [DIR]', 'Dump program to HTML in DIR directory') do |dir|
          @options[:html] = dir
        end
        opts.on('--hierarchy [FILTER]', 'Render hierarchy graph') do |filter|
          @options[:hierarchy] = filter || ""
        end
        opts.on("-h", "--help", "Show this message") do
          puts opts
          exit 1
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
          if @options[:dump_ll]
            @options[:output_filename] = "#{@options[:output_filename]}.ll"
          end
        end
      end

      @llc = LLVMConfig.bin("llc")
      @opt = LLVMConfig.bin("opt")
      @clang = LLVMConfig.bin("clang")
      unless File.exists?(@clang)
        if RUBY_PLATFORM =~ /darwin/
          puts "Could not find clang. Install clang 3.3: brew tap homebrew/versions; brew install llvm33 --with-clang"
          exit 1
        end

        @clang = `which gcc`.strip
        if @clang.empty?
          puts "Could not find a C compiler. Install clang (3.3) or gcc."
          exit 1
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

        llvm_modules = nil
        with_stats_or_profile('codegen-llvm') do
          llvm_modules = program.build node, filename: filename, debug: @options[:debug]
        end
      rescue Crystal::Exception => ex
        puts ex.to_s(source)
        exit 1
      rescue Exception => ex
        puts ex
        puts ex.backtrace
        exit 1
      end

      FileUtils.mkdir_p ".crystal"

      assembly_names = []

      with_stats_or_profile('codegen-llc') do
        llvm_modules.each do |type, llvm_mod|
          name = type.gsub(/[^a-zA-Z0-9]/, '_')
          bc_name = ".crystal/#{name}.bc"

          llvm_mod.write_bitcode "#{bc_name}.new"

          if File.exists?(bc_name)
            `diff -q #{bc_name} #{bc_name}.new`

            if $?.success?
              FileUtils.rm "#{bc_name}.new"
            else
              FileUtils.mv "#{bc_name}.new", bc_name
              `#{@llc} .crystal/#{name}.bc -o .crystal/#{name}.s`
            end
          else
            FileUtils.mv "#{bc_name}.new", bc_name
            `#{@llc} .crystal/#{name}.bc -o .crystal/#{name}.s`
          end

          if @options[:dump_ll]
            llvm_dis = LLVMConfig.bin("llvm-dis")
            `#{llvm_dis} #{bc_name}`
          end

          assembly_names << ".crystal/#{name}.s"
        end
      end

      o_flag = @options[:output_filename] ? "-o #{@options[:output_filename]} " : ''

      with_stats_or_profile('codegen-clang') do
        `#{@clang} #{o_flag} #{lib_flags(program)} #{assembly_names.join " "}` unless @options[:dump_ll]
      end

      # if @options[:debug]
      #   obj_file = "#{@options[:output_filename]}.o"

      #   pid = spawn "#{@llc} | #{@clang} -x assembler -c -o #{obj_file} -", in: reader
      #   Process.waitpid pid

      #   `#{@clang} #{o_flag} #{obj_file} #{lib_flags(program)}`
      # else
      #   opt_cmd = @options[:opt_level] ? "#{@opt} -O#{@options[:opt_level]} |" : ""

      #   if @options[:dump_ll]
      #     llvm_dis = LLVMConfig.bin("llvm-dis")
      #     pid = spawn "#{opt_cmd} #{llvm_dis} #{o_flag}", in: reader
      #   else
      #     pid = spawn "#{opt_cmd} #{@llc} | #{@clang} -x assembler #{o_flag}- #{lib_flags(program)}", in: reader
      #   end
      #   Process.waitpid pid
      # end

      # if @options[:execute]
      #   @tempfile.close
      #   print `#{@options[:output_filename]} #{@options[:args].join ' '}`
      #   unless $?.success?
      #     puts "\033[1;31m#{$?.to_s}\033[0m"
      #   end
      #   @tempfile.delete
      # end
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
      flags << " -Wl,-allow_stack_execute" if RUBY_PLATFORM =~ /darwin/
      flags << " -L#{`llvm-config-3.3 --libdir`.strip}"
      flags
    end
  end
end
