require "ecr/macros"

module Crystal::Doc
  SVG_DEFS = <<-SVG
  <svg class="hidden">
    <symbol id="octicon-link" viewBox="0 0 16 16">
      <path fill="currentColor" fill-rule="evenodd" d="M4 9h1v1H4c-1.5 0-3-1.69-3-3.5S2.55 3 4 3h4c1.45 0 3 1.69 3 3.5 0 1.41-.91 2.72-2 3.25V8.59c.58-.45 1-1.27 1-2.09C10 5.22 8.98 4 8 4H4c-.98 0-2 1.22-2 2.5S3 9 4 9zm9-3h-1v1h1c1 0 2 1.22 2 2.5S13.98 12 13 12H9c-.98 0-2-1.22-2-2.5 0-.83.42-1.64 1-2.09V6.25c-1.09.53-2 1.84-2 3.25C6 11.31 7.55 13 9 13h4c1.45 0 3-1.69 3-3.5S14.5 6 13 6z"></path>
    </symbol>
  </svg>
  SVG

  SIDEBAR_BUTTON = <<-HTML
  <input type="checkbox" id="sidebar-btn">
  <label for="sidebar-btn" id="sidebar-btn-label">
    <svg class="open" xmlns="http://www.w3.org/2000/svg" height="2em" width="2em" viewBox="0 0 512 512"><title>Open Sidebar</title><path fill="currentColor" d="M80 96v64h352V96H80zm0 112v64h352v-64H80zm0 112v64h352v-64H80z"></path></svg>
    <svg class="close" xmlns="http://www.w3.org/2000/svg" width="2em" height="2em" viewBox="0 0 512 512"><title>Close Sidebar</title><path fill="currentColor" d="m118.6 73.4-45.2 45.2L210.7 256 73.4 393.4l45.2 45.2L256 301.3l137.4 137.3 45.2-45.2L301.3 256l137.3-137.4-45.2-45.2L256 210.7Z"></path></svg>
  </label>
  HTML

  def self.anchor_link(anchor : String)
    anchor = anchor.downcase.gsub(' ', '-')

    <<-HTML
    <a id="#{anchor}" class="anchor" href="##{anchor}">
      <svg class="octicon-link" aria-hidden="true">
        <use href="#octicon-link"/>
      </svg>
    </a>
    HTML
  end

  record TypeTemplate, type : Type, types : Array(Type), project_info : ProjectInfo do
    ECR.def_to_s "#{__DIR__}/html/type.html"
  end

  record ListItemsTemplate, types : Array(Type), current_type : Type? do
    ECR.def_to_s "#{__DIR__}/html/_list_items.html"
  end

  record MethodSummaryTemplate, title : String, methods : Array(Method) | Array(Macro) do
    ECR.def_to_s "#{__DIR__}/html/_method_summary.html"
  end

  record MethodDetailTemplate, title : String, methods : Array(Method) | Array(Macro) do
    ECR.def_to_s "#{__DIR__}/html/_method_detail.html"
  end

  record MethodsInheritedTemplate, type : Type, ancestor : Type, methods : Array(Method), label : String do
    ECR.def_to_s "#{__DIR__}/html/_methods_inherited.html"
  end

  record OtherTypesTemplate, title : String, type : Type, other_types : Array(Type) do
    ECR.def_to_s "#{__DIR__}/html/_other_types.html"
  end

  record MainTemplate, body : String, types : Array(Type), project_info : ProjectInfo do
    ECR.def_to_s "#{__DIR__}/html/main.html"
  end

  record HeadTemplate, project_info : ProjectInfo, current_type : Type? do
    def base_path
      if current_type = self.current_type
        current_type.path_to ""
      else
        ""
      end
    end

    ECR.def_to_s "#{__DIR__}/html/_head.html"
  end

  record SidebarTemplate, project_info : ProjectInfo, types : Array(Type), current_type : Type? do
    ECR.def_to_s "#{__DIR__}/html/_sidebar.html"
  end

  record Error404Template do
    ECR.def_to_s "#{__DIR__}/html/404.html"
  end

  struct JsTypeTemplate
    ECR.def_to_s "#{__DIR__}/html/js/doc.js"
  end

  struct JsSearchTemplate
    ECR.def_to_s "#{__DIR__}/html/js/_search.js"
  end

  struct JsNavigatorTemplate
    ECR.def_to_s "#{__DIR__}/html/js/_navigator.js"
  end

  struct JsVersionsTemplate
    ECR.def_to_s "#{__DIR__}/html/js/_versions.js"
  end

  struct JsUsageModal
    ECR.def_to_s "#{__DIR__}/html/js/_usage-modal.js"
  end

  struct StyleTemplate
    ECR.def_to_s "#{__DIR__}/html/css/style.css"
  end

  record SitemapTemplate, types : Array(Type), base_url : String, priority : String, changefreq : String do
    ECR.def_to_s "#{__DIR__}/html/sitemap.xml"
  end
end
