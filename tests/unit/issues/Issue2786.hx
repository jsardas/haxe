package unit.issues;

@:enum
private abstract E(Int) to Int {
    var A = 1;
    var B = 2;
    @:op(a | b) static function or(a:E, b:E):E;
}

@:enum
private abstract E2(Int) to Int {
    var A = 1;
    var B = 2;
    @:op(a | b) static function or(a:E2, b:E2):E2;
    @:op(a | b) static function or2(a:E2, b:E2):E2;
}

class Issue2786 extends Test {
	function test() {
		var a:E = A | B;
		eq(3, a);

		t(unit.TestType.typeError((A | B : E2)));
	}
}