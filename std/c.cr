lib C
  fun getchar : Char
  fun putchar(c : Char) : Char
  fun strlen(str : String) : Int
  fun puts(str : String) : Int
  fun atoi(str : String) : Int
  fun rand : Int
  fun srand(seed : Int)
  fun time(t : Long) : Long
  fun fork : Int
  fun exit(status : Int)
  fun getenv(str : String) : String

  fun fopen(filename : String, mode : String) : Pointer
  fun fputs(str : String, file : Pointer) : Int
  fun fclose(file : Pointer) : Int
end
