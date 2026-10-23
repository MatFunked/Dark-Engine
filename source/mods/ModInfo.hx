package mods;

class ModInfo
{
	public var id:String;
	public var name:String;
	public var description:String;
	public var dependencies:Array<String>;
	public var enabledByDefault:Bool;
	public var folder:String;
	public var path:String;
	public var songs:Array<String>;
	public var error:String;

	public function new(id:String, name:String, description:String, dependencies:Array<String>, enabledByDefault:Bool, folder:String, path:String,
			?songs:Array<String>)
	{
		this.id = id;
		this.name = name;
		this.description = description;
		this.dependencies = dependencies;
		this.enabledByDefault = enabledByDefault;
		this.folder = folder;
		this.path = path;
		this.songs = songs == null ? [] : songs;
	}

	public static function fromJson(json:Dynamic, folder:String, path:String):ModInfo
	{
		var id = readString(Reflect.field(json, "id"), folder);
		var name = readString(Reflect.field(json, "name"), id);
		var description = readString(Reflect.field(json, "description"), "");
		var dependencies = readDependencies(Reflect.field(json, "dependencies"));
		var enabledByDefault = readBool(Reflect.field(json, "enabledByDefault"), true);

		if (id == "")
			id = folder;
		if (name == "")
			name = id;

		return new ModInfo(id, name, description, dependencies, enabledByDefault, folder, path);
	}

	static function readString(value:Dynamic, fallback:String):String
	{
		if (value == null)
			return fallback;

		return StringTools.trim(Std.string(value));
	}

	static function readBool(value:Dynamic, fallback:Bool):Bool
	{
		if (value == null)
			return fallback;

		if (Std.isOfType(value, Bool))
			return cast value;

		var text = Std.string(value).toLowerCase();
		return text == "true" || text == "1";
	}

	static function readDependencies(value:Dynamic):Array<String>
	{
		var dependencies:Array<String> = [];

		if (value == null || !Std.isOfType(value, Array))
			return dependencies;

		for (entry in cast(value, Array<Dynamic>))
		{
			var dependency = readString(entry, "");

			if (dependency != "" && !dependencies.contains(dependency))
				dependencies.push(dependency);
		}

		return dependencies;
	}
}
