package bp.directory;

import tink.core.Promise;
import haxe.DynamicAccess;

typedef Provider = {
	var dataset:String;
	var projection:DynamicBuilder;
	var query:DynamicBuilder;
	var scope:Array<String>; // used to track the scope of custom projections/queries
    var selector:Dynamic->Dynamic;
    var queryEngine:bp.directory.query.Engine;
	function fetch():Cursor;
	function delete():Promise<DeleteResult>;
	function update(patch:Dynamic):Promise<Dynamic>;
	function create(patch:Dynamic):Promise<Dynamic>;
}

typedef Cursor = {
	function next():Promise<Dynamic>;
	function maxTimeMS(ms:Float):Cursor;
	function limit(count:Int):Cursor;
	function skip(count:Int):Cursor;
	function map(selector:Any->Any):Cursor;
}

typedef DeleteResult = {
	deletedCount:Int
}