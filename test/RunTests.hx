package;

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

class RunTests {
	static function main() {
		Runner.run(TestBatch.make([new Test(),])).handle(Runner.exit);
	}
}

class Tools {
	public static function print(d:DynamicBuilder) {
		trace(haxe.Json.stringify(d.toDyn(), null, "  "));
	}
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
	}
}

class DummyProvider {
	public function new() {}

	public var dataset = "";
	public var projection:DynamicBuilder = ({} : Dynamic);
	public var query:DynamicBuilder = ({} : Dynamic);
	public var scope = [];
	public var selector = v -> v;

	public function fetch():Cursor {
		trace(haxe.Json.stringify({
			scope: scope,
			projection: (projection : Dynamic),
			query: (query : Dynamic),
			dataset: dataset
		}));
		function next()
			return Future.sync(Success(null));
		function hasNext()
			return false;
		function maxTimeMS(_)
			return null;
		function limit(_)
			return null;
		function skip(_)
			return null;
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

@:asserts
class Test {
	public function new() {}

	var router:tink.web.routing.Router<DirectoryRouter<User>>;
	var remote:tink.web.proxy.Remote<DirectoryRouter<User>>;

	public function create_router() {
		asserts.assert(({
			router = new tink.web.routing.Router<DirectoryRouter<User>>(new DirectoryRouter<User>("foo", () -> new DummyProvider()));
			var container = new LocalContainer();
			container.run(req -> router.route(Context.ofRequest(req)).recover(tink.http.Response.OutgoingResponse.reportError));
			var client = new LocalContainerClient(container);
			remote = new Remote<DirectoryRouter<User>>(client, new RemoteEndpoint(new Host('brave-pi.io', 80)));
			trace(router);
			Noise;
		}).attempt(true));
		asserts.done();
		return asserts;
	}

	public function test_remote() {
		remote.roles().list({
			_skip: 1,
			_limit: 3,
			_list: true
		}).next(r -> {
			trace(r.body);
			remote.getSingle('test').roles().slice({
				_limit: 3,
				_list: true
			});
		}).next(r -> {
			trace(r.body);
			remote.getSingle('test').anon().bar().get();
		}).next(r -> {
			trace(r);
			asserts.done();
		}).eager();
		return asserts;
	}
}
