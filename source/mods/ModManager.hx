package mods;

import flixel.FlxG;
import openfl.utils.Assets;
import settings.GameSettings;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

class ModManager
{
	static inline var MODS_ROOT:String = "mods";
	static inline var MOD_JSON:String = "mod.json";
	static inline var SAVE_FIELD:String = "modEnabled";

	public static var mods(default, null):Array<ModInfo> = [];
	public static var loaded(default, null):Bool = false;

	static var overrides:Map<String, Bool> = new Map();
	static var songOwners:Map<String, Array<String>> = new Map();

	public static function load(?force:Bool = false):Void
	{
		if (loaded && !force)
			return;

		loaded = true;
		GameSettings.ensureSave();
		overrides = readOverrides();
		mods = scanMods();
		rebuildSongOwners();
	}

	public static function reload():Void
	{
		load(true);
	}

	public static function getMod(id:String):ModInfo
	{
		for (mod in mods)
		{
			if (mod.id == id)
				return mod;
		}

		return null;
	}

	public static function isRequestedEnabled(mod:ModInfo):Bool
	{
		if (mod == null || mod.error != null)
			return false;

		return overrides.exists(mod.id) ? overrides.get(mod.id) : mod.enabledByDefault;
	}

	public static function isActive(id:String):Bool
	{
		return checkActive(getMod(id), new Map());
	}

	public static function isSongAvailable(songFolder:String):Bool
	{
		load();

		var owners = songOwners.get(songFolder);

		if (owners == null || owners.length == 0)
			return true;

		for (owner in owners)
		{
			if (isActive(owner))
				return true;
		}

		return false;
	}

	public static function canActivate(mod:ModInfo):Bool
	{
		return mod != null && mod.error == null && getMissingDependencies(mod).length == 0;
	}

	public static function getMissingDependencies(mod:ModInfo):Array<String>
	{
		var missing:Array<String> = [];

		if (mod == null)
			return missing;

		for (dependency in mod.dependencies)
		{
			if (!isActive(dependency))
				missing.push(dependency);
		}

		return missing;
	}

	public static function dependencyState(dependency:String):String
	{
		var mod = getMod(dependency);

		if (mod == null)
			return "MISSING";
		if (mod.error != null)
			return "ERROR";
		if (!isRequestedEnabled(mod))
			return "OFF";

		return isActive(mod.id) ? "OK" : "BLOCKED";
	}

	public static function setEnabled(id:String, enabled:Bool):Array<String>
	{
		var mod = getMod(id);

		if (mod == null || mod.error != null)
			return [];

		if (enabled)
		{
			if (getMissingDependencies(mod).length > 0)
				return [];

			overrides.set(mod.id, true);
			return [];
		}

		if (!isRequestedEnabled(mod))
			return [];

		var disabledDependents:Array<String> = [];
		collectActiveDependents(mod.id, disabledDependents, new Map());
		overrides.set(mod.id, false);

		for (dependentId in disabledDependents)
			overrides.set(dependentId, false);

		return disabledDependents;
	}

	public static function save():Void
	{
		GameSettings.ensureSave();

		var data:Dynamic = {};

		for (id in overrides.keys())
			Reflect.setField(data, id, overrides.get(id));

		Reflect.setField(FlxG.save.data, SAVE_FIELD, data);
		FlxG.save.flush();
	}

	static function checkActive(mod:ModInfo, visiting:Map<String, Bool>):Bool
	{
		if (mod == null || mod.error != null || !isRequestedEnabled(mod))
			return false;

		if (visiting.exists(mod.id))
			return false;

		visiting.set(mod.id, true);

		for (dependency in mod.dependencies)
		{
			if (!checkActive(getMod(dependency), visiting))
			{
				visiting.remove(mod.id);
				return false;
			}
		}

		visiting.remove(mod.id);
		return true;
	}

	static function collectActiveDependents(id:String, result:Array<String>, visited:Map<String, Bool>):Void
	{
		for (mod in mods)
		{
			if (mod.id == id || visited.exists(mod.id) || mod.dependencies.indexOf(id) < 0)
				continue;

			visited.set(mod.id, true);

			if (isActive(mod.id))
				result.push(mod.id);

			collectActiveDependents(mod.id, result, visited);
		}
	}

	static function rebuildSongOwners():Void
	{
		songOwners = new Map();

		for (mod in mods)
		{
			for (song in mod.songs)
			{
				var owners = songOwners.get(song);

				if (owners == null)
				{
					owners = [];
					songOwners.set(song, owners);
				}

				if (!owners.contains(mod.id))
					owners.push(mod.id);
			}
		}
	}

	static function readOverrides():Map<String, Bool>
	{
		var result:Map<String, Bool> = new Map();
		var data:Dynamic = Reflect.field(FlxG.save.data, SAVE_FIELD);

		if (data == null || !Reflect.isObject(data))
			return result;

		for (field in Reflect.fields(data))
		{
			var value:Dynamic = Reflect.field(data, field);
			result.set(field, value == true || Std.string(value).toLowerCase() == "true");
		}

		return result;
	}

	static function scanMods():Array<ModInfo>
	{
		var found:Array<ModInfo> = [];
		var seenIds:Map<String, Bool> = new Map();

		#if sys
		scanPhysical(found, seenIds);
		#end

		scanVirtual(found, seenIds);
		found.sort(compareMods);

		return found;
	}

	#if sys
	static function scanPhysical(found:Array<ModInfo>, seenIds:Map<String, Bool>):Void
	{
		for (root in physicalRoots())
		{
			var entries:Array<String> = [];

			try
			{
				entries = FileSystem.readDirectory(root);
			}
			catch (error:Dynamic)
			{
				continue;
			}

			entries.sort(compareNames);

			for (folder in entries)
			{
				var folderPath = '$root/$folder';

				try
				{
					if (!FileSystem.isDirectory(folderPath))
						continue;

					var jsonPath = '$folderPath/$MOD_JSON';

					if (!FileSystem.exists(jsonPath))
						continue;

					var mod = parseMod(File.getContent(jsonPath), folder, folderPath);
					mod.songs = discoverPhysicalSongs(folderPath);
					addUnique(found, seenIds, mod);
				}
				catch (error:Dynamic)
				{
					var mod = invalidMod(folder, folderPath, "READ ERROR");
					mod.songs = discoverPhysicalSongs(folderPath);
					addUnique(found, seenIds, mod);
				}
			}
		}
	}

	static function physicalRoots():Array<String>
	{
		var roots:Array<String> = [];
		addPhysicalRoot(roots, MODS_ROOT);

		var applicationDirectory = lime.system.System.applicationDirectory;

		if (applicationDirectory != null && applicationDirectory != "")
			addPhysicalRoot(roots, '$applicationDirectory/$MODS_ROOT');

		return roots;
	}

	static function addPhysicalRoot(roots:Array<String>, root:String):Void
	{
		if (roots.indexOf(root) >= 0)
			return;

		try
		{
			if (FileSystem.exists(root) && FileSystem.isDirectory(root))
				roots.push(root);
		}
		catch (error:Dynamic) {}
	}

	static function discoverPhysicalSongs(folderPath:String):Array<String>
	{
		var songs:Array<String> = [];
		var songsRoot = '$folderPath/songs';

		try
		{
			if (!FileSystem.exists(songsRoot) || !FileSystem.isDirectory(songsRoot))
				return songs;

			for (entry in FileSystem.readDirectory(songsRoot))
			{
				var songPath = '$songsRoot/$entry';

				if (FileSystem.isDirectory(songPath) && FileSystem.exists('$songPath/meta.json'))
					songs.push(entry);
			}
		}
		catch (error:Dynamic) {}

		songs.sort(compareNames);
		return songs;
	}
	#end

	static function scanVirtual(found:Array<ModInfo>, seenIds:Map<String, Bool>):Void
	{
		var assets = Assets.list();
		var prefixes:Array<String> = ['$MODS_ROOT/', 'assets/$MODS_ROOT/'];
		var songsByMod = collectVirtualSongs(assets, prefixes);
		var suffix = '/$MOD_JSON';

		for (asset in assets)
		{
			var prefix = matchPrefix(asset, prefixes);

			if (prefix == null || !StringTools.endsWith(asset, suffix))
				continue;

			var rest = asset.substr(prefix.length);
			var folder = rest.substr(0, rest.length - suffix.length);

			if (folder == "" || folder.indexOf("/") >= 0)
				continue;

			var folderPath = prefix + folder;
			var jsonText:String = null;

			try
			{
				jsonText = Assets.getText(asset);
			}
			catch (error:Dynamic) {}

			var mod = parseMod(jsonText, folder, folderPath);
			var songs = songsByMod.get(folderPath);

			if (songs != null)
				mod.songs = songs;

			addUnique(found, seenIds, mod);
		}
	}

	static function collectVirtualSongs(assets:Array<String>, prefixes:Array<String>):Map<String, Array<String>>
	{
		var songsByMod:Map<String, Array<String>> = new Map();

		for (asset in assets)
		{
			var prefix = matchPrefix(asset, prefixes);

			if (prefix == null)
				continue;

			var parts = asset.substr(prefix.length).split("/");

			if (parts.length != 4 || parts[1] != "songs" || parts[3] != "meta.json")
				continue;

			var folderPath = prefix + parts[0];
			var songs = songsByMod.get(folderPath);

			if (songs == null)
			{
				songs = [];
				songsByMod.set(folderPath, songs);
			}

			if (!songs.contains(parts[2]))
				songs.push(parts[2]);
		}

		return songsByMod;
	}

	static function matchPrefix(path:String, prefixes:Array<String>):String
	{
		for (prefix in prefixes)
		{
			if (path.indexOf(prefix) == 0)
				return prefix;
		}

		return null;
	}

	static function parseMod(jsonText:String, folder:String, path:String):ModInfo
	{
		jsonText = stripBom(jsonText);

		if (jsonText == null || StringTools.trim(jsonText) == "")
			return invalidMod(folder, path, "EMPTY mod.json");

		try
		{
			var json:Dynamic = haxe.Json.parse(jsonText);

			if (json == null || Std.isOfType(json, Array) || !Reflect.isObject(json))
				return invalidMod(folder, path, "INVALID mod.json");

			return ModInfo.fromJson(json, folder, path);
		}
		catch (error:Dynamic)
		{
			return invalidMod(folder, path, "INVALID mod.json");
		}
	}

	static function stripBom(text:String):String
	{
		if (text != null && text.length > 0 && text.charCodeAt(0) == 0xFEFF)
			return text.substr(1);

		return text;
	}

	static function invalidMod(folder:String, path:String, message:String):ModInfo
	{
		var mod = new ModInfo(folder, folder, message, [], false, folder, path);
		mod.error = message;

		return mod;
	}

	static function addUnique(found:Array<ModInfo>, seenIds:Map<String, Bool>, mod:ModInfo):Void
	{
		if (mod == null || seenIds.exists(mod.id))
			return;

		seenIds.set(mod.id, true);
		found.push(mod);
	}

	static function compareMods(a:ModInfo, b:ModInfo):Int
	{
		var left = a.name.toLowerCase();
		var right = b.name.toLowerCase();

		if (left < right)
			return -1;
		if (left > right)
			return 1;

		return compareNames(a.id, b.id);
	}

	static function compareNames(a:String, b:String):Int
	{
		var left = a.toLowerCase();
		var right = b.toLowerCase();

		if (left < right)
			return -1;
		if (left > right)
			return 1;

		return 0;
	}
}
