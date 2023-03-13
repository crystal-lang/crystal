lib LibC
  WIN32_WINNT_WIN7  = 0x0601
  WIN32_WINNT_WIN8  = 0x0602
  WIN32_WINNT_WIN10 = 0x0A00 # includes Windows 11 too

  # add other version flags here, or use mechanisms other than flags
  {% if flag?(:win7) %}
    WIN32_WINNT = WIN32_WINNT_WIN7
  {% else %}
    {% ver_str = `cmd.exe /c ver` %}
    {% major, minor = ver_str.gsub(/.*?(\d+)\.(\d+).*/m, "").split %}
    WIN32_WINNT = {{ major.to_i * 0x100 + minor.to_i }}
  {% end %}
end
