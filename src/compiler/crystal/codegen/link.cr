module Crystal
  struct LinkAttribute
    getter lib : String?
    getter ldflags : String?
    getter framework : String?

    def initialize(@lib = nil, @ldflags = nil, @static = false, @framework = nil)
    end

    def static?
      @static
    end

    def self.from(attr : ASTNode)
      name = attr.name
      args = attr.args
      named_args = attr.named_args

      if name != "Link"
        attr.raise "illegal attribute for lib, valid attributes are: Link"
      end

      if args.empty? && !named_args
        attr.raise "missing link arguments: must at least specify a library name"
      end

      lib_name = nil
      lib_ldflags = nil
      lib_static = false
      lib_framework = nil
      count = 0

      args.each do |arg|
        case count
        when 0
          arg.raise "'lib' link argument must be a String" unless arg.is_a?(StringLiteral)
          lib_name = arg.value
        when 1
          arg.raise "'ldflags' link argument must be a String" unless arg.is_a?(StringLiteral)
          lib_ldflags = arg.value
        when 2
          arg.raise "'static' link argument must be a Bool" unless arg.is_a?(BoolLiteral)
          lib_static = arg.value
        when 3
          arg.raise "'framework' link argument must be a String" unless arg.is_a?(StringLiteral)
          lib_framework = arg.value
        else
          attr.wrong_number_of "link arguments", args.size, "1..4"
        end

        count += 1
      end

      named_args.try &.each do |named_arg|
        value = named_arg.value

        case named_arg.name
        when "lib"
          named_arg.raise "'lib' link argument already specified" if count > 0
          named_arg.raise "'lib' link argument must be a String" unless value.is_a?(StringLiteral)
          lib_name = value.value
        when "ldflags"
          named_arg.raise "'ldflags' link argument already specified" if count > 1
          named_arg.raise "'ldflags' link argument must be a String" unless value.is_a?(StringLiteral)
          lib_ldflags = value.value
        when "static"
          named_arg.raise "'static' link argument already specified" if count > 2
          named_arg.raise "'static' link argument must be a Bool" unless value.is_a?(BoolLiteral)
          lib_static = value.value
        when "framework"
          named_arg.raise "'framework' link argument already specified" if count > 3
          named_arg.raise "'framework' link argument must be a String" unless value.is_a?(StringLiteral)
          lib_framework = value.value
        else
          named_arg.raise "unknown link argument: '#{named_arg.name}' (valid arguments are 'lib', 'ldflags', 'static' and 'framework')"
        end
      end

      new(lib_name, lib_ldflags, lib_static, lib_framework)
    end
  end

  class Program
    def lib_flags
      has_flag?("windows") ? lib_flags_windows : lib_flags_posix
    end

    private def lib_flags_windows
      String.build do |flags|
        link_attributes.reverse_each do |attr|
          if ldflags = attr.ldflags
            flags << " " << ldflags
          end

          if libname = attr.lib
            flags << " " << libname << ".lib"
          end
        end
      end
    end

    private def lib_flags_posix
      library_path = ["/usr/lib", "/usr/local/lib"]
      has_pkg_config = nil

      String.build do |flags|
        link_attributes.reverse_each do |attr|
          if ldflags = attr.ldflags
            flags << " " << ldflags
          end

          if libname = attr.lib
            if has_pkg_config.nil?
              has_pkg_config = Process.run("which", {"pkg-config"}, output: Process::Redirect::Close).success?
            end

            if has_pkg_config && (libflags = pkg_config_flags(libname, attr.static?, library_path))
              flags << " " << libflags
            elsif attr.static? && (static_lib = find_static_lib(libname, library_path))
              flags << " " << static_lib
            else
              flags << " -l" << libname
            end
          end

          if framework = attr.framework
            flags << " -framework " << framework
          end
        end

        # Append the default paths as -L flags in case the linker doesn't know
        # about them (eg: FreeBSD won't search /usr/local/lib by default):
        library_path.each do |path|
          flags << " -L#{path}"
        end
      end
    end

    def link_attributes
      attrs = [] of LinkAttribute
      add_link_attributes @types, attrs
      attrs
    end

    private def pkg_config_flags(libname, static, library_path)
      if system("pkg-config #{libname}")
        if static
          flags = [] of String
          `pkg-config #{libname} --libs --static`.split.each do |cfg|
            if cfg.starts_with?("-L")
              library_path << cfg[2..-1]
            elsif cfg.starts_with?("-l")
              flags << (find_static_lib(cfg[2..-1], library_path) || cfg)
            else
              flags << cfg
            end
          end
          flags.join " "
        else
          `pkg-config #{libname} --libs`.chomp
        end
      end
    end

    private def find_static_lib(libname, library_path)
      library_path.each do |libdir|
        static_lib = "#{libdir}/lib#{libname}.a"
        return static_lib if File.exists?(static_lib)
      end
      nil
    end

    private def add_link_attributes(types, attrs)
      types.try &.each_value do |type|
        next if type.is_a?(AliasType) || type.is_a?(TypeDefType)

        if type.is_a?(LibType) && type.used? && (link_attrs = type.link_attributes)
          attrs.concat link_attrs
        end

        add_link_attributes type.types?, attrs
      end
    end
  end
end
