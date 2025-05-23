require "json"
require "file_utils"

class Crystal::Doc::MarkdownConverter
  def initialize(@json_data : Main, @output_dir : String)
  end

  def generate
    Dir.mkdir_p(@output_dir)
    generate_readme
    generate_index
    generate_type_files
  end

  private def generate_readme
    readme_content = @json_data.body
    File.write(File.join(@output_dir, "README.md"), readme_content)
  end

  private def generate_index
    program = @json_data.program
    repository_name = @json_data.project_info.name
    
    content = String.build do |io|
      io.puts "# #{repository_name} API Documentation"
      io.puts
      io.puts "## Top Level Namespace"
      io.puts
      
      # Add program summary if available
      if summary = program.formatted_summary
        io.puts summary
      end
      
      # List all types
      io.puts
      io.puts "## Types"
      io.puts
      
      # Create a table of types
      io.puts "| Name | Kind | Description |"
      io.puts "|------|------|-------------|"
      
      all_types = collect_all_types(program)
      all_types.each do |type|
        kind = type.kind
        name = type.name
        summary = type.formatted_summary || ""
        # Remove HTML tags from summary
        summary = summary.gsub(/<[^>]*>/, "")
        
        # Create link to type file
        type_link = "[#{name}](#{type_filename(type)})"
        
        io.puts "| #{type_link} | #{kind} | #{summary} |"
      end
    end
    
    File.write(File.join(@output_dir, "index.md"), content)
  end

  private def generate_type_files
    all_types = collect_all_types(@json_data.program)
    
    all_types.each do |type|
      content = generate_type_content(type)
      filename = type_filename(type)
      File.write(File.join(@output_dir, filename), content)
    end
  end

  private def generate_type_content(type)
    String.build do |io|
      # Type header
      io.puts "# #{type.name}"
      io.puts
      
      # Type kind and inheritance
      io.puts "**#{type.kind.capitalize}**"
      
      if type.superclass
        io.puts
        io.puts "Inherits: #{type_link(type.superclass)}"
      end
      
      # Included modules
      unless type.included_modules.empty?
        io.puts
        io.puts "Includes:"
        type.included_modules.each do |mod|
          io.puts "* #{type_link(mod)}"
        end
      end
      
      # Extended modules
      unless type.extended_modules.empty?
        io.puts
        io.puts "Extends:"
        type.extended_modules.each do |mod|
          io.puts "* #{type_link(mod)}"
        end
      end
      
      # Type documentation
      if doc = type.doc
        io.puts
        io.puts doc.gsub(/<[^>]*>/, "")
      end
      
      # Constants
      unless type.constants.empty?
        io.puts
        io.puts "## Constants"
        io.puts
        
        io.puts "| Name | Value | Description |"
        io.puts "|------|-------|-------------|"
        
        type.constants.each do |constant|
          name = constant.name
          value = constant.value.to_s.gsub(/<[^>]*>/, "")
          summary = constant.formatted_summary.to_s.gsub(/<[^>]*>/, "")
          
          io.puts "| #{name} | #{value} | #{summary} |"
        end
      end
      
      # Class methods
      unless type.class_methods.empty?
        io.puts
        io.puts "## Class Methods"
        io.puts
        
        type.class_methods.each do |method|
          generate_method_documentation(io, method)
        end
      end
      
      # Constructors
      unless type.constructors.empty?
        io.puts
        io.puts "## Constructors"
        io.puts
        
        type.constructors.each do |constructor|
          generate_method_documentation(io, constructor)
        end
      end
      
      # Instance methods
      unless type.instance_methods.empty?
        io.puts
        io.puts "## Instance Methods"
        io.puts
        
        type.instance_methods.each do |method|
          generate_method_documentation(io, method)
        end
      end
      
      # Macros
      unless type.macros.empty?
        io.puts
        io.puts "## Macros"
        io.puts
        
        type.macros.each do |macro_def|
          generate_macro_documentation(io, macro_def)
        end
      end
      
      # Nested types
      unless type.types.empty?
        io.puts
        io.puts "## Nested Types"
        io.puts
        
        io.puts "| Name | Kind | Description |"
        io.puts "|------|------|-------------|"
        
        type.types.each do |nested_type|
          kind = nested_type.kind
          name = nested_type.name
          summary = nested_type.formatted_summary.to_s.gsub(/<[^>]*>/, "")
          
          # Create link to type file
          type_link = "[#{name}](#{type_filename(nested_type)})"
          
          io.puts "| #{type_link} | #{kind} | #{summary} |"
        end
      end
    end
  end

  private def generate_method_documentation(io, method)
    # Method signature
    io.puts "### #{method.name}"
    io.puts
    io.puts "```crystal"
    io.puts method.to_s.gsub(/<[^>]*>/, "")
    io.puts "```"
    io.puts
    
    # Method documentation
    if doc = method.doc
      io.puts doc.gsub(/<[^>]*>/, "")
      io.puts
    end
  end

  private def generate_macro_documentation(io, macro_def)
    # Macro signature
    io.puts "### #{macro_def.name}"
    io.puts
    io.puts "```crystal"
    io.puts macro_def.to_s.gsub(/<[^>]*>/, "")
    io.puts "```"
    io.puts
    
    # Macro documentation
    if doc = macro_def.doc
      io.puts doc.gsub(/<[^>]*>/, "")
      io.puts
    end
  end

  private def collect_all_types(program)
    result = [] of Type
    collect_types(program, result)
    result
  end

  private def collect_types(type, types)
    types << type
    
    type.types.each do |subtype|
      collect_types(subtype, types)
    end
  end

  private def type_filename(type)
    return "unknown.md" unless type
    if type.program?
      "toplevel.md"
    else
      "#{type.full_name.gsub(/::|~|\*|\+|-|\/|=|&|\?|\|/, "_")}.md"
    end
  end

  private def type_link(type)
    return "Unknown" unless type
    "[#{type.name}](#{type_filename(type)})"
  end
end
