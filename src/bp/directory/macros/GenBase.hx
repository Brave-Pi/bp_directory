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
  public function nullable(e:Type):Type return haxe.macro.Context.fatalError('abstract', null);
  public function string():Type return haxe.macro.Context.fatalError('abstract', null);
  public function float():Type return haxe.macro.Context.fatalError('abstract', null);
  public function int():Type return haxe.macro.Context.fatalError('abstract', null);
  public function dyn(e:Type, ct:ComplexType):Type return haxe.macro.Context.fatalError('abstract', null);
  public function dynAccess(e:Type):Type return haxe.macro.Context.fatalError('abstract', null);
  public function bool():Type return haxe.macro.Context.fatalError('abstract', null);
  public function date():Type return haxe.macro.Context.fatalError('abstract', null);
  public function bytes():Type return haxe.macro.Context.fatalError('abstract', null);
  public function anon(fields:Array<FieldInfo<Type>>, ct:ComplexType):Type return haxe.macro.Context.fatalError('abstract', null);
  public function array(e:Type):Type return haxe.macro.Context.fatalError('abstract', null);
  public function map(k:Type, v:Type):Type return haxe.macro.Context.fatalError('abstract', null);
  public function enm(constructors:Array<EnumConstructor<Type>>, ct:ComplexType, pos:Position, gen:GenType<Type>):Type return haxe.macro.Context.fatalError('abstract', null);
  public function enumAbstract(names:Array<Expr>, e:Type, ct:ComplexType, pos:Position):Type return haxe.macro.Context.fatalError('abstract', null);
  public function rescue(t:Type, pos:Position, gen:GenType<Type>):Option<Type> return haxe.macro.Context.fatalError('abstract: $t', null);
  public function reject(t:Type):String return haxe.macro.Context.fatalError('abstract', null);
  public function shouldIncludeField(c:ClassField, owner:Option<ClassType>):Bool return true;
  public function drive(type:Type, pos:Position, gen:GenType<Type>):Type return gen(type, pos);
  function generate(type:String, builder:String->Array<Type>->TypeDefinition):Type {
    return BuildCache.getTypeN(type, ctx -> builder(ctx.name, ctx.types));
  }
}