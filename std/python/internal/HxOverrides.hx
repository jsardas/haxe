package python.internal;

import python.Syntax;

import python.Syntax.pythonCode in py;

@:keep
@:native("HxOverrides")
@:access(python.internal.ArrayImpl)
@:access(python.Boot)
class HxOverrides {

	// this two cases iterator and shift are like all methods in String and Array and are already handled in Reflect
	// we need to modify the transformer to call Reflect directly

	static public function iterator(x) {
		if (Boot.isArray(x)) {
			return (x:Array<Dynamic>).iterator();
		}
		return Syntax.callField(x, "iterator");
	}

	static function eq( a:Dynamic, b:Dynamic ) : Bool {
		if (Boot.isArray(a) || Boot.isArray(b)) {
			return Syntax.pythonCode('a is b');
		}
		return Syntax.binop(a, "==", b);
	}

	static function stringOrNull (s:String):String {
		return if (s == null) "null" else s;
	}

	static public function shift(x) {
		return Reflect.callMethod(null, Reflect.field(x, "shift"), []);
	}
	static public function toUpperCase(x) {
		return Reflect.callMethod(null, Reflect.field(x, "toUpperCase"), []);
	}

	static public function toLowerCase(x) {
		return Reflect.callMethod(null, Reflect.field(x, "toLowerCase"), []);
	}

	static public function rshift(val:Int, n:Int) {
		return Syntax.binop(Syntax.binop(val, "%", Syntax.pythonCode("0x100000000")), ">>", n);
	}

	static public function modf(a:Float, b:Float) {
		return Syntax.pythonCode("float('nan') if (b == 0.0) else a % b if a > 0 else -(-a % b)");
	}

	static public function arrayGet<T>(a:Dynamic, i:Int):Dynamic {
		if (Boot.isArray(a)) {
			return ArrayImpl._get(a, i);
		} else {
			return Syntax.arrayAccess(a, i);
		}
	}

	static public function arraySet(a:Dynamic, i:Int, v:Dynamic) {
		if (Boot.isArray(a)) {
			return ArrayImpl._set(a, i, v);
		} else {
			Syntax.assign(Syntax.arrayAccess(a, i), v);
			return v;
		}
	}

}