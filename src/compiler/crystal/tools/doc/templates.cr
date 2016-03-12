require "ecr/macros"

module Crystal::Doc
  record TypeTemplate, type : Type, types : Array(Type) do
    ECR.def_to_s "#{__DIR__}/html/type.html"
  end

  record ListItemsTemplate, types : Array(Type), current_type : Type? do
    ECR.def_to_s "#{__DIR__}/html/list_items.html"
  end

  record MethodSummaryTemplate, title : String, methods : Array(Method) | Array(Macro) do
    ECR.def_to_s "#{__DIR__}/html/method_summary.html"
  end

  record MethodDetailTemplate, title : String, methods : Array(Method) | Array(Macro) do
    ECR.def_to_s "#{__DIR__}/html/method_detail.html"
  end

  record MethodsInheritedTemplate, type : Type, ancestor : Type, methods : Array(Method), label : String do
    ECR.def_to_s "#{__DIR__}/html/methods_inherited.html"
  end

  record OtherTypesTemplate, title : String, type : Type, other_types : Array(Type) do
    ECR.def_to_s "#{__DIR__}/html/other_types.html"
  end

  record MainTemplate, body : String, types : Array(Type), repository_name : String do
    ECR.def_to_s "#{__DIR__}/html/main.html"
  end

  struct JsTypeTemplate
    ECR.def_to_s "#{__DIR__}/html/js/doc.js"
  end

  struct StyleTemplate
    ECR.def_to_s "#{__DIR__}/html/css/style.css"
  end
end
