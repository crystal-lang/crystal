lib LibC
  WIN32_WINNT_WIN7  = 0x0601
  WIN32_WINNT_WIN8  = 0x0602
  WIN32_WINNT_WIN10 = 0x0A00 # includes Windows 11 too

  # add other version flags here, or use mechanisms other than flags
  {% if flag?(:win7) %}
    WIN32_WINNT = {{ WIN32_WINNT_WIN7 }}
  {% else %}
    # TODO - detect host version using `cmd.exe /c ver`, environment variable or some other way.
    WIN32_WINNT = {{ WIN32_WINNT_WIN10 }}
  {% end %}
end
