require 'llvm/transforms/ipo'
require 'llvm/transforms/scalar'

module Crystal
  class Compiler
    include Crystal

    attr_reader :command

    def initialize
      require 'optparse'

      @options = {optimization_passes: 0}
      OptionParser.new do |opts|
        opts.banner = "Usage: crystal [switches] [--] [programfile] [arguments]"

        opts.on("-e 'command'", "one line script. Several -e's allowed. Omit [programfile]") do |command|
          @options[:command] ||= []
          @options[:command] << command
        end
        opts.on('-graph ', 'Render type graph') do
          @options[:graph] = true
        end
        opts.on('-types', 'Prints types of global variables') do
          @options[:types] = true
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
        opts.on('-O ', "Number of optimization passes (default: #{@options[:optimization_passes]})") do |opt|
          @options[:optimization_passes] = opt.to_i
        end
        opts.on('-prof', 'Enable profiling output') do
          @options[:prof] = true
        end
        opts.on('-run ', 'Execute program') do
          @options[:run] = true
        end
        opts.on('-stats', 'Enable statistics output') do
          @options[:stats] = true
        end
      end.parse!

      if !@options[:output_filename] && ::ARGV.length > 0
        @options[:output_filename] = File.basename(::ARGV[0], File.extname(::ARGV[0]))
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
        with_stats_or_profile('parse') do
          parser = Parser.new(source)
          parser.filename = filename
          node = parser.parse
        end

        require_node = Require.new(StringLiteral.new("prelude"))
        node = node ? Expressions.new([require_node, node]) : require_node

        with_stats_or_profile('normalize') do
          node = program.normalize node
        end
        program.infer_type node, @options

        graph node, mod, @options[:output_filename] if @options[:graph]
        print_types node if @options[:types]
        exit 0 if @options[:no_build]

        llvm_mod = nil
        engine = nil
        with_stats_or_profile('codegen') do
          llvm_mod = program.build node, filename, @options[:debug]
          write_main llvm_mod unless @options[:run] || @options[:command]

          # Don't optimize crystal_main away if the user wants to run the program
          llvm_mod.functions["crystal_main"].linkage = :internal unless @options[:run] || @options[:command]

          engine = LLVM::JITCompiler.new llvm_mod
          optimize llvm_mod, engine unless @options[:debug]
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

      if @options[:run] || @options[:command]
        program.load_libs

        engine.run_function llvm_mod.functions["crystal_main"], 0, nil
      else
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
          pid = spawn "llc | clang -x assembler #{o_flag}- #{lib_flags(program)}", in: reader
          Process.waitpid pid
        end
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

    def write_main(mod)
      mod.functions.add('main', [LLVM::Int, LLVM::Pointer(LLVM::Pointer(LLVM::Int8))], LLVM::Int) do |main, argc, argv|
        main.params[0].name = 'argc'
        main.params[1].name = 'argv'

        entry = main.basic_blocks.append('entry')
        entry.build do |b|
          b.call mod.functions['crystal_main'], argc, argv
          b.ret LLVM::Int(0)
        end
      end
    end

    def optimize(mod, engine)
      self.class.optimize mod, engine, @options[:optimization_passes]
    end

    def self.optimize(mod, engine, optimization_passes)
      pm = LLVM::PassManager.new engine
      pm.inline!
      pm.gdce!
      pm.instcombine!
      pm.reassociate!
      pm.gvn!
      pm.mem2reg!
      pm.simplifycfg!
      pm.tailcallelim!
      pm.loop_unroll!
      pm.loop_deletion!
      pm.loop_rotate!
      pm.scalarrepl!
      pm.memcpyopt!

      optimization_passes.times { pm.run mod }
    end
  end
end