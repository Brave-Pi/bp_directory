package bp.directory.macros;

import haxe.macro.Type;
import haxe.macro.Context;
using bp.directory.macros.Tools;
#if macro
class Tools {
	public static function getTypeParam(type:haxe.macro.Type)
		return switch (type) {
			case TInst(_, [t1]):
				t1;
			case t:
				Context.error("Class expected", Context.currentPos());
		}

	public static function run(gen:bp.directory.macros.GenBase, type:Type)
		return tink.typegen.Crawler.crawl(type.getTypeParam(), (macro null).pos, gen).ret;
}
#end
