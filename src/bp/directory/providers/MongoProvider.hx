package bp.directory.providers;

import bp.Mongo;

class MongoProvider extends ProviderBase {
	public function new(client) {
		this.client = client;
	}

	function setup()
		return {
			var collection = client.db().collection(this.dataset);
			var projection:Dynamic = this.projection;
			var query:Dynamic = this.query;
			{
				collection: collection,
				projection: projection,
				query: query
			};
		}

	var client:MongoClient;

	override function fetch():bp.directory.Provider.Cursor {
		var setup = setup();
		return new WrappedMongoCursor(setup.collection.find(query, {projection: projection}));
	}
}

class WrappedMongoCursor {
	var cursor:bp.Mongo.Cursor<Dynamic>;

	public function new(cursor) {
		this.cursor = cursor;
	}

	public function next() {
		var next:Promise<Dynamic> = this.cursor.next();
		return next.next(d -> Success(d));
	}

	public function maxTimeMS(ms:Float) {
		this.cursor = this.cursor.maxTimeMS(ms);
		return this;
	}

	public function limit(c) {
		this.cursor = this.cursor.limit(c);
		return this;
	}

	public function skip(c) {
		this.cursor = this.cursor.skip(c);
		return this;
	}

	public function map(selector) {
		this.cursor = this.cursor.map(selector);
		return this;
	}
}
