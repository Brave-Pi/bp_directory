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
	function patchType(ct:ComplexType):ComplexType {
		switch ct.toType().sure() {
			case TType(_.get() => defType, _):
				switch defType.type {
					case TAnonymous(ref):
						var anon = ref.get();
						anon.fields = anon.fields.map(field -> {
							if (!field.meta.has(':optional'))
								field.meta.add(':optional', [], field.pos);
							field;
						});

						var newType = haxe.macro.Type.TAnonymous({
							get: () -> anon,
							toString: ref.toString
						});
						
						
						return newType.toComplex();
					default:
				}
			default:
		}
		return (macro(null : Null<$ct>)).typeof().sure().toComplex();
	}

	
	function getRouterBase(name:String, ct:ComplexType, ?useFactory = false, ?readOnly = true, ?single = false)
		return {
			var pCt = patchType(ct);
			var ret = macro class $name extends bp.directory.routing.Router.RouterBase {
				function processQuery(query:bp.directory.routing.Router.SearchParams) {
					${
						if (useFactory)
							macro var provider = providerFactory()
						else
							macro null
					};
					if (query == null)
						query = {};

					if (query._select == null)
						provider.projection.replace(1);
					else
						provider.projection.replace(query._select);
					if (query._where != null && provider.queryEngine != null) {
						provider.query.target["$expr"] = provider.queryEngine.parse(query._where);
						inline function objectIdToString(head:haxe.DynamicAccess<Dynamic>) {
							if (head["$eq"] != null) {
								if (head["$eq"][0] == "$_id") {
									var dynAcc:haxe.DynamicAccess<Dynamic> = {};
									dynAcc["$toString"] = "$_id";
									head["$eq"][0] = dynAcc;
								}
							}
						}

						objectIdToString(provider.query.target["$expr"]);
					}
					if (provider.query.head['_id'] != null)
						provider.query.head['_id'] = provider.makeId(provider.query.head['_id']);
					return provider;
				}
			};
			if (!single) {
				ret.fields = ret.fields.concat((macro class {
					#if bp_grpc
					@:post("/@stream")
					public function stream(?query:bp.directory.routing.Router.ReadParams, body:tink.io.Source.RealSource):tink.io.Source.RealSource {
						var provider = processQuery(query);
						var cursor = provider.fetch().map(provider.selector); // get a cursor and  map it by the selector set in the parent router
						if (query != null && query._skip != null)
							cursor.skip(query._skip);
						if (query != null && query._limit != null)
							cursor.limit(query._limit);
						var reader = new bp.grpc.GrpcStreamParser<Bool>(body).toStream();
						var writer:bp.grpc.GrpcStreamWriter.GrpcWriter<$ct> = new bp.grpc.GrpcStreamWriter<$ct>();
						reader.forEach(req -> {
							if (req) {
								cursor.next().next(d -> {
									if (d != null)
										writer.write(d);
									else
										writer.end();
									d;
								}).map(d -> if (d != null) tink.streams.Stream.Handled.Resume else tink.streams.Stream.Handled.Finish);
							} else {
								writer.end();
								tink.streams.Stream.Handled.Finish;
							}
						}).handle(_ -> {
							writer.end();
						});
						return writer;
					}
					#end

					@:get("/")
					public function list(?query:bp.directory.routing.Router.ReadParams):tink.io.Source.RealSource {
						var provider = processQuery(query);
						var cursor = provider.fetch().map(provider.selector); // get a cursor and  map it by the selector set in the parent router
						if (query != null && query._skip != null)
							cursor.skip(query._skip);
						if (query != null && query._limit != null)
							cursor.limit(query._limit);
						var open = false;
						var first = true;
						var depleted = false;
						return tink.streams.Stream.Generator.stream(function next(step) {
							if (depleted)
								step(tink.streams.Stream.Step.End);
							else if (!open) {
								open = true;
								step(tink.streams.Stream.Step.Link(tink.Chunk.ofString("["), tink.streams.Stream.Generator.stream(next)));
							} else
								cursor.next() // cursor.next - returns Promise<Dynamic>
									.next(d -> (d : Null<$ct>)) // Promise.next, cast d, a Dynamic, to a Null<$ct>, where $ct is the type of this field
									.next(d -> {
										if (d == null) {
											// if d is null, the cursor is exhausted
											depleted = true;
											step(tink.streams.Stream.Step.Link(tink.Chunk.ofString("]"), tink.streams.Stream.Generator.stream(next)));
											null;
										} else
											d;
									})
									.next(d -> if (d != null) (tink.Json.stringify(d) : String) else null)
									.next(d -> if (d != null && !first) "," + d else {
										first = false;
										d;
									})
									.next(d -> if (d != null) tink.Chunk.ofString(d) else null)
									.next(d -> {
										if (d != null) {
											step(tink.streams.Stream.Step.Link(d, tink.streams.Stream.Generator.stream(next)));
										}
										tink.core.Noise;
									})
									.eager(); // promises in tink are lazy, always remember they must be handled,
							// here we don't need a a handler, so we just run it eagerly
						});
					}
				}).fields);
			}
			if (!readOnly) {
				var aCt = (macro(null : Array<$ct>)).typeof().sure().toComplex();
				ret.fields = (macro class {
					@:patch('/')
					
					
					public function patch(?query:bp.directory.routing.Router.SearchParams, body:String):tink.core.Promise<tink.core.Noise> {
						var provider = processQuery(query);
						return provider.update(haxe.Json.parse(body));
					}

					@:delete('/')
					public function delete(?query:bp.directory.routing.Router.SearchParams):tink.core.Promise<haxe.DynamicAccess<Dynamic>> {
						var provider = processQuery(query);

						return provider.delete();
					}

					@:post('/')
					public function create(body:tink.io.Source.RealSource):tink.core.Promise<haxe.DynamicAccess<Dynamic>> {
						${
							if (useFactory)
								macro var provider = providerFactory()
							else
								macro null
						};
						return tink.io.Source.RealSourceTools.all(body)
							.next(c -> c.toString())
							.next(d -> tink.Json.parse((d : Array<$ct>)))
							.next(provider.create);
					}
				}).fields.concat(ret.fields);
			}
			ret;
		}

	function getEntityPropertyRoutes(fields:Array<FieldInfo<Type>>, routerGen:ComplexType->Expr, ?useFactory = false)
		return [
			for (field in fields) {
				var name = field.name;
				var path = '/$name'.toExpr();
				var fCt = field.type.toComplex();
				var ret = (macro class {
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
						var selectorPrevious = provider.selector;
						provider.selector = v -> selectorPrevious(v).$name;
						return ${routerGen(fCt)};
					}
				}).fields;
				ret;
			}
		].fold((current, result : Array<Field>) -> {
			return result.concat(current);
		}, []);
}

class DirectoryRouterGen extends RouterGenBase {
	override function anon(fields:Array<FieldInfo<Type>>, ct:ComplexType):Type {
		return generate('bp.directory.routing.DirectoryRouter', (name, types) -> {
			var ct = types[0].toComplex();
			var additionalFields = getEntityPropertyRoutes(fields, ct -> {
				macro new bp.directory.routing.Router.FieldRouter<$ct>(provider);
			}, true).concat(getRouterBase(name, types[0].toComplex(), true, false).fields);

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
					provider.query.head["_id"] = provider.makeId(id);
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
		return t;

	override function anon(fields:Array<FieldInfo<Type>>, ct:ComplexType):Type
		return generate('bp.directory.routing.EntityRouter', (name, types) -> {
			var ct = types[0].toComplex();
			var additionalFields = getRouterBase(name, ct, false, false,
				true).fields.concat(getEntityPropertyRoutes(fields, ct -> macro new bp.directory.routing.Router.EntityFieldRouter<$ct>(provider), false));
			var ret = macro class $name extends bp.directory.routing.Router.RouterBase {
				@:get('/')
				public function get():tink.core.Promise<String> {
					return this.provider.fetch()
						.map(this.provider.selector)
						.next()
						.next(d -> (d : Null<$ct>))
						.next(d -> tink.Json.stringify(d));
					// .next(d -> ((d:String) :tink.io.Source.RealSource));
				}
			};
			ret.fields = ret.fields.concat(additionalFields);
			ret;
		});
}

class FieldRouterGenBase extends RouterGenBase {
	function prim():Type
		throw 'abstract';

	function genPrim(name:String, ?query:Bool = false) {
		return generate(name, (name, types) -> getRouterBase(name, types[0].toComplex()));
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

	function genArray(name:String, e:Type, ?isCollection = false) {
		var eCt = e.toComplex();

		var ret = generate(name, (name, types) -> {
			var additionalFields = if (isCollection) getRouterBase(name, eCt).fields else [];
			var ret = macro class $name extends bp.directory.routing.Router.RouterBase {
				@:sub("/$index")
				public function get(index:Int) {
					provider.projection.rename(name -> {
						var newName = name + '.' + Std.string(index);
						newName;
					});
					provider.scope.push(Std.string(index));
					return new bp.directory.routing.Router.FieldRouter<$eCt>(provider);
				}
			};
			ret.fields = additionalFields.concat(ret.fields);
			ret;
		});
		return ret;
	}

	function genMap(name:String, k:Type, v:Type, routerGen:ComplexType->Expr, ?isCollection = false) {
		var kCt = k.toComplex();
		var vCt = v.toComplex();
		var ret = generate(name, (name, types) -> {
			var additionalFields = if (isCollection) getRouterBase(name, (macro(null : Map<$kCt, $vCt>)).typeof().sure().toComplex()).fields else [];
			var ret = macro class $name extends bp.directory.routing.Router.RouterBase {
				public function new(provider:bp.directory.Provider) {
					super(provider);
				}

				@:sub("/@keys")
				public function keys() {
					provider.projection.rename(name -> name + '.1');
					return ${routerGen(kCt)};
				}

				@:sub("/@values")
				public function values() {
					provider.projection.rename(name -> name + '.2');
					return ${routerGen(vCt)};
				}

				@:sub("/$key")
				public function get(key:$kCt) {
					provider.projection.rename(name -> name + '.2');
					provider.query.push(provider.scope.concat(['1']).join('.'));
					provider.scope.push('2');
					provider.query.replace(Std.string(key));
					return ${routerGen(vCt)};
				}
			};
			ret.fields = additionalFields.concat(ret.fields);
			ret;
		});
		return ret;
	}

	function genDyn(name:String, t:Type, routerGen:ComplexType->Expr, ?isCollection = false) {
		var ct = t.toComplex();
		var ret = generate(name, (name, types) -> {
			var additionalFields = if (isCollection) getRouterBase(name, ct).fields else [];
			var ret = macro class $name extends bp.directory.routing.Router.RouterBase {
				public function new(provider:bp.directory.Provider) {
					super(provider);
				}

				@:sub("/$property")
				public function get(property:String) {
					provider.projection.push(property);
					provider.scope.push(property);
					var selectorPrevious = provider.selector;
					provider.selector = v -> (selectorPrevious(v) : haxe.DynamicAccess<Dynamic>)[property];
					return ${routerGen(ct)};
				}
			};
			ret.fields = additionalFields.concat(ret.fields);
			ret;
		});
		return ret;
	}
}

class FieldRouterGen extends FieldRouterGenBase {
	override function nullable(t:Type)
		return t;

	override function enumAbstract(names:Array<Expr>, e:Type, ct:ComplexType, pos:Position):Type
		return e;

	override function prim() {
		return genPrim("bp.directory.routing.FieldRouter", true);
	}

	override function array(t:haxe.macro.Type)
		return genArray("bp.directory.routing.FieldRouter", t, true);

	override function map(k:haxe.macro.Type, v:haxe.macro.Type)
		return genMap("bp.directory.routing.FieldRouter", k, v, vCt -> macro new bp.directory.routing.Router.FieldRouter<$vCt>(provider), true);

	override function dyn(e:Type, ct:ComplexType):Type
		return genDyn("bp.directory.routing.FieldRouter", e, ct -> macro new bp.directory.routing.Router.FieldRouter<$ct>(provider), true);

	override function dynAccess(e:Type):Type
		return return genDyn("bp.directory.routing.FieldRouter", e, ct -> macro new bp.directory.routing.Router.FieldRouter<$ct>(provider));

	override function anon(fields:Array<FieldInfo<Type>>, ct:ComplexType):Type {
		return generate("bp.directory.routing.FieldRouter", (name, types) -> {
			var ret = getRouterBase(name, types[0].toComplex());

			ret.fields = ret.fields.concat(getEntityPropertyRoutes(fields, (ct:ComplexType) -> {
				var ret = switch ct.toType().sure() {
					case TAnonymous(_): macro new bp.directory.routing.Router.DirectoryRouter<$ct>(provider.dataset, () -> provider);
					default: macro new bp.directory.routing.Router.FieldRouter<$ct>(provider);
				}
				ret;
			}));
			ret;
		});
	}
}

class EntityFieldRouterGen extends FieldRouterGenBase {
	override function nullable(t:Type)
		return t;

	override function anon(fields:Array<FieldInfo<Type>>, ct:ComplexType):Type {
		return generate("bp.directory.routing.EntityFieldRouter", (name, types) -> {
			var ret = getRouterBase(name, types[0].toComplex());

			ret.fields = ret.fields.concat(getEntityPropertyRoutes(fields, ct -> {
				var ret = switch ct.toType().sure() {
					case TAnonymous(_): macro new bp.directory.routing.Router.EntityRouter<$ct>(provider);
					default: macro new bp.directory.routing.Router.EntityFieldRouter<$ct>(provider);
				}
				ret;
			}));
			ret;
		});
	}

	override function array(t:haxe.macro.Type)
		return generate("bp.directory.routing.EntityFieldRouter", (name, types) -> {
			var ret = macro class $name extends bp.directory.routing.Router.RouterBase {};
			var eCt = t.toComplex();
			ret.fields = ret.fields.concat((macro class {
				@:get('/@slice')
				public function slice(?query:bp.directory.routing.Router.ReadParams) {
					if (query == null)
						query = {};
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
					return this.provider.fetch()
						.map(this.provider.selector)
						.next()
						.next(d -> (d : Null<$ct>))
						.next(d -> tink.Json.stringify(d));
					// .next(d -> ((d:String) :tink.io.Source.RealSource));
				}
			};
		});
	}

	override function enumAbstract(names:Array<Expr>, e:Type, ct:ComplexType, pos:Position):Type
		return e;

	override function dyn(e:Type, ct:ComplexType):Type
		return genDyn("bp.directory.routing.EntityFieldRouter", e, ct -> macro new bp.directory.routing.Router.EntityFieldRouter<$ct>(provider));

	override function dynAccess(e:Type):Type
		return return genDyn("bp.directory.routing.EntityFieldRouter", e, ct -> macro new bp.directory.routing.Router.EntityFieldRouter<$ct>(provider));
}
#end
