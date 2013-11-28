require "option_parser"
require "thread"

lib C
  fun tmpnam(result : Char*) : Char*
end

module Crystal
  class Compiler
    include Crystal

    getter! config
    getter! llc
    getter! opt
    getter! clang
    getter! llvm_dis
    getter! dump_ll
    getter! release
    getter! output_dir
    getter! mutex
    getter! llvm_modules
    getter! object_names

    def initialize
      @dump_ll = false
      @no_build = false
      @print_types = false
      @run = false
      @stats = false
      @release = false

      @config = LLVMConfig.new
      @llc = @config.bin "llc"
      @opt = @config.bin "opt"
      @clang = @config.bin "clang"
      @llvm_dis = @config.bin "llvm-dis"

      @options = OptionParser.parse! do |opts|
        opts.banner = "Usage: crystal [switches] [--] [programfile] [arguments]"
        opts.on("-e 'command'", "one line script. Omit [programfile]") do |command|
          @command = command
        end
        opts.on("-ll", "Dump ll to standard output") do
          @dump_ll = true
        end
        opts.on("-no-build", "Disable build output") do
          @no_build = true
        end
        opts.on("-o ", "Output filename") do |output_filename|
          @output_filename = output_filename
        end
        opts.on("--release", "Compile in release mode") do
          @release = true
        end
        opts.on("--run", "Execute program") do
          @run = true
        end
        opts.on("-stats", "Enable statistis output") do
          @stats = true
        end
        opts.on("-types", "Prints types of global variables") do
          @print_types = true
        end
        opts.on("-h", "--help", "Show this message") do
          puts opts
          exit 1
        end
      end
    end

    def compile
      if @command
        source = @command
        filename = "-"
        @run = true
      else
        if ARGV.length == 0
          puts @options
          exit 1
        end

        filename = ARGV[0]
        unless File.exists?(filename)
          puts "File #{filename} does not exist"
          exit 1
        end

        filename = File.expand_path(filename) #unless filename == '-'
        source = File.read filename
      end

      if @output_filename
        output_filename = @output_filename
      else
        if @run
          output_filename = String.new(C.tmpnam(nil))
        else
          output_filename = File.basename(filename, File.extname(filename))
        end
      end

      begin
        program = Program.new

        unless File.exists?(@clang)
          if program.has_require_flag?("darwin")
            puts "Could not find clang. Install clang 3.3: brew tap homebrew/versions; brew install llvm33 --with-clang"
            exit 1
          end

          clang = program.exec "which gcc"
          if clang
            @clang = clang
          else
            puts "Could not find a C compiler. Install clang (3.3) or gcc."
            exit 1
          end
        end

        parser = Parser.new(source)
        parser.filename = filename
        node = parser.parse

        require_node = Require.new("prelude")
        require_node.location = Location.new(1, 1, filename)

        node = Expressions.new([require_node, node] of ASTNode)

        node = timing("Normalize") do
          program.normalize(node)
        end

        node = timing("Type inference") do
          program.infer_type node
        end

        print_types node if @print_types
        exit if @no_build

        @llvm_modules = timing("Codegen (crystal)") do
          program.build node, @release
        end

        @output_dir = ".crystal/#{filename}"

        system "mkdir -p #{output_dir}"

        @mutex = Mutex.new
        @object_names = [] of String

        timing("Codegen (llc+clang)") do
          threads = Array.new(8) do
            Thread.new(self) do |compiler|
              while entry = compiler.mutex.synchronize { compiler.llvm_modules.shift? }
                type_name = entry.key
                llvm_mod = entry.value

                type_name = "main" if type_name == ""
                name = type_name.replace do |char|
                  if 'a' <= char <= 'z' || 'A' <= char <= 'Z' || '0' <= char <= '9' || char == '_'
                    nil
                  else
                    char.ord.to_s
                  end
                end

                bc_name = "#{compiler.output_dir}/#{name}.bc"
                bc_name_new = "#{bc_name}.new"
                bc_name_opt = "#{compiler.output_dir}/#{name}.opt.bc"
                s_name = "#{compiler.output_dir}/#{name}.s"
                o_name = "#{compiler.output_dir}/#{name}.o"
                ll_name = "#{compiler.output_dir}/#{name}.ll"

                llvm_mod.dump if Crystal::DUMP_LLVM

                llvm_mod.write_bitcode bc_name_new

                must_compile = true

                if File.exists?(bc_name) && File.exists?(o_name)
                  cmd_output = system "cmp -s #{bc_name} #{bc_name}.new"
                  if cmd_output == 0
                    system "rm #{bc_name_new}"
                    must_compile = false
                  end
                end

                if must_compile
                  # puts "Compile: #{type_name}"
                  system "mv #{bc_name_new} #{bc_name}"
                  if compiler.release
                    system "#{compiler.opt} #{bc_name} -O3 -o #{bc_name_opt}"
                    system "#{compiler.llc} #{bc_name_opt} -o #{s_name}"
                  else
                    system "#{compiler.llc} #{bc_name} -o #{s_name}"
                  end
                  system "#{compiler.clang} -c #{s_name} -o #{o_name}"
                end

                if compiler.dump_ll
                  if compiler.release
                    system "#{compiler.llvm_dis} #{bc_name_opt} -o #{ll_name}"
                  else
                    system "#{compiler.llvm_dis} #{bc_name} -o #{ll_name}"
                  end
                end

                compiler.mutex.synchronize { compiler.object_names << o_name }
              end
            end
          end
          threads.each &.join
        end

        timing("Codegen (clang)") do
          system "#{@clang} -o #{output_filename} #{object_names.join " "} #{lib_flags(program)}"
        end

        if @run
          system "#{output_filename}"
          File.delete output_filename
        end
      rescue ex
        puts ex
        exit 1
      end
    end

    def timing(label)
      if @stats
        time = Time.now
        value = yield
        puts "#{label}: #{Time.now - time} seconds"
        value
      else
        yield
      end
    end

    def lib_flags(mod)
      libs = mod.library_names
      String.build do |flags|
        if libs.length > 0
          flags << " -Wl"
          libs.each do |libname|
            flags << ",-l"
            flags << libname
          end
        end
        flags << " -Wl,-allow_stack_execute" if mod.has_require_flag?("darwin")
        flags << " -L#{@config.lib_dir}"
      end
    end
  end
end
