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

      @options = OptionParser.parse! do |opts|
        opts.banner = "Usage: crystal [switches] [--] [programfile] [arguments]"
        opts.on("-ll", "Dump ll to standard output") do
          @dump_ll = true
        end
        opts.on("-no-build", "Disable build output") do
          @no_build = true
        end
        opts.on("-run", "Execute program") do
          @run = true
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

      if @run
        output_filename = String.new(C.tmpnam(nil))
      else
        output_filename = File.basename(filename, File.extname(filename))
      end

      bitcode_filename = "#{output_filename}.bc"

      source = File.read filename

      begin
        program = Program.new
        parser = Parser.new(source)
        parser.filename = filename
        node = parser.parse

        require_node = Require.new("bootstrap")
        require_node.location = Location.new(1, 1, filename)

        node = Expressions.new([require_node, node] of ASTNode)

        node = program.normalize node
        node = program.infer_type node

        print_types node if @print_types
        exit if @no_build

        llvm_mod = program.build node

        llvm_mod.dump if @dump_ll

        llvm_mod.write_bitcode bitcode_filename

        system "llc-3.3 #{bitcode_filename} -o - | clang-3.3 -x assembler -o #{output_filename} #{lib_flags(program)} -"

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
      end
      # flags << " -Wl,-allow_stack_execute" if RUBY_PLATFORM =~ /darwin/
      # flags << " -L#{`llvm-config-3.3 --libdir`.strip}"
      # flags
    end
  end
end
