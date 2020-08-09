package bp.directory.macros;

import tink.macro.BuildCache;
import haxe.macro.Expr;
import haxe.macro.Type;
import tink.typegen.Generator;
import tink.typegen.FieldInfo;

using tink.MacroApi;
using tink.CoreApi;

class GenBase {
	public function new() {}

	public function nullable(e:Type):Type
		return throw 'abstract';

	public function string():Type
		return throw 'abstract';

	public function float():Type
		return throw 'abstract';

	public function int():Type
		return throw 'abstract';

	public function dyn(e:Type, ct:ComplexType):Type
		return throw 'abstract';

	public function dynAccess(e:Type):Type
		return throw 'abstract';

	public function bool():Type
		return throw 'abstract';

	public function date():Type
		return throw 'abstract';

	public function bytes():Type
		return throw 'abstract';

	public function anon(fields:Array<FieldInfo<Type>>, ct:ComplexType):Type
		return throw 'abstract';

	public function array(e:Type):Type
		return throw 'abstract';

	public function map(k:Type, v:Type):Type
		return throw 'abstract';

	public function enm(constructors:Array<EnumConstructor<Type>>, ct:ComplexType, pos:Position, gen:GenType<Type>):Type
		return throw 'abstract';

	public function enumAbstract(names:Array<Expr>, e:Type, ct:ComplexType, pos:Position):Type
		return throw 'abstract';

	public function rescue(t:Type, pos:Position, gen:GenType<Type>):Option<Type> {
    // #if tink_json
    //   return new 
    // #else
    return throw 'abstract: $t';
	}

	public function reject(t:Type):String
		return throw 'abstract: $t';

	public function shouldIncludeField(c:ClassField, owner:Option<ClassType>):Bool
		return true;

	public function drive(type:Type, pos:Position, gen:GenType<Type>):Type
		return gen(type, pos);

	function generate(type:String, builder:String->Array<Type>->TypeDefinition):Type {
		return BuildCache.getTypeN(type, ctx -> builder(ctx.name, ctx.types));
	}
}
