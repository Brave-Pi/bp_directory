package bp.directory.routing;

@:genericBuild(bp.directory.macros.RouterBuilder.DirectoryRouterBuilder.apply())
class DirectoryRouter<T> {
	public function new() {}
}

@:genericBuild(bp.directory.macros.RouterBuilder.EntityRouterBuilder.apply())
class EntityRouter<T> {
	public function new() {}
}

@:genericBuild(bp.directory.macros.RouterBuilder.FieldRouterBuilder.apply())
class FieldRouter<T> {
	public function new() {}
}

@:genericBuild(bp.directory.macros.RouterBuilder.EntityFieldRouterBuilder.apply())
class EntityFieldRouter<T> {
	public function new() {}
}

class RouterBase {
	var provider:bp.directory.Provider;

	public function new(provider) {
		this.provider = provider;
	}
}

typedef ReadParams = {
	@:optional var _select:DynamicAccess<Int>;
	@:optional var _where:String;
	@:optional
	var _skip:Int;
	@:optional
	var _limit:Int;
}

typedef StreamQuery = ReadParams;
typedef ListQuery = ReadParams;
