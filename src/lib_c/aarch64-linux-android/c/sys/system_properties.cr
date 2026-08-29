lib LibC
  {% if ANDROID_API >= 26 %}
    alias PropInfo = Void

    fun __system_property_find(__name : Char*) : PropInfo*
    fun __system_property_read_callback(__pi : PropInfo*, __callback : (Void*, Char*, Char*, UInt32 ->), __cookie : Void*)
  {% else %}
    PROP_VALUE_MAX = 92

    fun __system_property_get(__name : Char*, __value : Char*) : Int
  {% end %}
end
