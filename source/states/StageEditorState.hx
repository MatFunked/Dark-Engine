package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;
import mods.ModManager;
import openfl.display.BitmapData;
import openfl.geom.Rectangle;
import openfl.utils.Assets;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

private typedef EditorLayer =
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
	var sprite:FlxSprite;
}

private typedef StageInfo =
{
	var name:String;
	var path:String;
}

private typedef ImageInfo =
{
	var key:String;
	var path:String;
}

private typedef MarkerInfo =
{
	var name:String;
	var color:Int;
	var x:Float;
	var y:Float;
	var width:Float;
	var height:Float;
	var body:FlxSprite;
	var cross:FlxSprite;
	var label:FlxText;
}

class StageEditorState extends FlxState
{
	static inline var SAVE_ROOT:String = "assets/data/stages/";
	static inline var IMAGE_ROOT:String = "assets/images/";
	static inline var LEFT_PANEL_X:Float = 12;
	static inline var LEFT_PANEL_Y:Float = 66;
	static inline var LEFT_PANEL_WIDTH:Float = 360;
	static inline var LEFT_PANEL_HEIGHT:Float = 506;
	static inline var RIGHT_PANEL_X:Float = 908;
	static inline var RIGHT_PANEL_WIDTH:Float = 360;
	static inline var LAYER_LIST_X:Float = 24;
	static inline var LAYER_LIST_Y:Float = 108;
	static inline var LAYER_LIST_WIDTH:Float = 336;
	static inline var LAYER_ROW_HEIGHT:Float = 27;
	static inline var LAYER_ROWS:Int = 12;
	static inline var IMAGE_LIST_X:Float = 920;
	static inline var IMAGE_LIST_Y:Float = 108;
	static inline var IMAGE_LIST_WIDTH:Float = 336;
	static inline var IMAGE_ROW_HEIGHT:Float = 25;
	static inline var IMAGE_ROWS:Int = 10;
	static inline var BOTTOM_PANEL_Y:Float = 580;
	static inline var BOTTOM_PANEL_HEIGHT:Float = 128;
	static inline var MOVE_STEP:Float = 1;
	static inline var FAST_MOVE_STEP:Float = 10;
	static inline var SCALE_STEP:Float = 0.05;
	static inline var SCROLL_STEP:Float = 0.01;
	static inline var MIN_SCALE:Float = 0.05;
	static inline var MAX_SCALE:Float = 10;
	static inline var MIN_SCROLL:Float = -10;
	static inline var MAX_SCROLL:Float = 10;

	static var TARGET_LAYER:Int = 0;
	static var TARGET_DAD:Int = 1;
	static var TARGET_BF:Int = 2;
	static var TARGET_GF:Int = 3;

	var stageGroup:FlxGroup;
	var overlayGroup:FlxGroup;
	var uiGroup:FlxGroup;

	var stageInfos:Array<StageInfo> = [];
	var stageIndex:Int = -1;
	var stageName:String = "untitled";
	var stageDisplayName:String = "Untitled";
	var stageSource:String = null;
	var layers:Array<EditorLayer> = [];
	var selectedLayer:Int = -1;
	var layerOffset:Int = 0;
	var target:Int = TARGET_LAYER;

	var imageInfos:Array<ImageInfo> = [];
	var selectedImage:Int = 0;
	var imageOffset:Int = 0;

	var markers:Array<MarkerInfo> = [];
	var outlineParts:Array<FlxSprite> = [];

	var headerText:FlxText;
	var stageText:FlxText;
	var layerHeader:FlxText;
	var layerTexts:Array<FlxText> = [];
	var layerSelectionBar:FlxSprite;
	var layerDetailsText:FlxText;
	var imageHeader:FlxText;
	var imageTexts:Array<FlxText> = [];
	var imageSelectionBar:FlxSprite;
	var imageDetailsText:FlxText;
	var imageHintText:FlxText;
	var targetText:FlxText;
	var anchorsText:FlxText;
	var saveText:FlxText;
	var statusText:FlxText;
	var hintText:FlxText;
	var hintText2:FlxText;

	var dirty:Bool = false;
	var exitArmed:Bool = false;
	var uiHidden:Bool = false;

	override public function create():Void
	{
		super.create();

		bgColor = 0xFF090D14;
		FlxG.camera.scroll.set(0, 0);
		FlxG.camera.zoom = 1;
		ModManager.reload();

		stageGroup = new FlxGroup();
		overlayGroup = new FlxGroup();
		uiGroup = new FlxGroup();
		add(stageGroup);
		add(overlayGroup);
		add(uiGroup);

		stageInfos = discoverStages();
		imageInfos = discoverImages();

		buildMarkers();
		buildOutline();
		buildUi();

		if (stageInfos.length > 0)
			loadStage(0);
		else
			createNewStage();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (FlxG.mouse.justPressed)
			handleMouse(FlxG.mouse.x, FlxG.mouse.y);

		if (FlxG.keys.justPressed.ESCAPE)
		{
			if (dirty && !exitArmed)
			{
				exitArmed = true;
				setStatus("UNSAVED CHANGES - PRESS ESC AGAIN TO DISCARD", 0xFFFFAA33);
			}
			else
			{
				FlxG.switchState(new MainMenuState());
			}

			return;
		}

		if (FlxG.keys.justPressed.SPACE || (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S))
		{
			saveStage();
			return;
		}

		if (FlxG.keys.justPressed.F5)
		{
			cycleStage(-1);
			return;
		}

		if (FlxG.keys.justPressed.F6)
		{
			cycleStage(1);
			return;
		}

		if (FlxG.keys.justPressed.F7)
		{
			requestNewStage();
			return;
		}

		if (FlxG.keys.justPressed.H)
		{
			uiHidden = !uiHidden;
			uiGroup.visible = !uiHidden;
			return;
		}

		if (FlxG.keys.justPressed.TAB)
		{
			target = TARGET_LAYER;
			cycleLayer(FlxG.keys.pressed.SHIFT ? -1 : 1);
			return;
		}

		if (FlxG.keys.justPressed.ONE)
		{
			selectTarget(TARGET_DAD);
			return;
		}

		if (FlxG.keys.justPressed.TWO)
		{
			selectTarget(TARGET_BF);
			return;
		}

		if (FlxG.keys.justPressed.THREE)
		{
			selectTarget(TARGET_GF);
			return;
		}

		if (FlxG.keys.justPressed.N)
		{
			cycleImage(1);
			return;
		}

		if (FlxG.keys.justPressed.P)
		{
			cycleImage(-1);
			return;
		}

		if (FlxG.keys.justPressed.A)
		{
			addSelectedImage();
			return;
		}

		if (FlxG.keys.justPressed.LBRACKET)
		{
			moveLayerOrder(-1);
			return;
		}

		if (FlxG.keys.justPressed.RBRACKET)
		{
			moveLayerOrder(1);
			return;
		}

		if (FlxG.keys.justPressed.DELETE)
		{
			deleteSelectedLayer();
			return;
		}

		if (target == TARGET_LAYER)
			handleLayerInput();
		else
			handleMarkerInput();
	}

	function buildMarkers():Void
	{
		markers.push(createMarker("DAD", 0xFFFF5566, 92, 156));
		markers.push(createMarker("BF", 0xFF55AAFF, 84, 150));
		markers.push(createMarker("GF", 0xFFCC77FF, 78, 144));
		setDefaultMarkerPositions();
	}

	function createMarker(name:String, color:Int, width:Float, height:Float):MarkerInfo
	{
		var body = new FlxSprite();
		body.makeGraphic(Std.int(width), Std.int(height), color);
		body.alpha = 0.12;
		overlayGroup.add(body);

		var crossData = new BitmapData(33, 33, true, 0x00000000);
		crossData.fillRect(new Rectangle(15, 0, 3, 33), color);
		crossData.fillRect(new Rectangle(0, 15, 33, 3), color);

		var cross = new FlxSprite();
		cross.loadGraphic(crossData);
		overlayGroup.add(cross);

		var label = new FlxText(0, 0, 180, "", 14);
		label.alignment = FlxTextAlign.CENTER;
		label.color = color;
		overlayGroup.add(label);

		return {
			name: name,
			color: color,
			x: 0,
			y: 0,
			width: width,
			height: height,
			body: body,
			cross: cross,
			label: label
		};
	}

	function buildOutline():Void
	{
		for (i in 0...4)
		{
			var part = new FlxSprite();
			part.makeGraphic(i < 2 ? 1 : 2, i < 2 ? 2 : 1, 0xFF66CCFF);
			part.visible = false;
			overlayGroup.add(part);
			outlineParts.push(part);
		}
	}

	function buildUi():Void
	{
		addPanel(LEFT_PANEL_X, LEFT_PANEL_Y, LEFT_PANEL_WIDTH, LEFT_PANEL_HEIGHT);
		addPanel(RIGHT_PANEL_X, LEFT_PANEL_Y, RIGHT_PANEL_WIDTH, LEFT_PANEL_HEIGHT);
		addPanel(12, BOTTOM_PANEL_Y, FlxG.width - 24, BOTTOM_PANEL_HEIGHT);

		headerText = addText(0, 8, FlxG.width, "STAGE EDITOR", 28);
		headerText.alignment = FlxTextAlign.CENTER;
		headerText.color = FlxColor.WHITE;

		stageText = addText(0, 42, FlxG.width, "", 15);
		stageText.alignment = FlxTextAlign.CENTER;
		stageText.color = 0xFF9AA2B8;

		layerHeader = addText(LEFT_PANEL_X + 12, 78, LEFT_PANEL_WIDTH - 24, "LAYERS  (TAB / SHIFT+TAB / CLICK)", 17);
		layerHeader.color = 0xFF7D8AA6;

		layerSelectionBar = new FlxSprite(LEFT_PANEL_X + 6, 0);
		layerSelectionBar.makeGraphic(Std.int(LEFT_PANEL_WIDTH - 12), Std.int(LAYER_ROW_HEIGHT - 3), 0xFF1B2A3D);
		uiGroup.add(layerSelectionBar);

		for (i in 0...LAYER_ROWS)
		{
			var row = addText(LAYER_LIST_X, LAYER_LIST_Y + i * LAYER_ROW_HEIGHT, LAYER_LIST_WIDTH, "", 15);
			layerTexts.push(row);
		}

		layerDetailsText = addText(LEFT_PANEL_X + 12, 444, LEFT_PANEL_WIDTH - 24, "", 13);
		layerDetailsText.wordWrap = true;
		layerDetailsText.color = 0xFFB8C2D8;

		imageHeader = addText(RIGHT_PANEL_X + 12, 78, RIGHT_PANEL_WIDTH - 24, "STAGE IMAGES  (N/P / CLICK)", 17);
		imageHeader.color = 0xFF7D8AA6;

		imageSelectionBar = new FlxSprite(RIGHT_PANEL_X + 6, 0);
		imageSelectionBar.makeGraphic(Std.int(RIGHT_PANEL_WIDTH - 12), Std.int(IMAGE_ROW_HEIGHT - 3), 0xFF1B2A3D);
		uiGroup.add(imageSelectionBar);

		for (i in 0...IMAGE_ROWS)
		{
			var row = addText(IMAGE_LIST_X, IMAGE_LIST_Y + i * IMAGE_ROW_HEIGHT, IMAGE_LIST_WIDTH, "", 14);
			imageTexts.push(row);
		}

		imageDetailsText = addText(RIGHT_PANEL_X + 12, 370, RIGHT_PANEL_WIDTH - 24, "", 13);
		imageDetailsText.wordWrap = true;
		imageDetailsText.color = 0xFFB8C2D8;

		imageHintText = addText(RIGHT_PANEL_X + 12, 488, RIGHT_PANEL_WIDTH - 24, "A: ADD SELECTED IMAGE\nDEL: REMOVE LAYER    [/] : REORDER", 13);
		imageHintText.color = 0xFF7D8AA6;

		targetText = addText(24, 590, FlxG.width - 48, "", 13);
		targetText.color = FlxColor.WHITE;

		anchorsText = addText(24, 610, FlxG.width - 48, "", 13);
		anchorsText.color = 0xFFB8C2D8;

		saveText = addText(24, 632, FlxG.width - 48, "", 13);
		saveText.color = 0xFF9AA2B8;

		statusText = addText(24, 656, FlxG.width - 48, "", 13);
		statusText.color = 0xFF66FF88;

		hintText = addText(24, 678, FlxG.width - 48,
			"ARROWS: MOVE    SHIFT+ARROWS: SCROLL    Q/E OR -/=: SCALE    TAB: LAYER    1/2/3: DAD/BF/GF", 12);
		hintText.color = 0xFF66718A;

		hintText2 = addText(24, 694, FlxG.width - 48,
			"CLICK: SELECT    N/P: IMAGE    A: ADD    DEL: REMOVE    [/]: ORDER    F5/F6: STAGE    F7: NEW    H: HIDE UI    SPACE / CTRL+S: SAVE    ESC: BACK",
			12);
		hintText2.color = 0xFF66718A;
	}

	function addPanel(x:Float, y:Float, width:Float, height:Float):Void
	{
		var panel = new FlxSprite(x, y);
		panel.makeGraphic(Std.int(width), Std.int(height), 0xE6101520);
		uiGroup.add(panel);
	}

	function addText(x:Float, y:Float, width:Float, text:String, size:Int):FlxText
	{
		var label = new FlxText(x, y, width, text, size);
		uiGroup.add(label);
		return label;
	}

	function discoverStages():Array<StageInfo>
	{
		var found:Map<String, StageInfo> = new Map();
		ModManager.load();

		for (mod in ModManager.mods)
		{
			if (!ModManager.isActive(mod.id))
				continue;

			scanStageDirectory(found, 'mods/${mod.folder}/data/stages');
			scanStageDirectory(found, '${mod.path}/data/stages');
		}

		scanStageDirectory(found, 'assets/data/stages');

		var applicationDirectory = lime.system.System.applicationDirectory;

		if (applicationDirectory != null && applicationDirectory != "")
			scanStageDirectory(found, '$applicationDirectory/assets/data/stages');

		for (asset in Assets.list())
		{
			var path = asset.split("\\").join("/");
			var prefix = "assets/data/stages/";

			if (path.indexOf(prefix) != 0 || !StringTools.endsWith(path.toLowerCase(), ".json"))
				continue;

			var rest = path.substr(prefix.length);

			if (rest == "" || rest.indexOf("/") >= 0)
				continue;

			addStageInfo(found, stripExtension(rest), path);
		}

		var result:Array<StageInfo> = [];

		for (info in found)
			result.push(info);

		result.sort(function(a:StageInfo, b:StageInfo):Int
		{
			return compareNames(a.name, b.name);
		});

		return result;
	}

	function scanStageDirectory(found:Map<String, StageInfo>, directory:String):Void
	{
		#if sys
		try
		{
			if (!FileSystem.exists(directory) || !FileSystem.isDirectory(directory))
				return;

			for (file in FileSystem.readDirectory(directory))
			{
				if (!StringTools.endsWith(file.toLowerCase(), ".json"))
					continue;

				addStageInfo(found, stripExtension(file), '$directory/$file');
			}
		}
		catch (error:Dynamic) {}
		#end
	}

	function addStageInfo(found:Map<String, StageInfo>, name:String, path:String):Void
	{
		if (name == null || name == "")
			return;

		var key = name.toLowerCase();

		if (found.exists(key))
			return;

		found.set(key, {name: name, path: path});
	}

	function discoverImages():Array<ImageInfo>
	{
		var found:Map<String, ImageInfo> = new Map();
		ModManager.load();

		for (mod in ModManager.mods)
		{
			if (!ModManager.isActive(mod.id))
				continue;

			scanImageDirectory(found, 'mods/${mod.folder}/images/stages', "stages");
			scanImageDirectory(found, '${mod.path}/images/stages', "stages");
		}

		scanImageDirectory(found, 'assets/images/stages', "stages");

		var applicationDirectory = lime.system.System.applicationDirectory;

		if (applicationDirectory != null && applicationDirectory != "")
			scanImageDirectory(found, '$applicationDirectory/assets/images/stages', "stages");

		for (asset in Assets.list())
		{
			var path = asset.split("\\").join("/");
			var prefix = "assets/images/stages/";

			if (path.indexOf(prefix) != 0 || !isImageFile(path))
				continue;

			var key = "stages/" + stripExtension(path.substr(prefix.length));
			addImageInfo(found, key, path);
		}

		var result:Array<ImageInfo> = [];

		for (info in found)
			result.push(info);

		result.sort(function(a:ImageInfo, b:ImageInfo):Int
		{
			return compareNames(a.key, b.key);
		});

		return result;
	}

	function scanImageDirectory(found:Map<String, ImageInfo>, root:String, keyPrefix:String):Void
	{
		#if sys
		scanImageDirectoryRecursive(found, root, root, keyPrefix);
		#end
	}

	#if sys
	function scanImageDirectoryRecursive(found:Map<String, ImageInfo>, root:String, directory:String, keyPrefix:String):Void
	{
		try
		{
			if (!FileSystem.exists(directory) || !FileSystem.isDirectory(directory))
				return;

			for (entry in FileSystem.readDirectory(directory))
			{
				var path = '$directory/$entry';

				if (FileSystem.isDirectory(path))
				{
					scanImageDirectoryRecursive(found, root, path, keyPrefix);
					continue;
				}

				if (!isImageFile(entry))
					continue;

				var relative = path.substr(root.length);

				while (StringTools.startsWith(relative, "/") || StringTools.startsWith(relative, "\\"))
					relative = relative.substr(1);

				var key = keyPrefix + "/" + stripExtension(relative.split("\\").join("/"));
				addImageInfo(found, key, path);
			}
		}
		catch (error:Dynamic) {}
	}
	#end

	function addImageInfo(found:Map<String, ImageInfo>, key:String, path:String):Void
	{
		key = key.split("\\").join("/");

		if (key == "" || found.exists(key.toLowerCase()))
			return;

		found.set(key.toLowerCase(), {key: key, path: path});
	}

	function loadStage(index:Int):Void
	{
		if (index < 0 || index >= stageInfos.length)
			return;

		var info = stageInfos[index];
		destroyLayerSprites();
		layers = [];
		stageIndex = index;
		stageName = info.name;
		stageDisplayName = info.name;
		stageSource = info.path;
		target = TARGET_LAYER;
		selectedLayer = -1;
		layerOffset = 0;
		dirty = false;
		exitArmed = false;
		setDefaultMarkerPositions();

		var text = readTextAt(info.path);
		var loaded = false;

		if (text != null)
		{
			try
			{
				var data:Dynamic = haxe.Json.parse(stripBom(text));

				if (data != null && Reflect.isObject(data))
				{
					stageDisplayName = stringValue(Reflect.field(data, "name"), info.name);
					var rawLayers:Dynamic = Reflect.field(data, "layers");

					if (Std.isOfType(rawLayers, Array))
					{
						for (entry in cast(rawLayers, Array<Dynamic>))
						{
							var layer = parseLayer(entry);

							if (layer != null)
								layers.push(layer);
						}
					}

					setMarkerPosition(0, pointValue(Reflect.field(data, "dadPosition"), FlxG.width * 0.28, defaultCharacterY()));
					setMarkerPosition(1, pointValue(Reflect.field(data, "bfPosition"), FlxG.width * 0.72, defaultCharacterY()));
					setMarkerPosition(2, pointValue(Reflect.field(data, "gfPosition"), FlxG.width * 0.5, defaultCharacterY()));
					loaded = true;
				}
			}
			catch (error:Dynamic)
			{
				setStatus('INVALID STAGE JSON: ${Std.string(error)}', 0xFFFF4455);
			}
		}

		buildLayerSprites();

		if (layers.length > 0)
		{
			selectedLayer = 0;
			layerOffset = 0;
		}

		refreshAll();

		if (!loaded)
			setStatus('COULD NOT LOAD ${info.path}', 0xFFFF4455);
		else
			setStatus('LOADED ${info.path}', 0xFF66FF88);
	}

	function createNewStage():Void
	{
		destroyLayerSprites();
		layers = [];
		stageIndex = -1;
		stageName = uniqueStageName("untitled");
		stageDisplayName = "Untitled";
		stageSource = null;
		target = TARGET_LAYER;
		selectedLayer = -1;
		layerOffset = 0;
		dirty = false;
		exitArmed = false;
		setDefaultMarkerPositions();
		refreshAll();
		setStatus("NEW STAGE - ADD A LAYER OR PRESS SPACE TO SAVE", 0xFF66FF88);
	}

	function requestNewStage():Void
	{
		if (dirty && !exitArmed)
		{
			exitArmed = true;
			setStatus("UNSAVED CHANGES - PRESS F7 AGAIN TO DISCARD", 0xFFFFAA33);
			return;
		}

		createNewStage();
	}

	function cycleStage(delta:Int):Void
	{
		if (stageInfos.length == 0)
		{
			setStatus("NO STAGE FILES FOUND", 0xFFFFCC55);
			return;
		}

		if (dirty && !exitArmed)
		{
			exitArmed = true;
			setStatus("UNSAVED CHANGES - PRESS F5/F6 AGAIN TO DISCARD", 0xFFFFAA33);
			return;
		}

		var index:Int;

		if (stageIndex < 0)
			index = delta > 0 ? 0 : stageInfos.length - 1;
		else
			index = (stageIndex + delta + stageInfos.length) % stageInfos.length;

		loadStage(index);
	}

	function buildLayerSprites():Void
	{
		var missing = 0;

		for (layer in layers)
		{
			var sprite = createLayerSprite(layer);

			if (sprite == null)
			{
				missing++;
				continue;
			}

			layer.sprite = sprite;
			stageGroup.add(sprite);
		}

		if (missing > 0)
			setStatus('$missing LAYER IMAGE(S) NOT FOUND', 0xFFFFAA33);
	}

	function createLayerSprite(layer:EditorLayer):FlxSprite
	{
		var sprite:FlxSprite = null;

		if (layer.type == "image")
		{
			var bitmap = loadLayerBitmap(layer.image);

			if (bitmap == null)
				return null;

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

		sprite.antialiasing = false;
		sprite.immovable = true;
		applyLayerTransform(layer, sprite);
		return sprite;
	}

	function applyLayerTransform(layer:EditorLayer, ?sprite:FlxSprite):Void
	{
		var targetSprite = sprite == null ? layer.sprite : sprite;

		if (targetSprite == null)
			return;

		targetSprite.x = layer.x;
		targetSprite.y = layer.y;
		targetSprite.scale.set(layer.scale, layer.scale);
		targetSprite.scrollFactor.set(layer.scrollX, layer.scrollY);
		targetSprite.alpha = layer.alpha;
	}

	function destroyLayerSprites():Void
	{
		if (stageGroup == null)
			return;

		for (member in stageGroup.members)
		{
			if (member != null)
				member.destroy();
		}

		stageGroup.clear();
	}

	function refreshAll():Void
	{
		refreshHeader();
		refreshLayerList();
		refreshLayerDetails();
		refreshImageList();
		refreshImageDetails();
		refreshMarkers();
		refreshOutline();
		refreshBottom();
	}

	function refreshHeader():Void
	{
		var indexText = stageIndex < 0 ? "NEW" : '${stageIndex + 1}/${stageInfos.length}';
		stageText.text = 'STAGE $indexText: ${stageDisplayName}    FILE: ${stageName}.json    TARGET: ${targetLabel()}';
	}

	function refreshLayerList():Void
	{
		ensureLayerVisible();

		for (i in 0...LAYER_ROWS)
		{
			var index = layerOffset + i;
			var text = layerTexts[i];

			if (index >= layers.length)
			{
				text.text = "";
				continue;
			}

			var layer = layers[index];
			var selected = index == selectedLayer && target == TARGET_LAYER;
			text.text = (selected ? "> " : "  ") + (index + 1) + ". " + shorten(layer.name, 22) + "  [" + layer.type.toUpperCase() + "]";
			text.color = selected ? FlxColor.WHITE : (layer.sprite == null ? 0xFFFF7788 : 0xFF9AA2B8);
		}

		var visible = selectedLayer >= layerOffset && selectedLayer < layerOffset + LAYER_ROWS;

		if (visible)
		{
			layerSelectionBar.y = LAYER_LIST_Y + (selectedLayer - layerOffset) * LAYER_ROW_HEIGHT - 1;
			layerSelectionBar.visible = true;
		}
		else
		{
			layerSelectionBar.visible = false;
		}
	}

	function refreshLayerDetails():Void
	{
		var layer = currentLayer();

		if (layer == null)
		{
			layerDetailsText.text = "NO LAYERS\n\nADD AN IMAGE FROM THE LIBRARY ON THE RIGHT.";
			return;
		}

		var lines:Array<String> = [];
		lines.push('NAME: ${layer.name}');
		lines.push('TYPE: ${layer.type.toUpperCase()}');

		if (layer.type == "image")
			lines.push('IMAGE: ${layer.image}');
		else
			lines.push('SIZE: ${layer.width} x ${layer.height}');

		lines.push('POSITION: X ${formatNumber(layer.x)}    Y ${formatNumber(layer.y)}');
		lines.push('SCALE: ${formatNumber(layer.scale)}    ALPHA: ${formatNumber(layer.alpha)}');
		lines.push('SCROLL: ${formatNumber(layer.scrollX)} / ${formatNumber(layer.scrollY)}');

		layerDetailsText.text = lines.join("\n");
	}

	function refreshImageList():Void
	{
		ensureImageVisible();

		for (i in 0...IMAGE_ROWS)
		{
			var index = imageOffset + i;
			var text = imageTexts[i];

			if (index >= imageInfos.length)
			{
				text.text = "";
				continue;
			}

			var info = imageInfos[index];
			var selected = index == selectedImage;
			text.text = (selected ? "> " : "  ") + shorten(info.key, 38);
			text.color = selected ? FlxColor.WHITE : 0xFF9AA2B8;
		}

		var visible = selectedImage >= imageOffset && selectedImage < imageOffset + IMAGE_ROWS;

		if (visible)
		{
			imageSelectionBar.y = IMAGE_LIST_Y + (selectedImage - imageOffset) * IMAGE_ROW_HEIGHT - 1;
			imageSelectionBar.visible = true;
		}
		else
		{
			imageSelectionBar.visible = false;
		}
	}

	function refreshImageDetails():Void
	{
		if (imageInfos.length == 0)
		{
			imageDetailsText.text = "NO STAGE IMAGES FOUND\n\nEXPECTED IN images/stages/";
			return;
		}

		var info = imageInfos[selectedImage];
		imageDetailsText.text = 'SELECTED:\n${info.key}\n\n${shorten(info.path, 46)}';
	}

	function refreshMarkers():Void
	{
		for (i in 0...markers.length)
		{
			var marker = markers[i];
			var selected = target == i + 1;
			marker.body.x = marker.x - marker.width * 0.5;
			marker.body.y = marker.y;
			marker.body.alpha = selected ? 0.28 : 0.11;
			marker.cross.x = marker.x - 16;
			marker.cross.y = marker.y - 16;
			marker.cross.alpha = selected ? 1 : 0.65;
			marker.label.x = marker.x - 90;
			marker.label.y = marker.y - 30;
			marker.label.text = '${i + 1} ${marker.name}';
			marker.label.color = selected ? FlxColor.WHITE : marker.color;
		}
	}

	function refreshOutline():Void
	{
		var layer = target == TARGET_LAYER ? currentLayer() : null;

		if (layer == null || layer.sprite == null)
		{
			for (part in outlineParts)
				part.visible = false;

			return;
		}

		var x = layer.sprite.x;
		var y = layer.sprite.y;
		var width = layer.sprite.width * Math.abs(layer.sprite.scale.x);
		var height = layer.sprite.height * Math.abs(layer.sprite.scale.y);

		outlineParts[0].setPosition(x - 2, y - 2);
		outlineParts[0].scale.set(width + 4, 1);
		outlineParts[0].visible = true;

		outlineParts[1].setPosition(x - 2, y + height);
		outlineParts[1].scale.set(width + 4, 1);
		outlineParts[1].visible = true;

		outlineParts[2].setPosition(x - 2, y - 2);
		outlineParts[2].scale.set(1, height + 4);
		outlineParts[2].visible = true;

		outlineParts[3].setPosition(x + width, y - 2);
		outlineParts[3].scale.set(1, height + 4);
		outlineParts[3].visible = true;
	}

	function refreshBottom():Void
	{
		var layer = currentLayer();
		var marker = target > TARGET_LAYER ? markers[target - 1] : null;

		if (marker != null)
			targetText.text = 'TARGET: ${marker.name}    X ${formatNumber(marker.x)}    Y ${formatNumber(marker.y)}    ARROWS: MOVE    SHIFT+ARROWS: 10px';
		else if (layer != null)
			targetText.text = 'TARGET: LAYER ${selectedLayer + 1}/${layers.length}  ${layer.name}    X ${formatNumber(layer.x)}    Y ${formatNumber(layer.y)}    SCALE ${formatNumber(layer.scale)}    SCROLL ${formatNumber(layer.scrollX)} / ${formatNumber(layer.scrollY)}';
		else
			targetText.text = "TARGET: NO LAYER    SELECT OR ADD A LAYER";

		anchorsText.text = 'DAD ${formatNumber(markers[0].x)}, ${formatNumber(markers[0].y)}    BF ${formatNumber(markers[1].x)}, ${formatNumber(markers[1].y)}    GF ${formatNumber(markers[2].x)}, ${formatNumber(markers[2].y)}';

		var source = stageSource == null ? "NEW STAGE" : shorten(stageSource, 80);
		saveText.text = 'SAVE: ${savePath()}    SOURCE: $source';
	}

	function targetLabel():String
	{
		if (target == TARGET_LAYER)
			return currentLayer() == null ? "LAYER" : 'LAYER ${selectedLayer + 1}';

		return markers[target - 1].name;
	}

	function handleLayerInput():Void
	{
		var layer = currentLayer();

		if (layer == null)
			return;

		if (FlxG.keys.justPressed.Q || FlxG.keys.justPressed.MINUS || FlxG.keys.justPressed.NUMPADMINUS)
			adjustScale(layer, -SCALE_STEP);
		else if (FlxG.keys.justPressed.E || FlxG.keys.justPressed.PLUS || FlxG.keys.justPressed.NUMPADPLUS)
			adjustScale(layer, SCALE_STEP);

		if (FlxG.keys.pressed.SHIFT)
		{
			var changed = false;

			if (FlxG.keys.justPressed.LEFT)
			{
				layer.scrollX = clamp(layer.scrollX - SCROLL_STEP, MIN_SCROLL, MAX_SCROLL);
				changed = true;
			}
			else if (FlxG.keys.justPressed.RIGHT)
			{
				layer.scrollX = clamp(layer.scrollX + SCROLL_STEP, MIN_SCROLL, MAX_SCROLL);
				changed = true;
			}
			else if (FlxG.keys.justPressed.UP)
			{
				layer.scrollY = clamp(layer.scrollY - SCROLL_STEP, MIN_SCROLL, MAX_SCROLL);
				changed = true;
			}
			else if (FlxG.keys.justPressed.DOWN)
			{
				layer.scrollY = clamp(layer.scrollY + SCROLL_STEP, MIN_SCROLL, MAX_SCROLL);
				changed = true;
			}

			if (changed)
			{
				layer.scrollX = roundTo(layer.scrollX, 100);
				layer.scrollY = roundTo(layer.scrollY, 100);
				applyLayerTransform(layer);
				markDirty("SCROLL FACTOR UPDATED - UNSAVED");
				refreshLayerList();
				refreshLayerDetails();
				refreshBottom();
			}

			return;
		}

		var step = FlxG.keys.pressed.CONTROL ? FAST_MOVE_STEP : MOVE_STEP;
		var moved = false;

		if (FlxG.keys.justPressed.LEFT)
		{
			layer.x -= step;
			moved = true;
		}
		else if (FlxG.keys.justPressed.RIGHT)
		{
			layer.x += step;
			moved = true;
		}
		else if (FlxG.keys.justPressed.UP)
		{
			layer.y -= step;
			moved = true;
		}
		else if (FlxG.keys.justPressed.DOWN)
		{
			layer.y += step;
			moved = true;
		}

		if (moved)
		{
			applyLayerTransform(layer);
			markDirty("LAYER MOVED - UNSAVED");
			refreshLayerList();
			refreshLayerDetails();
			refreshBottom();
			refreshOutline();
		}
	}

	function handleMarkerInput():Void
	{
		var marker = markers[target - 1];
		var step = FlxG.keys.pressed.SHIFT ? FAST_MOVE_STEP : MOVE_STEP;
		var moved = false;

		if (FlxG.keys.justPressed.LEFT)
		{
			marker.x -= step;
			moved = true;
		}
		else if (FlxG.keys.justPressed.RIGHT)
		{
			marker.x += step;
			moved = true;
		}
		else if (FlxG.keys.justPressed.UP)
		{
			marker.y -= step;
			moved = true;
		}
		else if (FlxG.keys.justPressed.DOWN)
		{
			marker.y += step;
			moved = true;
		}

		if (moved)
		{
			markDirty("CHARACTER POINT MOVED - UNSAVED");
			refreshMarkers();
			refreshBottom();
		}
	}

	function adjustScale(layer:EditorLayer, delta:Float):Void
	{
		layer.scale = clamp(roundTo(layer.scale + delta, 100), MIN_SCALE, MAX_SCALE);
		applyLayerTransform(layer);
		markDirty("LAYER SCALE UPDATED - UNSAVED");
		refreshLayerList();
		refreshLayerDetails();
		refreshBottom();
		refreshOutline();
	}

	function handleMouse(mouseX:Float, mouseY:Float):Void
	{
		if (!uiHidden)
		{
			if (pointInRect(mouseX, mouseY, LEFT_PANEL_X, LEFT_PANEL_Y, LEFT_PANEL_WIDTH, LEFT_PANEL_HEIGHT))
			{
				for (i in 0...LAYER_ROWS)
				{
					var index = layerOffset + i;
					var rowY = LAYER_LIST_Y + i * LAYER_ROW_HEIGHT;

					if (index < layers.length && mouseX >= LAYER_LIST_X && mouseX <= LAYER_LIST_X + LAYER_LIST_WIDTH
						&& mouseY >= rowY && mouseY < rowY + LAYER_ROW_HEIGHT - 2)
					{
						selectLayer(index);
						return;
					}
				}

				return;
			}

			if (pointInRect(mouseX, mouseY, RIGHT_PANEL_X, LEFT_PANEL_Y, RIGHT_PANEL_WIDTH, LEFT_PANEL_HEIGHT))
			{
				for (i in 0...IMAGE_ROWS)
				{
					var index = imageOffset + i;
					var rowY = IMAGE_LIST_Y + i * IMAGE_ROW_HEIGHT;

					if (index < imageInfos.length && mouseX >= IMAGE_LIST_X && mouseX <= IMAGE_LIST_X + IMAGE_LIST_WIDTH
						&& mouseY >= rowY && mouseY < rowY + IMAGE_ROW_HEIGHT - 2)
					{
						selectImage(index);
						return;
					}
				}

				return;
			}

			if (pointInRect(mouseX, mouseY, 12, BOTTOM_PANEL_Y, FlxG.width - 24, BOTTOM_PANEL_HEIGHT))
				return;
		}

		for (i in 0...markers.length)
		{
			var marker = markers[i];
			var left = marker.x - marker.width * 0.5;
			var top = marker.y;

			if (mouseX >= left && mouseX <= left + marker.width && mouseY >= top && mouseY <= top + marker.height)
			{
				selectTarget(i + 1);
				return;
			}
		}
	}

	function selectLayer(index:Int):Void
	{
		if (index < 0 || index >= layers.length)
			return;

		selectedLayer = index;
		target = TARGET_LAYER;
		refreshAll();
	}

	function cycleLayer(delta:Int):Void
	{
		if (layers.length == 0)
		{
			setStatus("NO LAYERS TO SELECT - ADD AN IMAGE", 0xFFFFCC55);
			return;
		}

		if (selectedLayer < 0)
			selectedLayer = 0;
		else
			selectedLayer = (selectedLayer + delta + layers.length) % layers.length;

		target = TARGET_LAYER;
		refreshAll();
	}

	function selectTarget(index:Int):Void
	{
		target = index;
		refreshAll();
	}

	function selectImage(index:Int):Void
	{
		if (index < 0 || index >= imageInfos.length)
			return;

		selectedImage = index;
		refreshImageList();
		refreshImageDetails();
	}

	function cycleImage(delta:Int):Void
	{
		if (imageInfos.length == 0)
		{
			setStatus("NO STAGE IMAGES FOUND", 0xFFFFCC55);
			return;
		}

		selectedImage = (selectedImage + delta + imageInfos.length) % imageInfos.length;
		ensureImageVisible();
		refreshImageList();
		refreshImageDetails();
	}

	function addSelectedImage():Void
	{
		if (imageInfos.length == 0)
		{
			setStatus("NO STAGE IMAGES FOUND", 0xFFFF4455);
			return;
		}

		var info = imageInfos[selectedImage];
		var bitmap = loadLayerBitmap(info.key);

		if (bitmap == null)
		{
			setStatus('COULD NOT LOAD IMAGE: ${info.key}', 0xFFFF4455);
			return;
		}

		var x = (FlxG.width - bitmap.width) * 0.5;
		var y = (FlxG.height - bitmap.height) * 0.5;
		var baseName = fileName(info.key);
		var name = baseName;
		var suffix = 2;

		while (layerNameExists(name))
		{
			name = '$baseName $suffix';
			suffix++;
		}

		var layer:EditorLayer = {
			type: "image",
			name: name,
			image: info.key,
			color: 0xFFFFFFFF,
			x: x,
			y: y,
			width: bitmap.width,
			height: bitmap.height,
			scale: 1,
			alpha: 1,
			scrollX: 1,
			scrollY: 1,
			lineSpacing: 96,
			sprite: null
		};

		var sprite = new FlxSprite(layer.x, layer.y);
		sprite.loadGraphic(bitmap);
		sprite.antialiasing = false;
		sprite.immovable = true;
		applyLayerTransform(layer, sprite);
		layer.sprite = sprite;
		stageGroup.add(sprite);
		layers.push(layer);
		selectedLayer = layers.length - 1;
		layerOffset = Std.int(Math.max(0, selectedLayer - LAYER_ROWS + 1));
		target = TARGET_LAYER;
		markDirty('ADDED ${info.key} - UNSAVED');
		refreshAll();
	}

	function deleteSelectedLayer():Void
	{
		if (target != TARGET_LAYER || selectedLayer < 0 || selectedLayer >= layers.length)
			return;

		var layer = layers[selectedLayer];

		if (layer.sprite != null)
		{
			stageGroup.remove(layer.sprite, true);
			layer.sprite.destroy();
			layer.sprite = null;
		}

		layers.splice(selectedLayer, 1);

		if (layers.length == 0)
			selectedLayer = -1;
		else if (selectedLayer >= layers.length)
			selectedLayer = layers.length - 1;

		markDirty("LAYER REMOVED - UNSAVED");
		refreshAll();
	}

	function moveLayerOrder(delta:Int):Void
	{
		if (target != TARGET_LAYER || selectedLayer < 0 || selectedLayer >= layers.length)
			return;

		var other = selectedLayer + delta;

		if (other < 0 || other >= layers.length)
			return;

		var layer = layers[selectedLayer];
		layers[selectedLayer] = layers[other];
		layers[other] = layer;
		selectedLayer = other;
		rebuildStageOrder();
		markDirty("LAYER ORDER UPDATED - UNSAVED");
		refreshAll();
	}

	function rebuildStageOrder():Void
	{
		stageGroup.clear();

		for (layer in layers)
		{
			if (layer.sprite != null)
				stageGroup.add(layer.sprite);
		}
	}

	function ensureLayerVisible():Void
	{
		if (selectedLayer < 0)
		{
			layerOffset = 0;
			return;
		}

		if (selectedLayer < layerOffset)
			layerOffset = selectedLayer;
		else if (selectedLayer >= layerOffset + LAYER_ROWS)
			layerOffset = selectedLayer - LAYER_ROWS + 1;

		var maxOffset = Std.int(Math.max(0, layers.length - LAYER_ROWS));
		layerOffset = Std.int(Math.max(0, Math.min(layerOffset, maxOffset)));
	}

	function ensureImageVisible():Void
	{
		if (selectedImage < imageOffset)
			imageOffset = selectedImage;
		else if (selectedImage >= imageOffset + IMAGE_ROWS)
			imageOffset = selectedImage - IMAGE_ROWS + 1;

		var maxOffset = Std.int(Math.max(0, imageInfos.length - IMAGE_ROWS));
		imageOffset = Std.int(Math.max(0, Math.min(imageOffset, maxOffset)));
	}

	function setDefaultMarkerPositions():Void
	{
		setMarkerPosition(0, newMarkerPoint(FlxG.width * 0.28, defaultCharacterY()));
		setMarkerPosition(1, newMarkerPoint(FlxG.width * 0.72, defaultCharacterY()));
		setMarkerPosition(2, newMarkerPoint(FlxG.width * 0.5, defaultCharacterY()));
	}

	function setMarkerPosition(index:Int, point:Dynamic):Void
	{
		if (index < 0 || index >= markers.length || point == null)
			return;

		markers[index].x = point.x;
		markers[index].y = point.y;
	}

	function newMarkerPoint(x:Float, y:Float):Dynamic
	{
		return {x: x, y: y};
	}

	function saveStage():Void
	{
		#if sys
		var path = savePath();
		var json = buildStageJson();

		try
		{
			var directory = haxe.io.Path.directory(path);

			if (directory != null && directory != "" && !FileSystem.exists(directory))
				FileSystem.createDirectory(directory);

			File.saveContent(path, json);
			dirty = false;
			exitArmed = false;
			stageSource = path;
			stageName = sanitizeStageName(stageName);
			stageInfos = discoverStages();
			stageIndex = findStageIndex(stageName);
			refreshAll();
			setStatus('SAVED $path', 0xFF66FF88);
		}
		catch (error:Dynamic)
		{
			setStatus('SAVE ERROR: ${Std.string(error)}', 0xFFFF4455);
		}
		#else
		setStatus("SAVE IS NOT AVAILABLE ON THIS TARGET", 0xFFFF4455);
		#end
	}

	function buildStageJson():String
	{
		var layerData:Array<Dynamic> = [];

		for (layer in layers)
		{
			var data:Dynamic = {
				name: layer.name,
				type: layer.type,
				x: cleanNumber(layer.x),
				y: cleanNumber(layer.y),
				scale: cleanNumber(layer.scale),
				alpha: cleanNumber(layer.alpha),
				scrollFactor: [cleanNumber(layer.scrollX), cleanNumber(layer.scrollY)]
			};

			if (layer.type == "image")
			{
				Reflect.setField(data, "image", layer.image);
			}
			else
			{
				Reflect.setField(data, "width", layer.width);
				Reflect.setField(data, "height", layer.height);
				Reflect.setField(data, "color", layer.color);

				if (layer.type == "grid")
					Reflect.setField(data, "lineSpacing", layer.lineSpacing);
			}

			layerData.push(data);
		}

		var root:Dynamic = {
			name: stageDisplayName == "" ? stageName : stageDisplayName,
			layers: layerData,
			dadPosition: [cleanNumber(markers[0].x), cleanNumber(markers[0].y)],
			bfPosition: [cleanNumber(markers[1].x), cleanNumber(markers[1].y)],
			gfPosition: [cleanNumber(markers[2].x), cleanNumber(markers[2].y)]
		};

		return haxe.Json.stringify(root, null, "\t") + "\n";
	}

	function savePath():String
	{
		return '$SAVE_ROOT${sanitizeStageName(stageName)}.json';
	}

	function findStageIndex(name:String):Int
	{
		for (i in 0...stageInfos.length)
		{
			if (stageInfos[i].name.toLowerCase() == name.toLowerCase())
				return i;
		}

		return -1;
	}

	function layerNameExists(name:String):Bool
	{
		for (layer in layers)
		{
			if (layer.name.toLowerCase() == name.toLowerCase())
				return true;
		}

		return false;
	}

	function uniqueStageName(base:String):String
	{
		var name = base;
		var suffix = 2;

		while (stageNameExists(name))
		{
			name = '$base-$suffix';
			suffix++;
		}

		return name;
	}

	function stageNameExists(name:String):Bool
	{
		for (info in stageInfos)
		{
			if (info.name.toLowerCase() == name.toLowerCase())
				return true;
		}

		#if sys
		return FileSystem.exists(savePathFor(name));
		#else
		return false;
		#end
	}

	function savePathFor(name:String):String
	{
		return '$SAVE_ROOT${sanitizeStageName(name)}.json';
	}

	function currentLayer():EditorLayer
	{
		return selectedLayer >= 0 && selectedLayer < layers.length ? layers[selectedLayer] : null;
	}

	function markDirty(message:String):Void
	{
		dirty = true;
		exitArmed = false;
		setStatus(message + " - SPACE TO SAVE", 0xFFFFAA33);
	}

	function setStatus(message:String, color:Int):Void
	{
		if (statusText == null)
			return;

		statusText.text = message;
		statusText.color = color;
	}

	function parseLayer(entry:Dynamic):EditorLayer
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
			lineSpacing: intValue(Reflect.field(entry, "lineSpacing"), 96),
			sprite: null
		};
	}

	static function scrollFactorValue(data:Dynamic):Dynamic
	{
		var raw:Dynamic = Reflect.field(data, "scrollFactor");

		if (raw != null)
		{
			if (Std.isOfType(raw, Array))
			{
				var values:Array<Dynamic> = cast raw;
				return {
					x: values.length > 0 ? numberValue(values[0], 1) : 1,
					y: values.length > 1 ? numberValue(values[1], 1) : 1
				};
			}

			if (Reflect.isObject(raw))
				return {
					x: numberValue(Reflect.field(raw, "x"), 1),
					y: numberValue(Reflect.field(raw, "y"), 1)
				};

			var scalar = numberValue(raw, 1);
			return {x: scalar, y: scalar};
		}

		return {
			x: numberValue(Reflect.field(data, "scrollX"), 1),
			y: numberValue(Reflect.field(data, "scrollY"), 1)
		};
	}

	static function pointValue(value:Dynamic, fallbackX:Float, fallbackY:Float):Dynamic
	{
		if (value == null)
			return {x: fallbackX, y: fallbackY};

		if (Std.isOfType(value, Array))
		{
			var values:Array<Dynamic> = cast value;
			return {
				x: values.length > 0 ? numberValue(values[0], fallbackX) : fallbackX,
				y: values.length > 1 ? numberValue(values[1], fallbackY) : fallbackY
			};
		}

		if (Reflect.isObject(value))
			return {
				x: numberValue(Reflect.field(value, "x"), fallbackX),
				y: numberValue(Reflect.field(value, "y"), fallbackY)
			};

		return {x: fallbackX, y: fallbackY};
	}

	function loadLayerBitmap(image:String):BitmapData
	{
		for (candidate in imageCandidates(image))
		{
			var bitmap = loadBitmapAt(candidate);

			if (bitmap != null)
				return bitmap;
		}

		return null;
	}

	static function imageCandidates(image:String):Array<String>
	{
		var candidates:Array<String> = [];
		var path = image == null ? "" : StringTools.trim(image);

		if (path == "")
			return candidates;

		path = path.split("\\").join("/");

		while (StringTools.startsWith(path, "/"))
			path = path.substr(1);

		if (StringTools.startsWith(path, "assets/images/"))
			path = path.substr("assets/images/".length);
		else if (StringTools.startsWith(path, "images/"))
			path = path.substr("images/".length);

		addImagePath(candidates, '$IMAGE_ROOT$path');

		var applicationDirectory = lime.system.System.applicationDirectory;

		if (applicationDirectory != null && applicationDirectory != "")
			addImagePath(candidates, '$applicationDirectory/assets/images/$path');

		ModManager.load();

		for (mod in ModManager.mods)
		{
			if (!ModManager.isActive(mod.id))
				continue;

			addImagePath(candidates, 'mods/${mod.folder}/images/$path');
			addImagePath(candidates, '${mod.path}/images/$path');
		}

		return candidates;
	}

	static function addImagePath(candidates:Array<String>, path:String):Void
	{
		if (path == null || path == "" || candidates.indexOf(path) >= 0)
			return;

		candidates.push(path);

		var lower = path.toLowerCase();

		if (!StringTools.endsWith(lower, ".png") && !StringTools.endsWith(lower, ".jpg") && !StringTools.endsWith(lower, ".jpeg")
			&& !StringTools.endsWith(lower, ".webp"))
			candidates.push('$path.png');
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

	static function defaultCharacterY():Float
	{
		return FlxG.height * 0.13;
	}

	static function pointInRect(px:Float, py:Float, x:Float, y:Float, width:Float, height:Float):Bool
	{
		return px >= x && px <= x + width && py >= y && py <= y + height;
	}

	static function clamp(value:Float, min:Float, max:Float):Float
	{
		return Math.max(min, Math.min(max, value));
	}

	static function roundTo(value:Float, factor:Float):Float
	{
		return Math.round(value * factor) / factor;
	}

	static function cleanNumber(value:Float):Float
	{
		var rounded = Math.round(value * 1000) / 1000;
		return rounded == 0 ? 0 : rounded;
	}

	static function formatNumber(value:Float):String
	{
		if (Math.abs(value - Math.round(value)) < 0.0001)
			return Std.string(Math.round(value));

		return Std.string(Math.round(value * 100) / 100);
	}

	static function shorten(value:String, maxLength:Int):String
	{
		if (value == null)
			return "";

		return value.length <= maxLength ? value : value.substr(0, maxLength - 3) + "...";
	}

	static function sanitizeStageName(value:String):String
	{
		var name = StringTools.trim(value);

		if (StringTools.endsWith(name.toLowerCase(), ".json"))
			name = name.substr(0, name.length - 5);

		name = name.split("\\").join("-").split("/").join("-");
		name = name.split("..").join("_");

		var invalid = new EReg('[<>:"|?*]', "g");
		name = invalid.replace(name, "_");
		name = StringTools.trim(name);
		return name == "" ? "untitled" : name;
	}

	static function isImageFile(path:String):Bool
	{
		var lower = path.toLowerCase();
		return StringTools.endsWith(lower, ".png") || StringTools.endsWith(lower, ".jpg") || StringTools.endsWith(lower, ".jpeg")
			|| StringTools.endsWith(lower, ".webp");
	}

	static function stripExtension(file:String):String
	{
		var dot = file.lastIndexOf(".");

		return dot < 0 ? file : file.substr(0, dot);
	}

	static function stripBom(text:String):String
	{
		if (text != null && text.length > 0 && text.charCodeAt(0) == 0xFEFF)
			return text.substr(1);

		return text;
	}

	static function fileName(path:String):String
	{
		var normalized = path == null ? "" : path.split("\\").join("/");
		var slash = normalized.lastIndexOf("/");
		return slash < 0 ? normalized : normalized.substr(slash + 1);
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
