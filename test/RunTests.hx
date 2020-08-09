package;

import haxe.DynamicAccess;
import tink.unit.*;
import tink.testrunner.*;
import tink.CoreApi;
import bp.directory.routing.Router;
import bp.directory.Provider;
import tink.http.containers.*;
import tink.web.routing.Context;
import tink.web.proxy.Remote;
import tink.http.clients.*;
import tink.url.Host;
import bp.grpc.GrpcStreamWriter;
import tink.streams.*;
import bp.grpc.GrpcStreamParser;

using Lambda;
using bp.test.Utils;
using RunTests;
using tink.CoreApi;
using tink.io.Source;

import tink.testrunner.Reporter;

class RunTests {
	static function main() {
		ANSI.stripIfUnavailable = false;
		var reporter = new BasicReporter(new AnsiFormatter());
		Runner.run(TestBatch.make([new Test(),]), reporter).handle(Runner.exit);
	}
}

class Tools {
	public static function print(d:DynamicBuilder) {
		trace(haxe.Json.stringify(d.toDyn(), null, "  "));
	}

	public static function drill<T>(d:DynamicAccess<Dynamic>, string:String):Dynamic
		return string.split('/').fold((item : String, result : DynamicAccess<Dynamic>) -> {
			result = result[item];
		}, d);
}

typedef DeeplyNestedDoc = {
	waldo:String,
	plugh:Int
};

typedef User = {
	var username:String;
	var password:String;
	var address:String;
	var roles:Array<String>;
	var map:Map<Date, String>;
	var anon:{
		var foo:Bool;
		var bar:Int;
		var baz:Float;
		var qux:String;
		var quux:Date;
		var corge:Array<{
			var grault:haxe.io.Bytes;
			var garply:Map<Int, String>;
		}>;
		var nested:Map<String, Map<String, Map<String, Array<DeeplyNestedDoc>>>>;
	}
	var recursive:User;
	var dyn:Dynamic<Dynamic<Dynamic<Dynamic<Array<DeeplyNestedDoc>>>>>;
}

typedef WildDuckUser = {
	@:optional var _id:String;
	@:optional var username:String;
	@:optional var name:String;
	@:optional var password:String;
	@:optional var address:String;
	@:optional var storageUsed:Int;
	@:optional var created:Date;
}

class LoggingProvider {
	public function new() {}

	public var dataset = "";
	public var projection:DynamicBuilder = ({} : Dynamic);
	public var query:DynamicBuilder = ({} : Dynamic);
	public var scope:Array<String> = [];
	public var selector = v -> v;
	public var skipped = 0;
	public var limitted = 0;
	public var queryEngine = null;
	public var data:{
		scope:Array<String>,
		projection:Dynamic,
		query:Dynamic,
		dataset:String
	};

	public function makeId(v) return v;

	public function fetch():Cursor {
		this.data = ({
			scope: scope,
			projection: (projection : Dynamic),
			query: (query : Dynamic),
			dataset: dataset
		});
		function next()
			return Future.sync(Success(null));
		function hasNext()
			return false;
		function maxTimeMS(_)
			return null;
		function limit(v:Int) {
			this.limitted = v;
			return null;
		}
		function skip(v:Int) {
			this.skipped = v;
			return null;
		}
		function map(_)
			return this.fetch();
		return {
			next: next,
			maxTimeMS: maxTimeMS,
			limit: limit,
			skip: skip,
			map: map
		}
	}

	public function delete()
		return null;

	public function update(_)
		return null;

	public function create(_)
		return null;
}

class Logger {
	public static function log(s:Dynamic, ?pos:haxe.PosInfos)
		return {
			trace(s, pos);
			Noise;
		};

	public static function json(d:Dynamic)
		return haxe.Json.stringify(d, null, "   ");
}

@:asserts
class Test {
	public function new() {}

	var router:tink.web.routing.Router<DirectoryRouter<User>>;
	var remote:tink.web.proxy.Remote<DirectoryRouter<User>>;
	var provider:LoggingProvider;
	var header:tink.http.Request.IncomingRequestHeader;
	var dataset = "foo";

	function match(scope:Array<String>, callback:haxe.DynamicAccess<Dynamic>->haxe.DynamicAccess<Dynamic>->Any)
		return switch this.provider.data {
			case {
				scope: _.foreach(scope.has) => true,
				projection: p,
				query: q,
				dataset: _ == dataset => true
			}:
				callback(p, q);
				true;
			default: false;
		};

	public function create_router() {
		asserts.assert(({
			router = new tink.web.routing.Router<DirectoryRouter<User>>(new DirectoryRouter<User>(dataset, () -> this.provider = new LoggingProvider()));
			var container = new LocalContainer();
			container.run(req -> {
				var ret = router.route(Context.ofRequest(req)).recover(tink.http.Response.OutgoingResponse.reportError);
				header = req.header;
				ret;
			});
			var client = new LocalContainerClient(container);
			remote = new Remote<DirectoryRouter<User>>(client, new RemoteEndpoint(new Host('brave-pi.io', 80)));
			trace(router);
			Noise;
		}).attempt(true));
		asserts.done();
		return asserts;
	}

	var ts = Date.now();

	inline function printRequestAndPayload(r:tink.http.Response.IncomingResponse)
		return '${({requestHeader: '$header', providerResponse: this.provider.data.json(), responseHeader: '${r.header}'})}'; // .json();

	public function test_remote() {
		remote.roles()
			.list({
				_skip: 1,
				_limit: 3,
			})
			.next(r -> {
				remote.getSingle('test').roles().slice({
					_limit: 3,
				});
			})
			.next(r -> {
				asserts.assert(match(["roles"], (projection, query) -> {
					var roleProjection:DynamicAccess<Dynamic> = projection["roles"];
					var slice:Array<Int> = projection.drill("roles/$slice");
					var testA = false;
					asserts.assert(testA = slice.foreach([0, 3].has));
					var testB = false;
					asserts.assert(testB = query["_id"] == "test");
					return testA && testB;
				}), printRequestAndPayload(r));

				remote.getSingle('test').anon().bar().get();
			})
			.next(r -> {
				asserts.assert(match(["anon", "bar"], (projection, query) -> {
					var testA = false;
					asserts.assert(testA = projection.drill("anon/bar") == 1);
					var testB = false;
					asserts.assert(testB = query["_id"] == "test");
					return testA && testB;
				}), printRequestAndPayload(r));

				remote.getSingle('test').map().get(ts).get();
			})
			.next(r -> {
				asserts.assert(match(["map", "2"], (projection, query) -> {
					var testA = false;
					asserts.assert(testA = projection["map.2"] == 1);
					var testB = false;
					asserts.assert(testB = query["_id"] == "test");
					var testC = false;
					asserts.assert(testC = query["map.1"] == ts);
					return testA && testB && testC;
				}), printRequestAndPayload(r));

				remote.getSingle('test').anon().corge().get(314).grault().get();
			})
			.next(r -> {
				asserts.assert(match(["anon", "corge", "grault"],
					(projection, query) -> asserts.assert(projection.drill("anon/corge.314/grault") == 1 && query["_id"] == "test")),
					printRequestAndPayload(r));

				remote.anon().corge().get(314).list({
					_limit: 636,
				});
			})
			.next(r -> {
				asserts.assert(match(["anon", "corge", "314"], (projection, query) -> projection.drill("anon/corge.314") == 1), printRequestAndPayload(r));
				asserts.assert(provider.limitted == 636 && provider.skipped == 0);

				remote.anon().nested().get('path').get('to').get('result').get(15).waldo().list({});
			})
			.next(r -> {
				asserts.assert(match(["anon", "nested", "2", "2", "2", "15", "waldo"], (projection, query) -> {
					asserts.assert(projection.drill("anon/nested.2.2.2.15/waldo") == 1);
					asserts.assert(query.drill("anon.nested.2.2.1") == "result");
					asserts.assert(query.drill("anon.nested.2.1") == "to");
					asserts.assert(query.drill("anon.nested.1") == "path");
					true;
				}), printRequestAndPayload(r));
				remote.recursive()
					.recursive()
					.recursive()
					.recursive()
					.recursive()
					.anon()
					.foo()
					.list({});
			})
			.next(r -> {
				asserts.assert(r.header.statusCode == OK, printRequestAndPayload(r));
				remote.dyn().get("foo").get("bar").get("baz").get("qux").get(35).waldo().list({});
			})
			.next(r -> {
				asserts.assert(r.header.statusCode == OK, printRequestAndPayload(r));
				remote.map().keys().list({});
			})
			.next(r -> {
				asserts.assert(r.header.statusCode == OK, printRequestAndPayload(r));
				remote.map().values().list({});
			})
			.next(r -> {
				asserts.assert(r.header.statusCode == OK, printRequestAndPayload(r));
				asserts.done();
				Noise;
			})
			.eager();
		return asserts;
	}

	var wildduckRouter:tink.web.routing.Router<DirectoryRouter<WildDuckUser>>;
	var wildduckRemote:tink.web.proxy.Remote<DirectoryRouter<WildDuckUser>>;

	@:timeout(10000)
	public function test_mongo() {
		var promise:Promise<bp.Mongo.MongoClient> = bp.Mongo.connect(js.node.Fs.readFileSync('./secrets/cnxStr').toString());
		promise.next(client -> {
			wildduckRouter = new tink.web.routing.Router<DirectoryRouter<WildDuckUser>>(new DirectoryRouter<WildDuckUser>("users",
				() -> new bp.directory.providers.MongoProvider(client)));
			var container = new LocalContainer();
			container.run(req -> {
				trace(req);
				var ret = wildduckRouter.route(Context.ofRequest(req)).recover(e -> {
					var ret = tink.http.Response.OutgoingResponse.reportError(e);
					trace('ERR: $e');
					ret;
				});
				header = req.header;
				ret.next(ret -> {
					Noise;
				}).eager();
				ret;
			});
			var client = new LocalContainerClient(container);
			wildduckRemote = new Remote<DirectoryRouter<WildDuckUser>>(client, new RemoteEndpoint(new Host('brave-pi.io', 80)));
		})
			.next(_ -> {
				trace("Remote setup");
				wildduckRemote.username().list({
					_limit: 10
				});
			})
			.next(r -> {
				r.body.all()
					.next(body -> {
						trace('got $body');
						body;
					})
					.next(d -> (tink.Json.parse(d) : Array<String>))
					.next(results -> {
						asserts.assert(results != null);
						asserts.assert(results.length == 10);
					})
					.recover(e -> {
						asserts.assert(e == null);
					})
					.next(_ -> {
						var writer:GrpcWriter<Bool> = new GrpcStreamWriter<Bool>();
						wildduckRemote.username().stream({
							_limit: 10
						}, writer).next((res:tink.http.Response.IncomingResponse) -> {
							new tink.core.Pair(res, cast writer);
						});
					});
			})
			.next(pair -> {
				var res = pair.a;
				var writer = pair.b;
				var reader:GrpcReader<String> = new bp.grpc.GrpcStreamParser<String>(res.body);
				var readStream:RealStream<String> = reader;
				var counter = 0;
				var usernames = [];
				writer.write(true);
				readStream.forEach(username -> {
					usernames.push(username);
					if (++counter > 9) {
						asserts.assert(usernames.length == 10);
						tink.streams.Stream.Handled.Finish;
					} else {
						asserts.assert(usernames.length == counter);
						trace('Waiting 50 ms...');
						Future.delay(50, () -> {
							trace('...writing');
							writer.write(true);
						});
						tink.streams.Stream.Handled.Resume;
					}
				}).next(_ -> {
					asserts.assert(usernames.length == 10, 'Should have 10 usernames: $usernames');
					var writer:GrpcWriter<Bool> = new GrpcStreamWriter<Bool>();
					wildduckRemote.stream({
						_limit: 10,
						_where: "name != null", // hquery expression
						_select: {
							username: 1,
							name: 1
						}
					}, writer).next((res:tink.http.Response.IncomingResponse) -> {
						new tink.core.Pair(res, cast writer);
					});
				});
			})
			.next(pair -> {
				var res = pair.a;
				var writer = pair.b;
				var _reader:GrpcReader<{name:String}> = new bp.grpc.GrpcStreamParser<{name:String}>(res.body);
				var reader:RealStream<{name:String}> = _reader;
				writer.write(true);
				reader.forEach(incoming -> {
					if (incoming == null) {
						tink.streams.Stream.Handled.Finish;
					} else {
						asserts.assert(incoming.name != null, '${Std.string(incoming)} has a name');
						writer.write(true);
						tink.streams.Stream.Handled.Resume;
					}
				});
			})
			.next(_ -> {
				wildduckRemote.create(tink.Json.stringify([
					{
						username: 'ReallyUniqueName',
						password: 'quxquuxcorge'
					}
				]));
			})
			.next(r -> {
				asserts.assert(r == Noise, "Should have been successfully created");
				wildduckRemote.list({
					_where: "username = 'ReallyUniqueName'",
					_select: {username: 1}
				});
			})
			.next(r -> {
				r.body.all().next((d) -> (tink.Json.parse(d) : Array<{_id:String, username:String}>)).next(d -> {
					asserts.assert(d.length == 1);
					asserts.assert(d[0].username == 'ReallyUniqueName');
					asserts.assert(d[0]._id != null);
					wildduckRemote.getSingle(d[0]._id).delete({}).next(r -> new Pair(r, d[0]));
				});
			})
			.next(pair -> {
				asserts.assert(pair.a == Noise);
				wildduckRemote.getSingle(pair.b._id).get();
			})
			.next(r -> {
				r.body.all().next(r -> {
					asserts.assert(r == "null");
					asserts.done();
				});
			})
			.recover(e -> {
				asserts.assert(e == null);
				asserts.done();
			})
			.eager();
		return asserts;
	}
}
