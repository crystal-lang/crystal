require_relative "to_s.rb"

module Crystal
  class ASTNode
    def to_html(dir, filename, in_main = true)
      path = File.join(dir, filename)
      return if File.exists?(path)
      File.write(path, "")
      visitor = ToHTMLVisitor.new(dir, in_main)
      self.accept visitor
      title = case self
      when Crystal::Def
        "#{self.owner}##{self.name}(#{self.args.map(&:type).join ', '})"
      else
        "main"
      end
      File.write(path, %(<html><body><h1>#{title}</h1><pre>#{visitor.to_s}</pre></body></html>))
    end
  end

  class ToHTMLVisitor < ToSVisitor
    def initialize(dir, in_main)
      @dir = dir
      @in_main = in_main
      super()
    end

    def visit_call(node)
      if node.target_defs
        node.target_defs.each do |target_def|
          target_def.to_html(@dir, "#{target_def.object_id}.html", false)
        end

        if node.target_defs.length > 1
          selector = "<html><body><ul>"
          node.target_defs.each do |target_def|
            selector << "<li><a href='#{target_def.object_id}.html'>#{target_def.owner}##{target_def.name}(#{target_def.args.map(&:type).join ', '})</a></li>"
          end
          selector << "</ul></body></html>"
          File.write(File.join(@dir, "#{node.object_id}.html"), selector)
        end
      end
      super
    end

    def decorate_call(node, str)
      link = if node.target_defs == nil
        ""
      elsif node.target_defs.length == 1
        node.target_defs.first.object_id
      else
        node.object_id
      end
      "<a href='#{link}.html' title='#{node.type}'>#{str}</a>"
    end

    def decorate_var(node, str)
      "<span title='#{node.type}'>#{str}</span>"
    end

    def visit_def(node)
      super unless @in_main
    end

    def visit_class_def(node)
      false
    end

    def visit_module_def(node)
      false
    end

    def visit_lib_def(node)
      false
    end
  end
end
