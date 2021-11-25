@[Link("oleaut32")]
lib LibC
  alias BSTR = WCHAR*

  fun SysFreeString(bstrString : BSTR)
end
