import haxe.macro.Expr;

class HelloWorld {
    static public function add2(x, y) {
      return x + y;
    }

    macro static function add(e:Expr) {
      var x = add2(1, 2);
      return new Expr(x);
    }

    static public function main() {
      add(1);
    }
}