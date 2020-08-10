- [BP Directory](#bp-directory)
  * [How it Works](#how-it-works)
  * [Provider](#provider)
  * [Querying and Projection](#querying-and-projection)
  * [Field Routes](#field-routes)
  * [Entity Routes](#entity-routes)


# Haxe project

This is an example Haxe project scaffolded by Visual Studio Code.

Without further changes the structure is following:

 * `src/RunTests.hx`: Entry point Haxe source file
 * `build.hxml`: Haxe command line file used to build the project
 * `README.md`: This file

# BP Directory

A macro-based data access layer as a REST API, with some gRPC inspired streams.

## How it Works

BP Directory works by building router classes from anonymous structures which can then be consumed by [`tink_web`](https://github.com/haxetink/tink_web) to generate REST APIs.

Take this typedef of an anonymous structure:
```haxe
typedef User = {
    var _id:String;
    var username:String;
    var password:String;
    var address:String;
}
```

You can create an entire REST API for it with just:
```haxe
import bp.directory.Router;
import tink.http.containers.*;
import tink.http.Response;
import tink.web.routing.*;

var container = /* get some tink.http.container */
var dataset = "wildduck.users";
var directory = new DirectoryRouter<User>(dataset, providerFactory); // dataset should point to where the data resides in your database, and the providerFactory should be a factory function for creating a provider.
var router = new tink.web.routing.Router<DirectoryRouter<User>>(directory);
container.run(req -> router.route(Context.ofRequest(req)).recover(OutgoingResponse.reportError));
```

This would expose:
- `GET /` - Paginated listing of results
- `GET /@stream` -  **EXPERIMENTAL** get a (textual; length+newline delimitted) "gRPC" stream of results


The above two paths include parameters optional parameters `_limit` and `_skip`.


- `PATCH /` - Update users
- `DELETE /` - Delete users


The above 4 paths (including the GETs) include optional parameters `_where` and `_select`

- `GET /$id` - Get an entity by ID.
- `POST /` - Create a User

## Provider

The Provider factory above refers to this type (which is a little too `Dynamic` at the moment):
```haxe

typedef Provider = {
    var dataset:String;
    var projection:DynamicBuilder;
    var query:DynamicBuilder;
    var scope:Array<String>; // used to track the scope of custom queries
    var selector:Dynamic->Dynamic;
    var queryEngine:bp.directory.query.Engine;
    function fetch():Cursor;
    function delete():Promise<Dynamic>;
    function update(patch:Dynamic):Promise<Dynamic>;
    function create(n:Array<Dynamic>):Promise<Dynamic>;
    function makeId(id:String):Dynamic;
}
```
You may notice it includes a `queryEngine`.

The `queryEngine` can be null, in this case, querying is disabled.

There is an existing provider ([`bp.directory.providers.MongoProvider`](https://github.com/Brave-Pi/bp_directory/blob/master/src/bp/directory/providers/MongoProvider.hx)) for MongoDB using [`hscript`](https://github.com/haxefoundation/hscript) to parse and transform the queries (via [`hquery`](https://github.com/brave-pi/hquery), which only handles a subset of the hscript AST)

## Querying and Projection

The `_where` and `_select` parameters enable querying and projection.
- `_where` - Accepts an arbitrary string, passed to the `provider.queryEngine` (if it is not null)
- `_select` - Specify whether or not a field is present in the result with 0 or 1; if you specify 0 for a field, it excludes this field and displays all others. If you specify 1 for a field, it will include this field and exclude all others except for the `_id` field (unless it is explicitly excluded)

An example selection:
- `GET /?_select[username]=1&_select[address]=1` - Will return only the username and address for records.
- `GET /?_select[_id]=0` - Will return all fields except for `_id`
- `GET /_select[username]=1&_where=address.substring(-9) == gmail.com` - Would return the `username` and `_id` for users with e-mail addresses ending in "gmail.com"

## Field Routes
GET routes identical to the ones above would would also be exposed for each property. e.g.:
- `GET /username?_limit=10` - Would get a list of the top 10 usernames
- `GET /password?_where=username = 'bob'` - Assuming you URI encode the query string here,  this would get a list of the passwords for all users with the username "bob".  (in hquery, both `==` and `=` have the same meaning)

## Entity Routes
Similarly, when accessing a specific entity, each field is exposed as a route:
- `GET /some-id/username` - Gets the username of the user with id "some-id"

And, you can read, update or delete single entities:
- `GET /some-id` - Get the user with id "some-id"
- `PATCH /some-id` - Updates the user with id "some-id"
- `DELETE /some-id` - Deletes the user with id "some-id"


## Client Generation

Because the library utilizes `tink_web` it is possible to generate a `tink.web.proxy.Remote` from the same `DirectoryRouter` you created the REST API with in order to instantiate a strongly typed API client that exposes methods to access the REST API.

You can see an example of this [here](https://github.com/Brave-Pi/bp_directory_example/blob/371727e516b8ffdcf3aada396b65f2d4c9f6c536/src/FrontEndServer3.hx#L25).
