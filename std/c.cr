lib C
  fun getchar : Char
  fun putchar(c : Char) : Char
  fun puts(str : String) : Int
  fun atoi(str : String) : Int
  fun rand : Int
  fun srand(seed : Int)
  fun time(t : Long) : Long
  fun fork : Int
  fun exit(status : Int)
  fun getenv(str : String) : String

  type File : Pointer

  fun fopen(filename : String, mode : String) : File
  fun fputs(str : String, file : File) : Int
  fun fclose(file : File) : Int
end
