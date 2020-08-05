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
			var garply:Map<Float, String>;
		}>;
		var nested:Map<String, Map<String, Map<String, Array<{waldo:String, plugh:Int}>>>>;
	}
	var recursive:User;
	var dyn:Dynamic<Dynamic<Dynamic<Dynamic<Array<{waldo:String, plugh:Int}>>>>>;
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
	public var data:{
		scope:Array<String>,
		projection:Dynamic,
		query:Dynamic,
		dataset:String
	};

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
			hasNext: hasNext,
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

	function match(scope:Array<String>, callback:haxe.DynamicAccess<Dynamic>->haxe.DynamicAccess<Dynamic>->Bool)
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

	public function test_remote() {
		inline function printRequestAndPayload(r:tink.http.Response.IncomingResponse)
			return '${({requestHeader: '$header', providerResponse: this.provider.data.json(), responseHeader: '${r.header}'})}'; // .json();
		remote.roles()
			.list({
				_skip: 1,
				_limit: 3,
				_list: true
			})
			.next(r -> {
				remote.getSingle('test').roles().slice({
					_limit: 3,
					_list: true
				});
			})
			.next(r -> {
				asserts.assert(match(["roles"], (projection, query) -> {
					var roleProjection:DynamicAccess<Dynamic> = projection["roles"];
					var slice:Array<Int> = projection.drill("roles/$slice");
					var testA = false;
					asserts.assert(testA = slice.foreach([0, 3].has));
					var testB = false;
					trace('TEST A: $testA, TEST B: $testB');
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
				asserts.assert(match(["value"], (projection, query) -> {
					var testA = false;
					asserts.assert(testA = projection.drill("map/value") == 1);
					var testB = false;
					asserts.assert(testB = query["_id"] == "test");
					var testC = false;
					asserts.assert(testC = query.drill("map/key") == ts);
					return testA && testB && testC;
				}), printRequestAndPayload(r));

				remote.getSingle('test').anon().corge().get(314).grault().get();
			})
			.next(r -> {
				asserts.assert(match(["anon", "corge", "grault"],
					(projection, query) -> projection.drill("anon/corge.314/grault") == 1 && query["_id"] == "test"),
					printRequestAndPayload(r));

				remote.anon().corge().get(314).list({
					_limit: 636,
					_list: true
				});
			})
			.next(r -> {
				asserts.assert(match(["anon", "corge"], (projection, query) -> projection.drill("anon/corge.314") == 1), printRequestAndPayload(r));
				asserts.assert(provider.limitted == 636 && provider.skipped == 0);

				remote.anon().nested().get('path').get('to').get('result').get(15).waldo().list({
					_list: true
				});
			})
			.next(r -> {
				asserts.assert(match(["value", "waldo"], (projection, query) -> {
					asserts.assert(projection.drill("anon/nested/value/value/value.15/waldo") == 1);
					asserts.assert(query.drill("anon/nested/value/value/key") == "result");
					asserts.assert(query.drill("anon/nested/value/key") == "to");
					asserts.assert(query.drill("anon/nested/key") == "path");
					true;
				}), printRequestAndPayload(r));
				remote.recursive()
					.recursive()
					.recursive()
					.recursive()
					.recursive()
					.anon()
					.foo()
					.list({
						_list: true,
					});
			})
			.next(r -> {
				asserts.assert(true, printRequestAndPayload(r));
				remote.dyn().get("foo").get("bar").get("baz").get("qux").get(35).waldo().list({
					_list:true
				});
			})
			.next(r -> {
				asserts.assert(true, printRequestAndPayload(r));
				remote.map().keys().list({
					_list:true
				});
			})
			.next(r -> {
				asserts.assert(true, printRequestAndPayload(r));
				asserts.done();
				Noise;
			})
			.eager();
		return asserts;
	}
}
