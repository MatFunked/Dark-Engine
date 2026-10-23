package stages;

import flixel.FlxG;
import flixel.group.FlxGroup;
import flixel.FlxSprite;
import flixel.math.FlxPoint;
import openfl.display.BitmapData;
import openfl.geom.Rectangle;
import openfl.utils.Assets;
import mods.ModManager;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

private typedef StageLayerConfig =
{
	var type:String;
	var name:String;
	var image:String;
	var color:Int;
	var x:Float;
	var y:Float;
	var width:Int;
	var height:Int;
	var scale:Float;
	var alpha:Float;
	var scrollX:Float;
	var scrollY:Float;
	var lineSpacing:Int;
}

private typedef StageConfig =
{
	var name:String;
	var layers:Array<StageLayerConfig>;
	var dadPosition:FlxPoint;
	var bfPosition:FlxPoint;
	var gfPosition:FlxPoint;
	var source:String;
}

class Stage extends FlxGroup
{
	public static inline var DEFAULT_STAGE_NAME:String = "stage";
	public static inline var FALLBACK_STAGE_NAME:String = "Test Grid Studio";

	public var stageName(default, null):String;
	public var displayName(default, null):String = FALLBACK_STAGE_NAME;
	public var usesFallback(default, null):Bool = false;
	public var layerCount(default, null):Int = 0;
	public var dadPosition(default, null):FlxPoint;
	public var bfPosition(default, null):FlxPoint;
	public var gfPosition(default, null):FlxPoint;

	public function new(?requestedStageName:String)
	{
		super();

		stageName = normalizeStageName(requestedStageName);
		var config = isDefaultStage(stageName) ? null : loadStageConfig(stageName);

		if (config != null)
		{
			layerCount = addConfiguredLayers(config);

			if (layerCount > 0)
			{
				displayName = config.name;
				dadPosition = config.dadPosition;
				bfPosition = config.bfPosition;
				gfPosition = config.gfPosition;
				return;
			}
		}

		usesFallback = true;
		displayName = FALLBACK_STAGE_NAME;
		layerCount = buildTestGridStudio();
		setFallbackPositions();
	}

	static function isDefaultStage(stageName:String):Bool
	{
		return stageName == "" || stageName == DEFAULT_STAGE_NAME || stageName == "default";
	}

	static function normalizeStageName(value:String):String
	{
		var name = value == null ? "" : StringTools.trim(value);

		if (name == "")
			return DEFAULT_STAGE_NAME;

		name = name.split("\\").join("/");

		while (name.indexOf("//") >= 0)
			name = name.split("//").join("/");

		while (name.substr(0, 1) == "/")
			name = name.substr(1);

		if (name.indexOf("..") >= 0)
			return DEFAULT_STAGE_NAME;

		if (StringTools.endsWith(name.toLowerCase(), ".json"))
			name = name.substr(0, name.length - 5);

		return name == "" ? DEFAULT_STAGE_NAME : name;
	}

	static function loadStageConfig(stageName:String):StageConfig
	{
		for (path in stageConfigCandidates(stageName))
		{
			var text = readTextAt(path);

			if (text == null)
				continue;

			var config = parseStageConfig(text, path, stageName);

			if (config != null)
				return config;
		}

		return null;
	}

	static function stageConfigCandidates(stageName:String):Array<String>
	{
		var candidates:Array<String> = [];
		var applicationDirectory = lime.system.System.applicationDirectory;
		var relativePath = 'data/stages/$stageName.json';

		ModManager.load();

		for (mod in ModManager.mods)
		{
			if (!ModManager.isActive(mod.id))
				continue;

			addUnique(candidates, 'mods/${mod.folder}/$relativePath');
			addUnique(candidates, '${mod.path}/$relativePath');

			if (applicationDirectory != null && applicationDirectory != "")
				addUnique(candidates, '$applicationDirectory/mods/${mod.folder}/$relativePath');
		}

		addUnique(candidates, 'assets/$relativePath');

		if (applicationDirectory != null && applicationDirectory != "")
			addUnique(candidates, '$applicationDirectory/assets/$relativePath');

		return candidates;
	}

	static function parseStageConfig(text:String, source:String, stageName:String):StageConfig
	{
		var data:Dynamic;

		try
		{
			data = haxe.Json.parse(stripBom(text));
		}
		catch (error:Dynamic)
		{
			return null;
		}

		if (data == null || !Reflect.isObject(data))
			return null;

		var rawLayers:Dynamic = Reflect.field(data, "layers");

		if (!Std.isOfType(rawLayers, Array))
			return null;

		var layers:Array<StageLayerConfig> = [];

		for (entry in cast(rawLayers, Array<Dynamic>))
		{
			var layer = parseLayer(entry);

			if (layer != null)
				layers.push(layer);
		}

		if (layers.length == 0)
			return null;

		return {
			name: stringValue(Reflect.field(data, "name"), stageName),
			layers: layers,
			dadPosition: pointValue(Reflect.field(data, "dadPosition"), FlxG.width * 0.28, defaultCharacterY()),
			bfPosition: pointValue(Reflect.field(data, "bfPosition"), FlxG.width * 0.72, defaultCharacterY()),
			gfPosition: optionalPointValue(Reflect.field(data, "gfPosition")),
			source: source
		};
	}

	static function parseLayer(entry:Dynamic):StageLayerConfig
	{
		if (entry == null || !Reflect.isObject(entry))
			return null;

		var image = firstString(entry, ["image", "sprite", "path"]);
		var rawColor:Dynamic = Reflect.field(entry, "color");
		var type = stringValue(Reflect.field(entry, "type"), "").toLowerCase();

		if (type == "")
			type = image == "" ? (rawColor == null ? "grid" : "color") : "image";

		if (type != "image" && type != "color" && type != "solid" && type != "rect" && type != "grid")
			type = image != "" ? "image" : (rawColor == null ? "grid" : "color");

		var width = intValue(Reflect.field(entry, "width"), Std.int(FlxG.width * 1.8));
		var height = intValue(Reflect.field(entry, "height"), Std.int(FlxG.height * 1.5));
		var scroll = scrollFactorValue(entry);

		return {
			type: type,
			name: stringValue(Reflect.field(entry, "name"), type),
			image: image,
			color: colorValue(rawColor, type == "grid" ? 0x553E5870 : 0xFF101820),
			x: numberValue(Reflect.field(entry, "x"), 0),
			y: numberValue(Reflect.field(entry, "y"), 0),
			width: width,
			height: height,
			scale: numberValue(Reflect.field(entry, "scale"), 1),
			alpha: numberValue(Reflect.field(entry, "alpha"), 1),
			scrollX: scroll.x,
			scrollY: scroll.y,
			lineSpacing: intValue(Reflect.field(entry, "lineSpacing"), 96)
		};
	}

	static function scrollFactorValue(data:Dynamic):FlxPoint
	{
		var raw:Dynamic = Reflect.field(data, "scrollFactor");

		if (raw != null)
		{
			if (Std.isOfType(raw, Array))
			{
				var values:Array<Dynamic> = cast raw;
				return new FlxPoint(values.length > 0 ? numberValue(values[0], 1) : 1, values.length > 1 ? numberValue(values[1], 1) : 1);
			}

			if (Reflect.isObject(raw))
				return new FlxPoint(numberValue(Reflect.field(raw, "x"), 1), numberValue(Reflect.field(raw, "y"), 1));

			var scalar = numberValue(raw, 1);
			return new FlxPoint(scalar, scalar);
		}

		return new FlxPoint(numberValue(Reflect.field(data, "scrollX"), 1), numberValue(Reflect.field(data, "scrollY"), 1));
	}

	function addConfiguredLayers(config:StageConfig):Int
	{
		var added = 0;

		for (layer in config.layers)
		{
			var sprite = createLayerSprite(layer, config.source);

			if (sprite == null)
				continue;

			add(sprite);
			added++;
		}

		return added;
	}

	function createLayerSprite(layer:StageLayerConfig, source:String):FlxSprite
	{
		var sprite:FlxSprite = null;

		if (layer.type == "image")
		{
			var bitmap = loadBitmap(layer.image, source);

			if (bitmap == null)
			{
				FlxG.log.warn('Stage layer "${layer.name}" image not found: ${layer.image}');
				return null;
			}

			sprite = new FlxSprite(layer.x, layer.y);
			sprite.loadGraphic(bitmap);
		}
		else if (layer.type == "grid")
		{
			var bitmap = buildGridBitmap(layer.width, layer.height, layer.lineSpacing, layer.color);
			sprite = new FlxSprite(layer.x, layer.y);
			sprite.loadGraphic(bitmap);
		}
		else
		{
			var bitmap = new BitmapData(layer.width, layer.height, true, layer.color);
			sprite = new FlxSprite(layer.x, layer.y);
			sprite.loadGraphic(bitmap);
		}

		sprite.scrollFactor.set(layer.scrollX, layer.scrollY);
		sprite.scale.set(layer.scale, layer.scale);
		sprite.alpha = layer.alpha;
		sprite.antialiasing = false;
		sprite.immovable = true;

		return sprite;
	}

	function buildTestGridStudio():Int
	{
		var width = Std.int(FlxG.width * 2);
		var height = Std.int(FlxG.height * 2);
		var x = -FlxG.width * 0.5;
		var y = -FlxG.height * 0.5;

		var backdrop = buildBackdropBitmap(width, height);
		var background = new FlxSprite(x, y);
		background.loadGraphic(backdrop);
		background.scrollFactor.set(0.04, 0.04);
		background.antialiasing = false;
		add(background);

		var farGrid = new FlxSprite(x, y);
		farGrid.loadGraphic(buildGridBitmap(width, height, 128, 0x303E5870));
		farGrid.scrollFactor.set(0.14, 0.14);
		farGrid.antialiasing = false;
		add(farGrid);

		var midGrid = new FlxSprite(x, y);
		midGrid.loadGraphic(buildGridBitmap(width, height, 96, 0x604A6B8A));
		midGrid.scrollFactor.set(0.28, 0.28);
		midGrid.antialiasing = false;
		add(midGrid);

		var floor = new FlxSprite(x, FlxG.height * 0.56);
		floor.loadGraphic(buildFloorBitmap(width, Std.int(FlxG.height * 0.6)));
		floor.scrollFactor.set(0.55, 0.5);
		floor.antialiasing = false;
		add(floor);

		return 4;
	}

	function setFallbackPositions():Void
	{
		var characterY = defaultCharacterY();
		dadPosition = new FlxPoint(FlxG.width * 0.28, characterY);
		bfPosition = new FlxPoint(FlxG.width * 0.72, characterY);
		gfPosition = null;
	}

	static function defaultCharacterY():Float
	{
		return FlxG.height * 0.13;
	}

	static function buildBackdropBitmap(width:Int, height:Int):BitmapData
	{
		var bitmap = new BitmapData(width, height, true, 0xFF0A0F17);
		var horizon = Std.int(height * 0.34);

		bitmap.fillRect(new Rectangle(0, horizon, width, 3), 0xFF24384C);
		bitmap.fillRect(new Rectangle(0, horizon + 3, width, Std.int(height * 0.08)), 0xFF101A26);
		bitmap.fillRect(new Rectangle(0, Std.int(height * 0.66), width, height), 0xFF080C12);

		for (i in 0...8)
		{
			var lineY = horizon + 20 + i * 12;
			bitmap.fillRect(new Rectangle(0, lineY, width, 1), 0x182C4058);
		}

		return bitmap;
	}

	static function buildGridBitmap(width:Int, height:Int, spacing:Int, color:Int):BitmapData
	{
		var bitmap = new BitmapData(width, height, true, 0x00000000);
		var horizonX = Std.int(width * 0.5);
		var horizonY = Std.int(height * 0.34);
		var step = spacing < 16 ? 16 : spacing;

		var bottomSteps = Std.int(width / step) + 1;

		for (i in -bottomSteps...bottomSteps + 1)
		{
			var bottomX = horizonX + i * step;
			drawLine(bitmap, horizonX, horizonY, bottomX, height, color);
		}

		var row = 1;

		while (true)
		{
			var t = row / 18;
			var lineY = Std.int(horizonY + (height - horizonY) * t * t);

			if (lineY >= height)
				break;

			bitmap.fillRect(new Rectangle(0, lineY, width, 1), color);
			row++;
		}

		bitmap.fillRect(new Rectangle(0, horizonY, width, 1), color);
		return bitmap;
	}

	static function buildFloorBitmap(width:Int, height:Int):BitmapData
	{
		var bitmap = new BitmapData(width, height, true, 0x00000000);
		bitmap.fillRect(new Rectangle(0, 0, width, 2), 0x805E7EA0);

		for (i in 1...8)
		{
			var lineY = Std.int(height * i / 8);
			bitmap.fillRect(new Rectangle(0, lineY, width, 1), 0x303E5870);
		}

		return bitmap;
	}

	static function drawLine(bitmap:BitmapData, x0:Int, y0:Int, x1:Int, y1:Int, color:Int):Void
	{
		var dx = Std.int(Math.abs(x1 - x0));
		var dy = Std.int(-Math.abs(y1 - y0));
		var sx = x0 < x1 ? 1 : -1;
		var sy = y0 < y1 ? 1 : -1;
		var error = dx + dy;
		var x = x0;
		var y = y0;

		while (true)
		{
			if (x >= 0 && x < bitmap.width && y >= 0 && y < bitmap.height)
				bitmap.setPixel32(x, y, color);

			if (x == x1 && y == y1)
				break;

			var doubled = error * 2;

			if (doubled >= dy)
			{
				error += dy;
				x += sx;
			}

			if (doubled <= dx)
			{
				error += dx;
				y += sy;
			}
		}
	}

	static function loadBitmap(path:String, source:String):BitmapData
	{
		for (candidate in imageCandidates(path, source))
		{
			var bitmap = loadBitmapAt(candidate);

			if (bitmap != null)
				return bitmap;
		}

		return null;
	}

	static function imageCandidates(path:String, source:String):Array<String>
	{
		var candidates:Array<String> = [];
		var image = path == null ? "" : StringTools.trim(path);

		if (image == "")
			return candidates;

		image = image.split("\\").join("/");
		addImagePath(candidates, image);

		var applicationDirectory = lime.system.System.applicationDirectory;

		if (applicationDirectory != null && applicationDirectory != "")
			addImagePath(candidates, '$applicationDirectory/$image');

		if (source != null)
		{
			var marker = "/data/stages/";
			var markerIndex = source.split("\\").join("/").indexOf(marker);

			if (markerIndex >= 0)
			{
				var root = source.split("\\").join("/").substr(0, markerIndex);
				addImagePath(candidates, '$root/images/$image');
			}
		}

		addImagePath(candidates, 'assets/images/$image');

		ModManager.load();

		for (mod in ModManager.mods)
		{
			if (!ModManager.isActive(mod.id))
				continue;

			addImagePath(candidates, 'mods/${mod.folder}/images/$image');
			addImagePath(candidates, '${mod.path}/images/$image');
		}

		return candidates;
	}

	static function addImagePath(candidates:Array<String>, path:String):Void
	{
		addUnique(candidates, path);

		var lower = path.toLowerCase();

		if (!StringTools.endsWith(lower, ".png") && !StringTools.endsWith(lower, ".jpg") && !StringTools.endsWith(lower, ".jpeg")
			&& !StringTools.endsWith(lower, ".webp"))
			addUnique(candidates, '$path.png');
	}

	static function loadBitmapAt(path:String):BitmapData
	{
		try
		{
			if (Assets.exists(path))
				return Assets.getBitmapData(path);
		}
		catch (error:Dynamic) {}

		#if sys
		try
		{
			if (FileSystem.exists(path))
				return BitmapData.fromBytes(File.getBytes(path));
		}
		catch (error:Dynamic) {}
		#end

		return null;
	}

	static function readTextAt(path:String):String
	{
		try
		{
			if (Assets.exists(path))
				return Assets.getText(path);
		}
		catch (error:Dynamic) {}

		#if sys
		try
		{
			if (FileSystem.exists(path))
				return File.getContent(path);
		}
		catch (error:Dynamic) {}
		#end

		return null;
	}

	static function stripBom(text:String):String
	{
		if (text != null && text.length > 0 && text.charCodeAt(0) == 0xFEFF)
			return text.substr(1);

		return text;
	}

	static function pointValue(value:Dynamic, fallbackX:Float, fallbackY:Float):FlxPoint
	{
		if (value == null)
			return new FlxPoint(fallbackX, fallbackY);

		if (Std.isOfType(value, Array))
		{
			var values:Array<Dynamic> = cast value;
			return new FlxPoint(values.length > 0 ? numberValue(values[0], fallbackX) : fallbackX,
				values.length > 1 ? numberValue(values[1], fallbackY) : fallbackY);
		}

		if (Reflect.isObject(value))
			return new FlxPoint(numberValue(Reflect.field(value, "x"), fallbackX), numberValue(Reflect.field(value, "y"), fallbackY));

		return new FlxPoint(fallbackX, fallbackY);
	}

	static function optionalPointValue(value:Dynamic):FlxPoint
	{
		if (value == null)
			return null;

		return pointValue(value, 0, 0);
	}

	static function firstString(data:Dynamic, fields:Array<String>):String
	{
		for (field in fields)
		{
			var value = Reflect.field(data, field);

			if (value != null)
			{
				var text = StringTools.trim(Std.string(value));

				if (text != "")
					return text;
			}
		}

		return "";
	}

	static function stringValue(value:Dynamic, fallback:String):String
	{
		if (value == null)
			return fallback;

		var text = StringTools.trim(Std.string(value));
		return text == "" ? fallback : text;
	}

	static function numberValue(value:Dynamic, fallback:Float):Float
	{
		if (value == null)
			return fallback;

		if (Std.isOfType(value, Int) || Std.isOfType(value, Float))
			return cast value;

		var parsed = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
	}

	static function intValue(value:Dynamic, fallback:Int):Int
	{
		return Std.int(numberValue(value, fallback));
	}

	static function colorValue(value:Dynamic, fallback:Int):Int
	{
		if (value == null)
			return fallback;

		if (Std.isOfType(value, Int))
			return cast value;

		var text = StringTools.trim(Std.string(value).toLowerCase());

		if (text == "")
			return fallback;

		if (StringTools.startsWith(text, "0x"))
		{
			var parsed = Std.parseInt("0x" + text.substr(2));
			return parsed == null ? fallback : parsed;
		}

		if (StringTools.startsWith(text, "#"))
		{
			var digits = text.substr(1);

			if (digits.length == 6)
				digits = "ff" + digits;

			var parsed = Std.parseInt("0x" + digits);
			return parsed == null ? fallback : parsed;
		}

		return fallback;
	}

	static function addUnique(list:Array<String>, value:String):Void
	{
		if (value == null || value == "" || list.indexOf(value) >= 0)
			return;

		list.push(value);
	}
}
