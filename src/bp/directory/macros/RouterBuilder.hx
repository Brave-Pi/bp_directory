package bp.directory.macros;

import bp.directory.macros.GenBase;
import tink.macro.BuildCache;
import haxe.macro.Context;
import tink.streams.Stream.Generator;
import haxe.macro.Expr;
import haxe.macro.Type;
import tink.typegen.FieldInfo;

using tink.MacroApi;
using Lambda;
#if macro
using bp.directory.macros.Tools;

class DirectoryRouterBuilder {
	public static function apply() {
		return new DirectoryRouterGen().run(Context.getLocalType());
	}
}

class EntityRouterBuilder {
	public static function apply() {
		return new EntityRouterGen().run(Context.getLocalType());
	}
}

class FieldRouterBuilder {
	public static function apply() {
		return new FieldRouterGen().run(Context.getLocalType());
	}
}

class EntityFieldRouterBuilder {
	public static function apply() {
		return new EntityFieldRouterGen().run(Context.getLocalType());
	}
}

class RouterGenBase extends GenBase {
	function getEntityPropertyRoutes(fields:Array<FieldInfo<Type>>, routerGen:ComplexType->Expr, ?useFactory = false)
		return [
			for (field in fields) {
				var name = field.name;
				var path = '/$name'.toExpr();
				var fCt = field.type.toComplex();
				(macro class {
					// Endpoints to list/update only single field, of collection etc..
					@:sub($path)
					public function $name() {
						${
							if (useFactory)
								macro var provider = providerFactory()
							else
								macro null
						};
						provider.projection.push($v{name});
						provider.scope.push($v{name});
						provider.selector = r -> r.$name;
						return ${routerGen(fCt)};
					}
				}).fields;
			}
		].fold((current, result : Array<Field>) -> {
			return result.concat(current);
		}, []);
}

class DirectoryRouterGen extends RouterGenBase {
	override function anon(fields:Array<FieldInfo<Type>>, ct:ComplexType):Type {
		return generate('bp.directory.routing.DirectoryRouter', (name, types) -> {
			var ct = types[0].toComplex();
			var additionalFields = getEntityPropertyRoutes(fields, ct -> macro new bp.directory.routing.Router.FieldRouter<$ct>(provider), true);

			var ret = macro class $name {
				var providerFactory:Void->bp.directory.Provider;

				public function new(dataset:String, providerFactory:Void->bp.directory.Provider) {
					this.providerFactory = () -> {
						var provider = providerFactory();
						provider.dataset = dataset;
						provider;
					};
				}

				// endpoint for single entity

				@:sub("/$id")
				public function getSingle(id:String) {
					var provider = providerFactory();
					provider.query.head["_id"] = id;
					return new bp.directory.routing.Router.EntityRouter<$ct>(provider);
				}
			};

			ret.fields = additionalFields.concat(ret.fields);
			ret;
		});
	}
}

class EntityRouterGen extends RouterGenBase {
	override function nullable(t:Type)
		return new EntityRouterGen().run(t);

	override function anon(fields:Array<FieldInfo<Type>>, ct:ComplexType):Type
		return generate('bp.directory.routing.EntityRouter', (name, types) -> {
			var ct = types[0].toComplex();
			var additionalFields = getEntityPropertyRoutes(fields, ct -> macro new bp.directory.routing.Router.EntityFieldRouter<$ct>(provider));
			var ret = macro class $name extends bp.directory.routing.Router.RouterBase {
			};
			ret.fields = additionalFields.concat(ret.fields);
			ret;
		});
}

class FieldRouterGenBase extends RouterGenBase {
	function prim():Type
		throw 'abstract';

	function getCollectionFieldRouter(name:String, ct:ComplexType)
		return macro class $name extends bp.directory.routing.Router.RouterBase {
			public function new(provider:bp.directory.Provider) {
				super(provider);
			}

			@:post('/')
			public function stream(query:bp.directory.routing.Router.StreamQuery):tink.io.Source.RealSource {
				provider.projection.replace(1);
				var cursor = this.provider.fetch(); // gets a cursor
				if (query != null && query._skip != null)
					cursor.skip(query._skip);
				if (query != null && query._limit != null)
					cursor.limit(query._limit);
				return tink.streams.Stream.Generator.stream(function next(step) {
					cursor.map(this.provider.selector) // map it by the selector set in the parent router
						.next() // cursor.next - returns Promise<Dynamic>
						.next(d -> (d : Null<$ct>)) // Promise.next, cast d, a Dynamic, to a Null<$ct>, where $ct is the type of this field
						.next(d -> {
							if (d == null) {
								// if d is null, the cursor is exhausted
								step(tink.streams.Stream.Step.End);
								null;
							} else
								d;
						})
						.next(d -> if (d != null) (tink.Json.stringify(d) : String) else null)
						.next(d -> if (d != null) tink.Chunk.ofString(d) else null)
						.next(d -> {
							if (d != null)
								step(tink.streams.Stream.Step.Link(d, tink.streams.Stream.Generator.stream(next)));
							tink.core.Noise;
						})
						.eager(); // promises in tink are lazy, always remember they must be handled,
					// here we don't need a a handler, so we just run it eagerly
				});
			}

			@:get('/')
			public function list(query:bp.directory.routing.Router.ListQuery):tink.io.Source.RealSource {
				provider.projection.replace(1);
				var cursor = this.provider.fetch(); // gets a cursor
				if (query != null && query._skip != null)
					cursor.skip(query._skip);
				if (query != null && query._limit != null)
					cursor.limit(query._limit);
				return tink.streams.Stream.Generator.stream(function next(step) {
					cursor.map(this.provider.selector) // map it by the selector set in the parent router
						.next() // cursor.next - returns Promise<Dynamic>
						.next(d -> (d : Null<$ct>)) // Promise.next, cast d, a Dynamic, to a Null<$ct>, where $ct is the type of this field
						.next(d -> {
							if (d == null) {
								// if d is null, the cursor is exhausted
								step(tink.streams.Stream.Step.End);
								null;
							} else
								d;
						})
						.next(d -> if (d != null) (tink.Json.stringify(d) : String) else null)
						.next(d -> if (d != null) tink.Chunk.ofString(d) else null)
						.next(d -> {
							if (d != null)
								step(tink.streams.Stream.Step.Link(d, tink.streams.Stream.Generator.stream(next)));
							tink.core.Noise;
						})
						.eager(); // promises in tink are lazy, always remember they must be handled,
					// here we don't need a a handler, so we just run it eagerly
				});
			}
		};

	function genPrim(name:String, ?query:Bool = false) {
		return generate(name, (name, types) -> getCollectionFieldRouter(name, types[0].toComplex()));
	}

	override function int() {
		return prim();
	}

	override function float() {
		return prim();
	}

	override function string()
		return prim();

	override function date()
		return prim();

	override function bytes()
		return prim();

	override function bool()
		return prim();

	function genArray(name:String, e:Type) {
		var eCt = e.toComplex();
		
		var ret = generate(name, (name, types) -> {
			var ret = getCollectionFieldRouter(name, eCt);
			ret.fields = ret.fields.concat((macro class {

				@:sub("/$index")
				public function get(index:Int) {
					provider.projection.rename(name -> name + '.' + Std.string(index));
					return new bp.directory.routing.Router.FieldRouter<$eCt>(provider);
				}
			}).fields);
			ret;
		});
		return ret;
	}

	function genMap(name:String, k:Type, v:Type, routerGen:ComplexType->Expr) {
		var kCt = k.toComplex();
		var vCt = v.toComplex();
		var ret = generate(name, (name, types) -> {
			macro class $name extends bp.directory.routing.Router.RouterBase {
				public function new(provider:bp.directory.Provider) {
					super(provider);
				}

				@:sub("/$key")
				public function get(key:$kCt) {
					provider.projection.push("value");
					while(provider.scope.length != 0)
						provider.query.push(provider.scope.shift());
					
					provider.query.push('key');
					provider.query.replace(Std.string(key));
					return ${routerGen(vCt)};
				}
			};
		});
		return ret;
	}
}

class FieldRouterGen extends FieldRouterGenBase {
	override function nullable(t:Type)
		return new FieldRouterGen().run(t);

	override function prim() {
		return genPrim("bp.directory.routing.FieldRouter", true);
	}

	override function array(t:haxe.macro.Type)
		return genArray("bp.directory.routing.FieldRouter", t);

	override function map(k:haxe.macro.Type, v:haxe.macro.Type)
		return genMap("bp.directory.routing.FieldRouter", k, v, vCt -> macro new bp.directory.routing.Router.FieldRouter<$vCt>(provider));

	override function dyn(e:Type, ct:ComplexType):Type
		return throw 'abstract';

	override function dynAccess(e:Type):Type
		return throw 'abstract';

	override function anon(fields:Array<FieldInfo<Type>>, ct:ComplexType):Type {
		return generate("bp.directory.routing.FieldRouter", (name, types) -> {
			var ret = getCollectionFieldRouter(name, types[0].toComplex());
			ret.fields = ret.fields.concat(getEntityPropertyRoutes(fields, ct -> macro new bp.directory.routing.Router.FieldRouter<$ct>(provider)));
			ret;
		});
	}
}

class EntityFieldRouterGen extends FieldRouterGenBase {
	override function nullable(t:Type)
		return new EntityFieldRouterGen().run(t);

	override function anon(fields:Array<FieldInfo<Type>>, ct:ComplexType):Type {
		return generate("bp.directory.routing.EntityFieldRouter", (name, types) -> {
			var ret = getCollectionFieldRouter(name, types[0].toComplex());

			ret.fields = ret.fields.concat(getEntityPropertyRoutes(fields, ct -> macro new bp.directory.routing.Router.EntityFieldRouter<$ct>(provider)));
			ret;
		});
	}

	override function array(t:haxe.macro.Type)
		return generate("bp.directory.routing.EntityFieldRouter", (name, types) -> {
			var ret = macro class $name extends bp.directory.routing.Router.RouterBase {};
			var eCt = t.toComplex();
			ret.fields = ret.fields.concat((macro class {
				@:get('/')
				public function slice(query:bp.directory.routing.Router.ListQuery) {
					provider.projection.push("$slice");
					var skip = if (query != null && query._skip != null) query._skip else 0;
					var limit = if (query != null && query._limit != null) query._limit else -1;
					provider.projection.replace([skip, limit]);
					var _signal = tink.core.Signal.trigger();
					var signal:tink.core.Signal<tink.streams.Stream.Yield<tink.Chunk, tink.core.Error>> = _signal;
					this.provider.fetch() // gets a cursor
						.map(this.provider.selector) // map it by the selector set in the parent router
						.next() // cursor.next - returns Promise<Dynamic>
						.next(d -> (d : Array<$eCt>)) // Promise.next, cast d, a Dynamic, to a Null<$ct>, where $ct is the type of this field
						.next(array -> {
							if (array != null)
								tink.core.Promise.inSequence(array.map(el -> new tink.core.Promise((resolve, reject) -> haxe.Timer.delay(() -> {
									var yield = if (el == null) tink.streams.Stream.Yield.End else
										tink.streams.Stream.Yield.Data(tink.Chunk.ofString(tink.Json.stringify(el)));
									signal.nextTime(_ -> {
										resolve(yield);
										true;
									}).eager();
									_signal.trigger(yield);
								}, 0)))).next(_ -> tink.core.Noise);
							else
								new tink.core.Promise((resolve, reject) -> resolve(tink.core.Noise));
						})
						.eager(); // promises in tink are lazy, always remember they must be handled,
					return (new tink.streams.Stream.SignalStream(signal) : tink.streams.Stream.Generator<tink.Chunk, tink.core.Error>);
				}

				@:sub("/$index")
				public function get(index:Int) {
					provider.projection.rename(name -> name + '.' + Std.string(index));
					return new bp.directory.routing.Router.EntityFieldRouter<$eCt>(provider);
				}
			}).fields);
			ret;
		});

	override function map(k:haxe.macro.Type, v:haxe.macro.Type)
		return genMap("bp.directory.routing.EntityFieldRouter", k, v, vCt -> macro new bp.directory.routing.Router.EntityFieldRouter<$vCt>(provider));

	override function prim() {
		return generate("bp.directory.routing.EntityFieldRouter", (name, types) -> {
			var ct = types[0].toComplex();
			macro class $name extends bp.directory.routing.Router.RouterBase {
				public function new(provider:bp.directory.Provider) {
					super(provider);
				}

				@:get('/')
				public function get():tink.core.Promise<String> {
					provider.projection.replace(1);
					return this.provider.fetch().map(this.provider.selector).next().next(d -> (d : Null<$ct>)).next(d -> tink.Json.stringify(d));
				}
			};
		});
	}

	override function enumAbstract(names:Array<Expr>, e:Type, ct:ComplexType, pos:Position):Type
		return e;

	override function dyn(e:Type, ct:ComplexType):Type {
		return generate("bp.directory.routing.EntityFieldRouter", (name, types) -> {
			var propRoute = "/$property".toExpr();
			var ret = macro class $name extends bp.directory.routing.Router.RouterBase {
				@:get($propRoute)
				public function getProperty(property:String) {
					trace(property);
					Noise;
				}
			};
			ret;
		});
	}
}
#end
