module Crystal
  class LinkAttribute
    getter :lib
    getter :ldflags
    getter :framework

    def initialize(@lib = nil, @ldflags = nil, @static = false, @framework = nil)
    end

    def static?
      @static
    end
  end

  class Program
    def lib_flags
      library_path = ["/usr/lib", "/usr/local/lib"]
      has_pkg_config = nil

      String.build do |flags|
        link_attributes.reverse_each do |attr|
          if ldflags = attr.ldflags
            flags << " " << ldflags
          end

          if libname = attr.lib
            if has_pkg_config.nil?
              has_pkg_config = Process.run("which", {"pkg-config"}, output: false).success?
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
      end
    end

    private def link_attributes
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
              library_path << cfg[2 .. -1]
            elsif cfg.starts_with?("-l")
              flags << (find_static_lib(cfg[2 .. -1], library_path) || cfg)
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
      types.each_value do |type|
        if type.is_a?(LibType) && type.used? && (link_attrs = type.link_attributes)
          attrs.concat link_attrs
        end

        add_link_attributes type.types, attrs
      end
    end
  end
end

