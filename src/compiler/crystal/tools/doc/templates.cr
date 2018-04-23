require "ecr/macros"

module Crystal::Doc
  record TypeTemplate, type : Type, types : Array(Type), canonical_base_url : String? do
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

  record MainTemplate, body : String, types : Array(Type), repository_name : String, canonical_base_url : String? do
    ECR.def_to_s "#{__DIR__}/html/main.html"
  end

  record HeadTemplate, type : Type?, canonical_base_url : String? do
    ECR.def_to_s "#{__DIR__}/html/_head.html"
  end

  record SidebarTemplate, repository_name : String, types : Array(Type), current_type : Type? do
    ECR.def_to_s "#{__DIR__}/html/_sidebar.html"
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

  struct JsUsageModal
    ECR.def_to_s "#{__DIR__}/html/js/_usage-modal.js"
  end

  struct StyleTemplate
    ECR.def_to_s "#{__DIR__}/html/css/style.css"
  end
end
