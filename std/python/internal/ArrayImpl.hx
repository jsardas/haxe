/*
 * Copyright (C)2005-2012 Haxe Foundation
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

package python.internal;

import python.lib.FuncTools;
import python.internal.HxBuiltin;

@:allow(Array)
@:keep
class ArrayImpl {



	public static inline function get_length <T>(x:Array<T>):Int return HxBuiltin.len(x);

	public static inline function concat<T>( a1:Array<T>, a2 : Array<T>) : Array<T> {
		return Syntax.binop(a1, "+", a2);
	}

	public static inline function copy<T>(x:Array<T>) : Array<T> {
		return Syntax.field(HxBuiltin, "list")(x);
	}

	public static inline function iterator<T>(x:Array<T>) : Iterator<T> {
		return new HaxeIterator(Syntax.callField(x, "__iter__"));
	}

	public static function indexOf<T>(a:Array<T>, x : T, ?fromIndex:Int) : Int {
		var l =
			if (fromIndex == null) 0
			else if (fromIndex < 0) a.length + fromIndex
			else fromIndex;
		if (l < 0) l = 0;
		for (i in l...a.length) {
			if (a[i] == x) return i;
		}
		return -1;
	}

	public static function lastIndexOf<T>(a:Array<T>, x : T, ?fromIndex:Int) : Int {
		var l =
			if (fromIndex == null) a.length
			else if (fromIndex < 0) a.length + fromIndex + 1
			else fromIndex+1;
		if (l > a.length) l = a.length;
		while (--l > -1) {
			if (a[l] == x) return l;
		}
		return -1;
	}

	@:access(python.Boot)
	public static inline function join<T>(x:Array<T>, sep : String ) : String {
		return Syntax.field(sep, "join")(Syntax.pythonCode("[{0}(x1) for x1 in {1}]", python.Boot.toString, x));
	}

	public static inline function toString<T>(x:Array<T>) : String {
		return "[" + join(x, ",") + "]";
	}

	public static inline function pop<T>(x:Array<T>) : Null<T> {
		return if (x.length == 0) null else Syntax.callField(x, "pop");
	}

	public static inline function push<T>(x:Array<T>, e:T) : Int {
		Syntax.callField(x, "append", e);
		return get_length(x);
	}

	public static inline function unshift<T>(x:Array<T>,e : T) : Void {
		return x.insert(0,e);
	}

	public static function remove<T>(x:Array<T>,e : T) : Bool {
		try {
			Syntax.callField(x, "remove", e);
			return true;
		} catch (e:Dynamic) {
			return false;
		}
	}

	public static inline function shift<T>(x:Array<T>) : Null<T> {
		if (x.length == 0) return null;
		return Syntax.callField(x, "pop", 0);
	}

	public static inline function slice<T>(x:Array<T>, pos : Int, ?end : Int ) : Array<T> {
		return Syntax.arrayAccess(x, pos, end);
	}

	public static inline function sort<T>(x:Array<T>, f:T->T->Int) : Void {
		Syntax.callNamedUntyped(Syntax.field(x, "sort"), { key : python.lib.FuncTools.cmp_to_key(f) });
	}

	public static inline function splice<T>(x:Array<T>, pos : Int, len : Int ) : Array<T> {
		if (pos < 0) pos = x.length+pos;
		if (pos < 0) pos = 0;
		var res = Syntax.arrayAccess(x, pos, pos+len);
		Syntax.delete((Syntax.arrayAccess(x, pos, pos+len)));
		return res;
	}

	public static inline function map<S,T>(x:Array<T>, f : T -> S ) : Array<S> {
		return Syntax.field(HxBuiltin, "list")(Syntax.field(HxBuiltin, "map")(f, x));
	}

	public static inline function filter<T>(x:Array<T>, f : T -> Bool ) : Array<T> {
		return Syntax.field(HxBuiltin, "list")(Syntax.field(HxBuiltin, "filter")(f, x));
	}

	public static inline function insert<T>(a:Array<T>, pos : Int, x : T ) : Void {
		Syntax.callField(a, "insert", pos, x);
	}

	public static inline function reverse<T>(a:Array<T>) : Void {
		Syntax.callField(a, "reverse");
	}

	private static inline function _get<T>(x:Array<T>, idx:Int):T {
		return if (idx > -1 && idx < x.length) Syntax.arrayAccess(x, idx) else null;
	}

	private static inline function _set<T>(x:Array<T>, idx:Int, v:T):T {
		var l = x.length;
		while (l < idx) {
			x.push(null);
			l+=1;
		}
		if (l == idx) {
			x.push(v);
		} else {
			Syntax.assign(Syntax.arrayAccess(x, idx), v);
		}
		return v;
	}

	private static inline function __unsafe_get<T>(x:Array<T>,idx:Int):T {
		return Syntax.arrayAccess(x, idx);
	}

	private static inline function __unsafe_set<T>(x:Array<T>,idx:Int, val:T):T {
		Syntax.assign(Syntax.arrayAccess(x, idx), val);
		return val;
	}
}