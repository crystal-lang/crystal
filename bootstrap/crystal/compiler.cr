require "option_parser"

lib C
  fun tmpnam(result : Char*) : Char*
end

module Crystal
  class Compiler
    include Crystal

    def initialize
      @dump_ll = false
      @no_build = false
      @print_types = false
      @run = false
      @stats = false
      @release = false

      @llc = "llc-3.3"
      @opt = "opt-3.3"
      @clang = "clang-3.3"
      @llvm_dis = "llvm-dis-3.3"

      @options = OptionParser.parse! do |opts|
        opts.banner = "Usage: crystal [switches] [--] [programfile] [arguments]"
        opts.on("-ll", "Dump ll to standard output") do
          @dump_ll = true
        end
        opts.on("-no-build", "Disable build output") do
          @no_build = true
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

      if @run
        output_filename = String.new(C.tmpnam(nil))
      else
        output_filename = File.basename(filename, File.extname(filename))
      end

      bitcode_filename = "#{output_filename}.bc"
      optimized_bitcode_filename = "#{output_filename}.opt.bc"
      ll_filename = "#{output_filename}.ll"

      source = File.read filename

      begin
        program = Program.new
        parser = Parser.new(source)
        parser.filename = filename
        node = parser.parse

        require_node = Require.new("prelude")
        require_node.location = Location.new(1, 1, filename)

        node = Expressions.new([require_node, node] of ASTNode)

        time = Time.now
        node = program.normalize node
        puts "Normalize: #{Time.now - time} seconds" if @stats

        time = Time.now
        node = program.infer_type node
        puts "Type inference: #{Time.now - time} seconds" if @stats

        print_types node if @print_types
        exit if @no_build

        time = Time.now
        llvm_modules = program.build node, @release
        puts "Codegen (crystal): #{Time.now - time} seconds" if @stats

        system "mkdir -p .crystal"

        time = Time.now

        object_names = [] of String

        llvm_modules.each do |type_name, llvm_mod|
          type_name = "main" if type_name == ""
          name = type_name.replace do |char|
            if 'a' <= char <= 'z' || 'A' <= char <= 'Z' || '0' <= char <= '9' || char == '_'
              nil
            else
              char.ord.to_s
            end
          end

          bc_name = ".crystal/#{name}.bc"
          bc_name_new = "#{bc_name}.new"
          bc_name_opt = ".crystal/#{name}.opt.bc"
          s_name = ".crystal/#{name}.s"
          o_name = ".crystal/#{name}.o"
          ll_name = ".crystal/#{name}.ll"

          # puts "Process: #{type_name}"

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
            if @release
              system "#{@opt} #{bc_name} -O3 -o #{bc_name_opt}"
              system "#{@llc} #{bc_name_opt} -o #{s_name}"
            else
              system "#{@llc} #{bc_name} -o #{s_name}"
            end
            system "#{@clang} -c #{s_name} -o #{o_name}"
          end

          if @dump_ll
            if @release
              system "#{@llvm_dis} #{bc_name_opt} -o #{ll_name}"
            else
              system "#{@llvm_dis} #{bc_name} -o #{ll_name}"
            end
          end

          object_names << o_name
        end

        puts "Codegen (llc+clang): #{Time.now - time} seconds" if @stats

        time = Time.now
        system "#{@clang} -o #{output_filename} #{object_names.join " "} #{lib_flags(program)}"
        puts "Codegen (clang): #{Time.now - time} seconds" if @stats

        if @run
          system "#{output_filename}"
          File.delete output_filename
        end
      rescue ex
        puts ex
        exit 1
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
        flags << " -L#{mod.exec("llvm-config-3.3 --libdir").strip}"
      end
    end
  end
end
