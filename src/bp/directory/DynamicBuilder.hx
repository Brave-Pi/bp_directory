package bp.directory;

typedef DynamicBuilderObject = {
	head:DynamicAccess<Dynamic>,
	trail:Array<{key:String, value:DynamicAccess<Dynamic>}>,
	target:DynamicAccess<Dynamic>
}

@:forward
abstract DynamicBuilder(DynamicBuilderObject) from DynamicBuilderObject to DynamicBuilderObject {
	public static function create():DynamicBuilder
		return ({} : Dynamic);

	@:from public static function ofDyn(dyn:Dynamic):DynamicBuilder
		return {
			head: dyn, // (dyn : DynamicAccess<Dynamic>),
			target: dyn, // (dyn : DynamicAccess<Dynamic>),
			trail: []
		};

	@:to public function toDyn():Dynamic
		return this.target;

	public function push(key:String, ?head:Dynamic) {
		(this.head : DynamicAccess<Dynamic>).set(key, if (head == null) {} else head);
		this.trail.push({key: key, value: this.head});
		this.head = (this.head : DynamicAccess<Dynamic>)[key];
	}

	public function previousUnnested() {
		var trail = this.trail.copy();
		trail.reverse();
		for (pair in trail) {
			if (pair.key.indexOf('.') == -1) {
				return pair.value;
			}
		}
		return this.target;
	}

	public function print() {
		trace(haxe.Json.stringify(this.target, null, "   "));
	}

	public function getHead():DynamicAccess<Dynamic> {
		return this.head;
	}

	public function setHead(h:Dynamic) {
		this.head = h;
	}

	public function replace(v:Dynamic) {
		var last = this.trail.pop();
		return if (last != null) {
			this.head = last.value;
			this.trail.push({key: last.key, value: this.head});
			(this.head : DynamicAccess<Dynamic>)[last.key] = v;
		} else {
			this.target = v;
		}
	}

	public function rename(newName:String->String) {
		var last = this.trail.pop();
		var self:DynamicBuilder = this;
		this.head = last.value;
		this.trail.push({key: last.key, value: this.head});
		self.push(newName(last.key), (this.head : DynamicAccess<Dynamic>)[last.key]);
		return last.value.remove(last.key);
	}
}
