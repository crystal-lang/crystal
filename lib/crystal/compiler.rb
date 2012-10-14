require 'llvm/transforms/ipo'
require 'llvm/transforms/scalar'

module Crystal
  class Compiler
    include Crystal

    attr_reader :command

    def initialize
      require 'optparse'

      @options = {optimization_passes: 5}
      OptionParser.new do |opts|
        opts.on('-o ', 'Output filename') do |output|
          @options[:output_filename] = output
        end
        opts.on('-O ', "Optimization passes (default: #{@options[:optimization_passes]})") do |opt|
          @options[:optimization_passes] = opt.to_i
        end
        opts.on('-run ', 'Execute filename') do
          @options[:run] = true
        end
        opts.on('-graph ', 'Render type graph') do
          @options[:graph] = true
        end
        opts.on('-ll', 'Dump ll to standard output') do
          @options[:dump_ll] = true
        end
        opts.on('-stats', 'Enable statistics output') do
          @options[:stats] = true
        end
        opts.on('-no-build', 'Disable build output') do
          @options[:no_build] = true
        end
      end.parse!

      if !@options[:output_filename] && ARGV.length > 0
        @options[:output_filename] = File.basename(ARGV[0], File.extname(ARGV[0]))
      end

      o_flag = @options[:output_filename] ? "-o #{@options[:output_filename]} " : ''
      @command = "llc | clang -x assembler #{o_flag}-"
    end

    def compile
      begin
        source = ARGF.read
        node = parse source
        mod = infer_type node, @options[:stats]
        graph node, mod, @options[:output_filename] if @options[:graph]
        exit 0 if @options[:no_build]

        llvm_mod = build node, mod
        write_main llvm_mod unless @options[:run]

        # Don't optimize crystal_main away if the user wants to run the program
        llvm_mod.functions["crystal_main"].linkage = :internal unless @options[:run]

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

      if @options[:run]
        engine.run_function llvm_mod.functions["crystal_main"]
      else
        reader, writer = IO.pipe
        Thread.new do
          llvm_mod.write_bitcode(writer)
          writer.close
        end

        pid = spawn command, in: reader
        Process.waitpid pid
      end
    end

    def write_main(mod)
      mod.functions.add('main', [], LLVM::Int) do |main|
        entry = main.basic_blocks.append('entry')
        entry.build do |b|
          b.call mod.functions['crystal_main']
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