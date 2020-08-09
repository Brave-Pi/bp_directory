package bp.directory.providers;

import bp.Mongo;

class MongoProvider extends ProviderBase {
	public function new(client) {
		this.client = client;
		this.queryEngine = new bp.hquery.Engine();
	}

	var collection(get, never):bp.Mongo.Collection<Dynamic>;

	function get_collection()
		return client.db().collection(this.dataset);

    var client:MongoClient;
    
    override function makeId(id:String) {


        return new bp.mongo.bson.Bson.ObjectId(id);

    }

	override function fetch():bp.directory.Provider.Cursor {
		return new WrappedMongoCursor(collection.find(query, {projection: projection}));
	}

	override function delete():Promise<Dynamic> {
		return collection.deleteMany(query);
	}

	override function update(patch:Dynamic):Promise<Dynamic> {
		return collection.updateMany(query, patch);
	}

	override function create(n:Array<Dynamic>):Promise<Dynamic> {
		return collection.insertMany(n);
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
