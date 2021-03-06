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
package haxe.macro;
import haxe.macro.Expr;

/**
	All these methods can be called for compiler configuration macros.
**/
class Compiler {

	macro static public function getDefine( key : String ) {
		return macro $v{haxe.macro.Context.definedValue(key)};
	}

#if neko

	static var ident = ~/^[A-Za-z_][A-Za-z0-9_]*$/;
	static var path = ~/^[A-Za-z_][A-Za-z0-9_.]*$/;

	public static function allowPackage( v : String ) {
		untyped load("allow_package", 1)(v.__s);
	}

	public static function define( flag : String, ?value : String ) untyped {
		var v = flag + (value == null ? "" : "= " + value);
		load("define", 1)(v.__s);
	}

	public static function removeField( className : String, field : String, ?isStatic : Bool ) {
		if( !path.match(className) ) throw "Invalid "+className;
		if( !ident.match(field) ) throw "Invalid "+field;
		untyped load("type_patch",4)(className.__s,field.__s,isStatic == true,null);
	}

	public static function setFieldType( className : String, field : String, type : String, ?isStatic : Bool ) {
		if( !path.match(className) ) throw "Invalid "+className;
		if( !ident.match((field.charAt(0) == "$") ? field.substr(1) : field) ) throw "Invalid "+field;
		untyped load("type_patch",4)(className.__s,field.__s,isStatic == true,type.__s);
	}

	public static function addMetadata( meta : String, className : String, ?field : String, ?isStatic : Bool ) {
		if( !path.match(className) ) throw "Invalid "+className;
		if( field != null && !ident.match(field) ) throw "Invalid "+field;
		untyped load("meta_patch",4)(meta.__s,className.__s,(field == null)?null:field.__s,isStatic == true);
	}

	public static function addClassPath( path : String ) {
		untyped load("add_class_path",1)(path.__s);
	}

	public static function getOutput() : String {
		return new String(untyped load("get_output",0)());
	}

	public static function setOutput( fileOrDir : String ) {
		untyped load("set_output",1)(untyped fileOrDir.__s);
	}

	public static function getDisplayPos() : Null<{ file : String, pos : Int }> {
		var o = untyped load("get_display_pos",0)();
		if( o != null )
			o.file = new String(o.file);
		return o;
	}

	/**
		Adds a native library depending on the platform (eg : -swf-lib for Flash)
	**/
	public static function addNativeLib( name : String ) {
		untyped load("add_native_lib",1)(name.__s);
	}

	/**
		Includes all modules in package `pack` in the compilation.

		In order to include single modules, their paths can be listed directly
		on command line: `haxe ... ModuleName pack.ModuleName`.

		@param rec If true, recursively adds all sub-packages.
		@param ignore Array of module names to ignore for inclusion.
		@param classPaths Array of additional class paths to check. This can be
		    used to add packages outside the usual class paths.
	**/
	public static function include( pack : String, ?rec = true, ?ignore : Array<String>, ?classPaths : Array<String> ) {
		var skip = if( ignore == null ) {
			function(c) return false;
		} else {
			function(c) return Lambda.has(ignore, c);
		}
		if( classPaths == null ) {
			classPaths = Context.getClassPath();
			// do not force inclusion when using completion
			if( Context.defined("display") )
				return;
			// normalize class path
			for( i in 0...classPaths.length ) {
				var cp = StringTools.replace(classPaths[i], "\\", "/");
				if(StringTools.endsWith(cp, "/"))
					cp = cp.substr(0, -1);
				if( cp == "" )
					cp = ".";
				classPaths[i] = cp;
			}
		}
		var prefix = pack == '' ? '' : pack + '.';
		for( cp in classPaths ) {
			var path = pack == '' ? cp : cp + "/" + pack.split(".").join("/");
			if( !sys.FileSystem.exists(path) || !sys.FileSystem.isDirectory(path) )
				continue;
			for( file in sys.FileSystem.readDirectory(path) ) {
				if( StringTools.endsWith(file, ".hx") ) {
					var cl = prefix + file.substr(0, file.length - 3);
					if( skip(cl) )
						continue;
					Context.getModule(cl);
				} else if( rec && sys.FileSystem.isDirectory(path + "/" + file) && !skip(prefix + file) )
					include(prefix + file, true, ignore, classPaths);
			}
		}
	}

	/**
		Exclude a given class or a complete package from being generated.
	**/
	public static function exclude( pack : String, ?rec = true ) {
		Context.onGenerate(function(types) {
			for( t in types ) {
				var b : Type.BaseType, name;
				switch( t ) {
				case TInst(c, _):
					name = c.toString();
					b = c.get();
				case TEnum(e, _):
					name = e.toString();
					b = e.get();
				default: continue;
				}
				var p = b.pack.join(".");
				if( (p == pack || name == pack) || (rec && StringTools.startsWith(p, pack + ".")) )
					b.exclude();
			}
		});
	}

	/**
		Exclude classes listed in an extern file (one per line) from being generated.
	**/
	public static function excludeFile( fileName : String ) {
		fileName = Context.resolvePath(fileName);
		var f = sys.io.File.read(fileName,true);
		var classes = new haxe.ds.StringMap();
		try {
			while( true ) {
				var l = StringTools.trim(f.readLine());
				if( l == "" || !~/[A-Za-z0-9._]/.match(l) )
					continue;
				classes.set(l,true);
			}
		} catch( e : haxe.io.Eof ) {
		}
		Context.onGenerate(function(types) {
			for( t in types ) {
				switch( t ) {
				case TInst(c, _): if( classes.exists(c.toString()) ) c.get().exclude();
				case TEnum(e, _): if( classes.exists(e.toString()) ) e.get().exclude();
				default:
				}
			}
		});
	}

	/**
		Load a type patch file that can modify declared classes fields types
	**/
	public static function patchTypes( file : String ) : Void {
		var file = Context.resolvePath(file);
		var f = sys.io.File.read(file, true);
		try {
			while( true ) {
				var r = StringTools.trim(f.readLine());
				if( r == "" || r.substr(0,2) == "//" ) continue;
				if( StringTools.endsWith(r,";") ) r = r.substr(0,-1);
				if( r.charAt(0) == "-" ) {
					r = r.substr(1);
					var isStatic = StringTools.startsWith(r,"static ");
					if( isStatic ) r = r.substr(7);
					var p = r.split(".");
					var field = p.pop();
					removeField(p.join("."),field,isStatic);
					continue;
				}
				if( r.charAt(0) == "@" ) {
					var rp = r.split(" ");
					var type = rp.pop();
					var isStatic = rp[rp.length - 1] == "static";
					if( isStatic ) rp.pop();
					var meta = rp.join(" ");
					var p = type.split(".");
					var field = if( p.length > 1 && p[p.length-2].charAt(0) >= "a" ) null else p.pop();
					addMetadata(meta,p.join("."),field,isStatic);
					continue;
				}
				if( StringTools.startsWith(r, "enum ") ) {
					define("fakeEnum:" + r.substr(5));
					continue;
				}
				var rp = r.split(" : ");
				if( rp.length > 1 ) {
					r = rp.shift();
					var isStatic = StringTools.startsWith(r,"static ");
					if( isStatic ) r = r.substr(7);
					var p = r.split(".");
					var field = p.pop();
					setFieldType(p.join("."),field,rp.join(" : "),isStatic);
					continue;
				}
				throw "Invalid type patch "+r;
			}
		} catch( e : haxe.io.Eof ) {
		}
	}

	/**
		Marks types or packages to be kept by DCE and includes them for
		compilation.

		This also extends to the sub-types of resolved modules.

		In order to include module sub-types directly, their full dot path
		including the containing module has to be used
		(e.g. msignal.Signal.Signal0).

		@param path A package, module or sub-type dot path to keep.
		@param paths An Array of package, module or sub-type dot paths to keep.
		@param recursive If true, recurses into sub-packages for package paths.
	**/
	public static function keep(?path : String, ?paths : Array<String>, ?recursive:Bool = true)
	{
		if (null == paths)
			paths = [];
		if (null != path)
			paths.push(path);
		for (path in paths) {
			var found:Bool = false;
			var moduleFirstCharacter:String = ((path.indexOf(".") < 0)?path:path.substring(path.lastIndexOf(".")+1)).charAt(0);
			var startsWithUpperCase:Bool = (moduleFirstCharacter == moduleFirstCharacter.toUpperCase());//needed because FileSystem is not case sensitive
			var moduleRoot = (path.indexOf(".") < 0)?"":path.substring(0, path.lastIndexOf("."));
			var moduleRootFirstCharacter:String = ((moduleRoot.indexOf(".") < 0)?moduleRoot:moduleRoot.substring(moduleRoot.lastIndexOf(".")+1)).charAt(0);
			var rootStartsWithUpperCase:Bool = (moduleRootFirstCharacter == moduleRootFirstCharacter.toUpperCase());//needed because FileSystem is not case sensitive
			for ( classPath in Context.getClassPath() ) {
				var moduleRootPath = (moduleRoot == "")?"":(classPath + moduleRoot.split(".").join("/") + ".hx");
				var fullPath = classPath + path.split(".").join("/");
				var isValidModule:Bool = startsWithUpperCase && sys.FileSystem.exists(fullPath + ".hx");
				var isValidSubType:Bool = !isValidModule && moduleRootPath != "" && rootStartsWithUpperCase && sys.FileSystem.exists(moduleRootPath);
				var isValidDirectory:Bool = !isValidSubType && sys.FileSystem.exists(fullPath) && sys.FileSystem.isDirectory(fullPath);
				if ( !isValidDirectory && !isValidModule && !isValidSubType)
					continue;
				else
					found = true;

				if(isValidDirectory) {
					for( file in sys.FileSystem.readDirectory(fullPath) ) {
						if( StringTools.endsWith(file, ".hx") ) {
							var module = path + "." + file.substr(0, file.length - 3);
							keepModule(module);
						} else if( recursive && sys.FileSystem.isDirectory(fullPath + "/" + file) )
							keep(path + "." + file, true);
					}
				} else if(isValidModule){
					keepModule(path);
				} else if(isValidSubType){
					keepSubType(path);
				}
			}

			if (!found)
				Context.warning("file or directory not found, can't keep: "+path, Context.currentPos());
		}
	}

	private static function keepSubType( path : String )
	{
		var module = path.substring(0, path.lastIndexOf("."));
		var subType = module.substring(0, module.lastIndexOf(".")) + "." + path.substring(path.lastIndexOf(".") + 1);
		var types = Context.getModule(module);
		var found:Bool = false;
		for (type in types) {
			switch(type) {
				case TInst(cls, _):
					if (cls.toString() == subType) {
						found = true;
						cls.get().meta.add(":keep", [], cls.get().pos);
					}
				default:
					//
			}
		}

		if (!found)
			Context.warning("subtype not found, can't keep: "+path, Context.currentPos());
	}

	private static function keepModule( path : String )
	{
		var types = Context.getModule(path);
		for (type in types) {
			switch(type) {
				case TInst(cls, _):
					cls.get().meta.add(":keep", [], cls.get().pos);
				default:
					//
			}
		}
	}

	/**
		Change the default JS output by using a custom generator callback
	**/
	public static function setCustomJSGenerator( callb : JSGenApi -> Void ) {
		load("custom_js",1)(callb);
	}

	static function load( f, nargs ) : Dynamic {
		#if macro
		return neko.Lib.load("macro", f, nargs);
		#else
		return Reflect.makeVarArgs(function(_) return throw "Can't be called outside of macro");
		#end
	}

#end

	#if (js || macro)
	/**
		Embed an on-disk javascript file (can be called into an __init__ method)
	**/
	public static macro function includeFile( fileName : Expr ) {
		var str = switch( fileName.expr ) {
		case EConst(c):
			switch( c ) {
			case CString(str): str;
			default: null;
			}
		default: null;
		}
		if( str == null ) Context.error("Should be a constant string", fileName.pos);
		var f = try sys.io.File.getContent(Context.resolvePath(str)) catch( e : Dynamic ) Context.error(Std.string(e), fileName.pos);
		var p = Context.currentPos();
		return { expr : EUntyped( { expr : ECall( { expr : EConst(CIdent("__js__")), pos : p }, [ { expr : EConst(CString(f)), pos : p } ]), pos : p } ), pos : p };
	}
	#end

}
