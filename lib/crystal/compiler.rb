require 'llvm/transforms/ipo'
require 'llvm/transforms/scalar'

module Crystal
  class Compiler
    include Crystal

    attr_reader :command

    def initialize
      require 'optparse'

      @options = {optimization_passes: 5, load_std: true}
      OptionParser.new do |opts|
        opts.banner = "Usage: crystal [switches] [--] [programfile] [arguments]"

        opts.on("-e 'command'", "one line script. Several -e's allowed. Omit [programfile]") do |command|
          @options[:command] ||= []
          @options[:command] << command
        end
        opts.on('-graph ', 'Render type graph') do
          @options[:graph] = true
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

      o_flag = @options[:output_filename] ? "-o #{@options[:output_filename]} " : ''

      @command = "llc | clang -x assembler #{o_flag}-"
    end

    def compile
      begin
        source = @options[:command] ? @options[:command].join(";") : ARGF.read

        parser = Parser.new(source)
        parser.filename = ARGF.filename unless ARGF.filename == '-'

        node = parser.parse
        mod = infer_type node, @options

        graph node, mod, @options[:output_filename] if @options[:graph] || !Crystal::UNIFY
        exit 0 if @options[:no_build] || !Crystal::UNIFY

        llvm_mod = build node, mod
        write_main llvm_mod unless @options[:run] || @options[:command]

        # Don't optimize crystal_main away if the user wants to run the program
        llvm_mod.functions["crystal_main"].linkage = :internal unless @options[:run] || @options[:command]

        engine = LLVM::JITCompiler.new llvm_mod
        optimize llvm_mod, engine
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
        mod.load_libs

        engine.run_function llvm_mod.functions["crystal_main"], 0, nil
      else
        reader, writer = IO.pipe
        Thread.new do
          llvm_mod.write_bitcode(writer)
          writer.close
        end

        append_libs_to_command mod

        pid = spawn command, in: reader
        Process.waitpid pid
      end
    end

    def append_libs_to_command(mod)
      libs = mod.library_names
      if libs.length > 0
        @command << " -Wl"
        libs.each do |lib|
          @command << ",-l"
          @command << lib
        end
      end
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

      @options[:optimization_passes].times { pm.run mod }
    end
  end
end