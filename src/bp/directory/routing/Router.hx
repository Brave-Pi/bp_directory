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

typedef GetQueryBase = {
    // @:json var _select:Dynamic;
    // @:json var _where:Dynamic;
    @:optional
    var _skip:Int;
    @:optional
    var _limit:Int;
}

typedef StreamQuery = {
    >GetQueryBase,
    @:optional
    var _stream:Bool;
}

typedef ListQuery = {
    >GetQueryBase,
    @:optional
    var _list:Bool;
}
