package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;
import graphics.BrokenCharacter;
import graphics.SparrowLoader;
import openfl.display.BitmapData;
import openfl.utils.Assets;
import openfl.utils.ByteArray;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

private typedef CharacterEntry =
{
	var name:String;
	var dataAsset:String;
	var dataFile:String;
	var imageAsset:String;
	var imageFile:String;
	var xmlAsset:String;
	var xmlFile:String;
}

private typedef CharacterConfig =
{
	var root:Xml;
	var doctype:String;
	var source:String;
	var error:String;
}

private typedef AnimationInfo =
{
	var name:String;
	var prefix:String;
	var fps:Float;
	var looped:Bool;
	var offsetX:Float;
	var offsetY:Float;
	var available:Bool;
}

class CharacterEditorState extends FlxState
{
	static inline var DATA_ROOT:String = "assets/data/characters/";
	static inline var IMAGE_ROOT:String = "assets/images/characters/";
	static inline var PREVIEW_SCALE:Float = 0.7;
	static inline var CENTER_X:Float = 640;
	static inline var FLOOR_Y:Float = 600;
	static inline var CHARACTER_LIST_X:Float = 24;
	static inline var CHARACTER_LIST_Y:Float = 126;
	static inline var CHARACTER_ROW_HEIGHT:Float = 26;
	static inline var CHARACTER_LIST_WIDTH:Float = 300;
	static inline var CHARACTER_ROWS:Int = 11;
	static inline var ANIMATION_LIST_X:Float = 956;
	static inline var ANIMATION_LIST_Y:Float = 130;
	static inline var ANIMATION_ROW_HEIGHT:Float = 38;
	static inline var ANIMATION_LIST_WIDTH:Float = 292;
	static inline var MAX_OFFSET:Float = 2000;

	static var ANIMATION_NAMES:Array<String> = ["idle", "singLEFT", "singDOWN", "singUP", "singRIGHT"];
	static var ANIMATION_SUFFIXES:Array<String> = [" idle", " left", " down", " up", " right"];

	var characterEntries:Array<CharacterEntry> = [];
	var animations:Array<AnimationInfo> = [];
	var selectedCharacter:Int = 0;
	var selectedAnimation:Int = 0;
	var characterOffset:Int = 0;
	var preview:FlxSprite;
	var previewFrames:FlxAtlasFrames;
	var previewBaseOffsetX:Float = 0;
	var previewBaseOffsetY:Float = 0;
	var previewUsesPlaceholder:Bool = false;
	var currentConfig:CharacterConfig;
	var dirty:Bool = false;
	var exitArmed:Bool = false;
	var subtitleText:FlxText;
	var infoText:FlxText;
	var statusText:FlxText;
	var characterTexts:Array<FlxText> = [];
	var animationTexts:Array<FlxText> = [];
	var animationOffsetTexts:Array<FlxText> = [];

	override public function create():Void
	{
		super.create();

		bgColor = 0xFF0D1018;
		characterEntries = discoverCharacters();
		buildGuide();
		buildUi();
		selectCharacter(0);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (FlxG.mouse.justPressed)
			handleMouseClick(FlxG.mouse.x, FlxG.mouse.y);

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

		if (FlxG.keys.justPressed.TAB)
		{
			selectCharacter(selectedCharacter + (FlxG.keys.pressed.SHIFT ? -1 : 1));
			return;
		}

		if (FlxG.keys.justPressed.Q)
			selectAnimation(selectedAnimation - 1);
		else if (FlxG.keys.justPressed.E)
			selectAnimation(selectedAnimation + 1);
		else if (FlxG.keys.justPressed.ONE)
			selectAnimation(0);
		else if (FlxG.keys.justPressed.TWO)
			selectAnimation(1);
		else if (FlxG.keys.justPressed.THREE)
			selectAnimation(2);
		else if (FlxG.keys.justPressed.FOUR)
			selectAnimation(3);
		else if (FlxG.keys.justPressed.FIVE)
			selectAnimation(4);

		var step = FlxG.keys.pressed.SHIFT ? 10.0 : 1.0;

		if (FlxG.keys.justPressed.LEFT)
			adjustOffset(-step, 0);
		else if (FlxG.keys.justPressed.RIGHT)
			adjustOffset(step, 0);
		else if (FlxG.keys.justPressed.UP)
			adjustOffset(0, -step);
		else if (FlxG.keys.justPressed.DOWN)
			adjustOffset(0, step);

		if (FlxG.keys.justPressed.R)
			resetOffset();

		if (FlxG.keys.justPressed.SPACE || (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S))
			saveConfig();
	}

	function buildGuide():Void
	{
		var vertical = new FlxSprite(CENTER_X - 1, 80);
		vertical.makeGraphic(2, 520, 0xFF3B2F55);
		add(vertical);

		var horizontal = new FlxSprite(CENTER_X - 300, FLOOR_Y - 1);
		horizontal.makeGraphic(600, 2, 0xFF3B2F55);
		add(horizontal);

		var originLabel = new FlxText(CENTER_X + 10, 84, 120, "ORIGIN", 12);
		originLabel.color = 0xFF7777AA;
		add(originLabel);

		var floorLabel = new FlxText(CENTER_X + 10, FLOOR_Y - 20, 120, "FLOOR", 12);
		floorLabel.color = 0xFF7777AA;
		add(floorLabel);
	}

	function buildUi():Void
	{
		var title = new FlxText(0, 16, FlxG.width, "CHARACTER EDITOR", 30);
		title.alignment = FlxTextAlign.CENTER;
		title.color = FlxColor.WHITE;
		add(title);

		subtitleText = new FlxText(0, 54, FlxG.width, "", 16);
		subtitleText.alignment = FlxTextAlign.CENTER;
		subtitleText.color = 0xFFAAAAAA;
		add(subtitleText);

		var characterHeader = new FlxText(CHARACTER_LIST_X, 96, CHARACTER_LIST_WIDTH, "CHARACTERS", 18);
		characterHeader.color = 0xFF7777AA;
		add(characterHeader);

		for (i in 0...CHARACTER_ROWS)
		{
			var row = new FlxText(CHARACTER_LIST_X, CHARACTER_LIST_Y + i * CHARACTER_ROW_HEIGHT, CHARACTER_LIST_WIDTH, "", 18);
			row.color = 0xFF8888AA;
			add(row);
			characterTexts.push(row);
		}

		var animationHeader = new FlxText(ANIMATION_LIST_X, 96, ANIMATION_LIST_WIDTH, "ANIMATIONS", 18);
		animationHeader.color = 0xFF7777AA;
		add(animationHeader);

		for (i in 0...ANIMATION_NAMES.length)
		{
			var nameText = new FlxText(ANIMATION_LIST_X, ANIMATION_LIST_Y + i * ANIMATION_ROW_HEIGHT, 132, "", 18);
			nameText.color = 0xFF8888AA;
			add(nameText);
			animationTexts.push(nameText);

			var offsetText = new FlxText(ANIMATION_LIST_X + 136, ANIMATION_LIST_Y + i * ANIMATION_ROW_HEIGHT + 2, 156, "", 16);
			offsetText.color = 0xFF8888AA;
			add(offsetText);
			animationOffsetTexts.push(offsetText);
		}

		infoText = new FlxText(ANIMATION_LIST_X, 326, ANIMATION_LIST_WIDTH, "", 14);
		infoText.color = 0xFF8888AA;
		infoText.wordWrap = true;
		add(infoText);

		statusText = new FlxText(0, 636, FlxG.width, "", 14);
		statusText.alignment = FlxTextAlign.CENTER;
		statusText.color = 0xFF66FF88;
		add(statusText);

		var hint = new FlxText(0, 660, FlxG.width,
			"TAB / SHIFT+TAB: CHARACTER    Q / E: ANIMATION    1-5: SELECT    ARROWS: OFFSET    SHIFT: 10px", 14);
		hint.alignment = FlxTextAlign.CENTER;
		hint.color = 0xFF666688;
		add(hint);

		var saveHint = new FlxText(0, 684, FlxG.width, "SPACE / CTRL+S: SAVE XML    R: RESET OFFSET    ESC: BACK", 14);
		saveHint.alignment = FlxTextAlign.CENTER;
		saveHint.color = 0xFF666688;
		add(saveHint);
	}

	function handleMouseClick(mouseX:Float, mouseY:Float):Void
	{
		for (i in 0...CHARACTER_ROWS)
		{
			var index = characterOffset + i;

			if (index >= characterEntries.length)
				break;

			var rowY = CHARACTER_LIST_Y + i * CHARACTER_ROW_HEIGHT;

			if (mouseX >= CHARACTER_LIST_X && mouseX <= CHARACTER_LIST_X + CHARACTER_LIST_WIDTH && mouseY >= rowY && mouseY < rowY + 22)
			{
				selectCharacter(index);
				return;
			}
		}

		for (i in 0...ANIMATION_NAMES.length)
		{
			var rowY = ANIMATION_LIST_Y + i * ANIMATION_ROW_HEIGHT;

			if (mouseX >= ANIMATION_LIST_X && mouseX <= ANIMATION_LIST_X + ANIMATION_LIST_WIDTH && mouseY >= rowY && mouseY < rowY + 32)
			{
				selectAnimation(i);
				return;
			}
		}
	}

	function selectCharacter(index:Int):Void
	{
		if (characterEntries.length == 0)
			return;

		selectedCharacter = (index + characterEntries.length) % characterEntries.length;
		selectedAnimation = 0;
		ensureCharacterVisible();
		loadSelectedCharacter();
		refreshAll();
	}

	function ensureCharacterVisible():Void
	{
		if (selectedCharacter < characterOffset)
			characterOffset = selectedCharacter;
		else if (selectedCharacter >= characterOffset + CHARACTER_ROWS)
			characterOffset = selectedCharacter - CHARACTER_ROWS + 1;

		var maxOffset = Std.int(Math.max(0, characterEntries.length - CHARACTER_ROWS));
		characterOffset = Std.int(Math.max(0, Math.min(characterOffset, maxOffset)));
	}

	function loadSelectedCharacter():Void
	{
		var entry = currentEntry();

		destroyPreview();
		currentConfig = entry == null ? null : loadConfig(entry);
		animations = buildAnimationData(entry, currentConfig);
		previewUsesPlaceholder = false;
		previewBaseOffsetX = 0;
		previewBaseOffsetY = 0;
		previewFrames = null;
		dirty = false;
		exitArmed = false;

		var brokenEntry = entry == null || isBrokenEntry(entry);
		var fallbackReason:String = null;
		var frames:FlxAtlasFrames = null;

		if (!brokenEntry)
		{
			if (currentConfig == null)
				fallbackReason = "MISSING CONFIG";
			else if (currentConfig.error != null || currentConfig.root == null || currentConfig.root.nodeName != "character")
				fallbackReason = "INVALID CONFIG";
			else
			{
				frames = loadFrames(entry);

				if (frames == null)
					fallbackReason = "MISSING OR INVALID ATLAS";
				else if (!hasPrefix(frames, animations[0].prefix))
					fallbackReason = "MISSING IDLE ANIMATION";
			}
		}

		if (brokenEntry || fallbackReason != null)
			createPlaceholderPreview();
		else
			createSpritePreview(entry, frames);

		playSelectedAnimation();

		if (brokenEntry)
			setStatus("BROKEN DEFAULT CHARACTER", 0xFF88AAFF);
		else if (fallbackReason != null)
			setStatus('BROKEN FALLBACK: $fallbackReason', 0xFFFFCC55);
		else
			setStatus("READY - ADJUST OFFSETS WITH ARROWS", 0xFF66FF88);
	}

	function createSpritePreview(entry:CharacterEntry, frames:FlxAtlasFrames):Void
	{
		preview = new FlxSprite();
		preview.frames = frames;
		preview.scale.set(PREVIEW_SCALE, PREVIEW_SCALE);
		preview.antialiasing = true;

		if (currentConfig != null && currentConfig.root != null)
		{
			var rawAntialiasing = currentConfig.root.get("antialiasing");
			var rawFlipX = currentConfig.root.get("flipX");

			if (rawAntialiasing == "false")
				preview.antialiasing = false;

			preview.flipX = rawFlipX == "true";
		}

		preview.updateHitbox();
		previewBaseOffsetX = preview.offset.x;
		previewBaseOffsetY = preview.offset.y;
		previewFrames = frames;

		for (info in animations)
		{
			info.available = hasPrefix(frames, info.prefix);

			if (info.available)
				preview.animation.addByPrefix(info.name, info.prefix, info.fps, info.looped);
		}

		preview.x = CENTER_X - preview.width * 0.5;
		preview.y = FLOOR_Y - preview.height;
		insert(0, preview);
	}

	function createPlaceholderPreview():Void
	{
		preview = new FlxSprite();
		BrokenCharacter.apply(preview);
		preview.x = CENTER_X - preview.width * 0.5;
		preview.y = FLOOR_Y - preview.height;
		previewUsesPlaceholder = true;

		for (info in animations)
			info.available = false;

		insert(0, preview);
	}

	function destroyPreview():Void
	{
		if (preview == null)
			return;

		remove(preview, true);
		preview.destroy();
		preview = null;
	}

	function playSelectedAnimation():Void
	{
		if (preview == null || animations.length == 0)
			return;

		var info = animations[selectedAnimation];

		if (!previewUsesPlaceholder && info.available)
		{
			preview.animation.play(info.name, true);
			applyPreviewOffset();
			return;
		}

		if (!previewUsesPlaceholder)
		{
			for (fallback in animations)
			{
				if (fallback.available)
				{
					preview.animation.play(fallback.name, true);
					break;
				}
			}
		}

		applyPreviewOffset();
	}

	function selectAnimation(index:Int):Void
	{
		if (animations.length == 0)
			return;

		selectedAnimation = (index + animations.length) % animations.length;
		playSelectedAnimation();
		refreshAnimationList();
		refreshDetails();
		refreshSubtitle();
	}

	function adjustOffset(deltaX:Float, deltaY:Float):Void
	{
		if (animations.length == 0)
			return;

		var info = animations[selectedAnimation];
		info.offsetX = Math.max(-MAX_OFFSET, Math.min(MAX_OFFSET, info.offsetX + deltaX));
		info.offsetY = Math.max(-MAX_OFFSET, Math.min(MAX_OFFSET, info.offsetY + deltaY));
		dirty = true;
		exitArmed = false;
		applyPreviewOffset();
		refreshAnimationList();
		refreshDetails();
		setStatus("UNSAVED CHANGES - SPACE TO SAVE", 0xFFFFAA33);
	}

	function resetOffset():Void
	{
		if (animations.length == 0)
			return;

		var info = animations[selectedAnimation];

		if (info.offsetX == 0 && info.offsetY == 0)
			return;

		info.offsetX = 0;
		info.offsetY = 0;
		dirty = true;
		exitArmed = false;
		applyPreviewOffset();
		refreshAnimationList();
		refreshDetails();
		setStatus("OFFSET RESET - UNSAVED CHANGES", 0xFFFFAA33);
	}

	function applyPreviewOffset():Void
	{
		if (preview == null || animations.length == 0)
			return;

		var info = animations[selectedAnimation];

		if (previewUsesPlaceholder)
			preview.offset.set(info.offsetX, info.offsetY);
		else
			preview.offset.set(previewBaseOffsetX + info.offsetX, previewBaseOffsetY + info.offsetY);
	}

	function refreshAll():Void
	{
		refreshCharacterList();
		refreshAnimationList();
		refreshSubtitle();
		refreshDetails();
	}

	function refreshCharacterList():Void
	{
		for (i in 0...characterTexts.length)
		{
			var index = characterOffset + i;
			var text = characterTexts[i];

			if (index >= characterEntries.length)
			{
				text.text = "";
				continue;
			}

			var entry = characterEntries[index];
			var selected = index == selectedCharacter;
			var broken = isBrokenEntry(entry);
			var ready = broken || (entryHasAtlas(entry) && entryHasConfig(entry));

			text.text = (selected ? "> " : "  ") + entry.name + (broken ? "  [DEFAULT]" : (ready ? "" : "  [!]"));
			text.color = selected ? FlxColor.WHITE : (ready ? 0xFF8888AA : 0xFF996677);
		}
	}

	function refreshAnimationList():Void
	{
		for (i in 0...animations.length)
		{
			var info = animations[i];
			var selected = i == selectedAnimation;
			var offsetText = animationOffsetTexts[i];

			animationTexts[i].text = (selected ? "> " : "  ") + info.name;
			animationTexts[i].color = selected ? FlxColor.WHITE : (info.available ? 0xFF8888AA : 0xFF664455);

			offsetText.text = '${info.available ? "OK" : "--"}  X ${formatInt(info.offsetX)}  Y ${formatInt(info.offsetY)}';
			offsetText.color = selected ? FlxColor.WHITE : (info.available ? 0xFF8888AA : 0xFF664455);
		}
	}

	function refreshSubtitle():Void
	{
		var entry = currentEntry();

		if (entry == null)
		{
			subtitleText.text = "NO CHARACTERS FOUND";
			return;
		}

		var state = isBrokenEntry(entry) ? "DEFAULT FALLBACK" : (previewUsesPlaceholder ? "BROKEN FALLBACK" : "ATLAS OK");
		subtitleText.text = 'CHARACTER: ${entry.name}    $state    TAB / SHIFT+TAB TO CYCLE';
	}

	function refreshDetails():Void
	{
		if (animations.length == 0 || infoText == null)
			return;

		var entry = currentEntry();
		var info = animations[selectedAnimation];
		var lines:Array<String> = [];

		lines.push('ANIM: ${info.name}');
		lines.push('PREFIX: ${info.prefix}');
		lines.push('FPS: ${formatNumber(info.fps)}    LOOP: ${info.looped ? "YES" : "NO"}');
		lines.push('FRAMES: ${countFrames(previewFrames, info.prefix)}');
		lines.push('OFFSET: X ${formatInt(info.offsetX)}    Y ${formatInt(info.offsetY)}');

		if (isBrokenEntry(entry))
			lines.push("ATLAS: BUILT-IN BROKEN CHARACTER");
		else if (previewUsesPlaceholder)
			lines.push("ATLAS: BROKEN FALLBACK");
		else if (!info.available)
			lines.push("ATLAS: ANIMATION MISSING");
		else
			lines.push("ATLAS: OK");

		if (isBrokenEntry(entry))
			lines.push("CONFIG: BUILT-IN FALLBACK");
		else if (currentConfig != null && currentConfig.error != null)
			lines.push('CONFIG: ${currentConfig.error}');
		else
			lines.push('CONFIG: ${configPathFor(entry)}');

		infoText.text = lines.join("\n");
	}

	function setStatus(message:String, color:Int):Void
	{
		if (statusText == null)
			return;

		statusText.text = message;
		statusText.color = color;
	}

	function currentEntry():CharacterEntry
	{
		return selectedCharacter >= 0 && selectedCharacter < characterEntries.length ? characterEntries[selectedCharacter] : null;
	}

	function configPathFor(entry:CharacterEntry):String
	{
		if (entry == null)
			return "NONE";

		if (currentConfig != null && currentConfig.source != null)
			return currentConfig.source;

		#if sys
		if (entry.dataFile != null)
			return entry.dataFile;
		#end

		if (entry.dataAsset != null)
			return entry.dataAsset;

		return '$DATA_ROOT${entry.name}.xml';
	}

	function saveConfig():Void
	{
		var entry = currentEntry();

		if (entry == null)
		{
			setStatus("NO CHARACTER SELECTED", 0xFFFF4455);
			return;
		}

		if (isBrokenEntry(entry))
		{
			setStatus("BROKEN IS THE BUILT-IN FALLBACK - NOTHING TO SAVE", 0xFFFFCC55);
			return;
		}

		var config = loadConfig(entry);

		if (config != null && config.root == null && config.error != null)
		{
			setStatus(config.error + " - SAVE ABORTED", 0xFFFF4455);
			return;
		}

		var root = config != null && config.root != null ? config.root : Xml.createElement("character");
		var existing = new Map<String, Xml>();

		for (node in root.elementsNamed("anim"))
		{
			var name = node.get("name");

			if (name != null)
				existing.set(name.toLowerCase(), node);
		}

		for (info in animations)
		{
			var node = existing.get(info.name.toLowerCase());

			if (node == null)
			{
				if (config != null && !info.available)
					continue;

				node = Xml.createElement("anim");
				node.set("name", info.name);
				node.set("anim", info.prefix);
				root.addChild(node);
			}
			else if (node.get("anim") == null || node.get("anim") == "")
			{
				node.set("anim", info.prefix);
			}

			node.set("x", formatInt(info.offsetX));
			node.set("y", formatInt(info.offsetY));
		}

		var doctype = config == null ? null : config.doctype;

		if (doctype == null && root.nodeName == "character")
			doctype = "<!DOCTYPE codename-engine-character>";

		var output = (doctype == null ? "" : doctype + "\n") + root.toString() + "\n";
		var path = resolveSavePath(entry);

		#if sys
		try
		{
			var directory = haxe.io.Path.directory(path);

			if (directory != null && directory != "" && !FileSystem.exists(directory))
				FileSystem.createDirectory(directory);

			File.saveContent(path, output);
			dirty = false;
			exitArmed = false;
			currentConfig = loadConfig(entry);
			refreshDetails();
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

	#if sys
	static function resolveSavePath(entry:CharacterEntry):String
	{
		if (entry.dataFile != null)
			return entry.dataFile;

		if (entry.dataAsset != null)
			return entry.dataAsset;

		return '$DATA_ROOT${entry.name}.xml';
	}
	#else
	static function resolveSavePath(entry:CharacterEntry):String
	{
		return null;
	}
	#end

	static function discoverCharacters():Array<CharacterEntry>
	{
		var entries:Map<String, CharacterEntry> = new Map();
		var assets = Assets.list();

		for (asset in assets)
		{
			if (asset.indexOf(DATA_ROOT) == 0 && StringTools.endsWith(asset, ".xml"))
			{
				var rest = asset.substr(DATA_ROOT.length);

				if (rest.indexOf("/") >= 0)
					continue;

				var name = stripExtension(rest);
				var entry = ensureEntry(entries, name);
				entry.name = name;
				entry.dataAsset = asset;
			}
			else if (asset.indexOf(IMAGE_ROOT) == 0 && StringTools.endsWith(asset, ".png"))
			{
				var rest = asset.substr(IMAGE_ROOT.length);

				if (rest.indexOf("/") >= 0)
					continue;

				var name = stripExtension(rest);
				var entry = ensureEntry(entries, name);
				entry.imageAsset = asset;
				entry.xmlAsset = '$IMAGE_ROOT$name.xml';
			}
			else if (asset.indexOf(IMAGE_ROOT) == 0 && StringTools.endsWith(asset, ".xml"))
			{
				var rest = asset.substr(IMAGE_ROOT.length);

				if (rest.indexOf("/") >= 0)
					continue;

				var name = stripExtension(rest);
				var entry = ensureEntry(entries, name);
				entry.xmlAsset = asset;
			}
		}

		#if sys
		scanPhysicalCharacters(entries, 'assets/data/characters', 'assets/images/characters');

		for (root in physicalModRoots())
			scanPhysicalCharacters(entries, '$root/data/characters', '$root/images/characters');
		#end

		var brokenEntry = ensureEntry(entries, BrokenCharacter.NAME);
		brokenEntry.name = BrokenCharacter.NAME;

		var result:Array<CharacterEntry> = [];

		for (entry in entries)
			result.push(entry);

		result.sort(function(a:CharacterEntry, b:CharacterEntry):Int
		{
			return compareNames(a.name, b.name);
		});

		return result;
	}

	static function ensureEntry(entries:Map<String, CharacterEntry>, name:String):CharacterEntry
	{
		var key = normalizeKey(name);
		var entry = entries.get(key);

		if (entry == null)
		{
			entry = createEntry(name);
			entries.set(key, entry);
		}

		return entry;
	}

	static function createEntry(name:String):CharacterEntry
	{
		return {
			name: name,
			dataAsset: null,
			dataFile: null,
			imageAsset: null,
			imageFile: null,
			xmlAsset: null,
			xmlFile: null
		};
	}

	#if sys
	static function physicalModRoots():Array<String>
	{
		var roots:Array<String> = [];
		addModDirectories(roots, "mods");

		var applicationDirectory = lime.system.System.applicationDirectory;

		if (applicationDirectory != null && applicationDirectory != "")
			addModDirectories(roots, '$applicationDirectory/mods');

		return roots;
	}

	static function addModDirectories(roots:Array<String>, base:String):Void
	{
		try
		{
			if (!FileSystem.exists(base) || !FileSystem.isDirectory(base))
				return;

			for (name in FileSystem.readDirectory(base))
			{
				var root = '$base/$name';

				if (FileSystem.isDirectory(root) && roots.indexOf(root) < 0)
					roots.push(root);
			}
		}
		catch (error:Dynamic) {}
	}

	static function scanPhysicalCharacters(entries:Map<String, CharacterEntry>, dataDirectory:String, imageDirectory:String):Void
	{
		for (file in readDirectoryFiles(dataDirectory, ".xml"))
		{
			var name = stripExtension(file);
			var entry = ensureEntry(entries, name);
			entry.name = name;
			entry.dataFile = '$dataDirectory/$file';
		}

		var imageXml:Map<String, String> = new Map();

		for (file in readDirectoryFiles(imageDirectory, ".xml"))
		{
			var name = stripExtension(file);
			imageXml.set(normalizeKey(name), '$imageDirectory/$file');
		}

		for (file in readDirectoryFiles(imageDirectory, ".png"))
		{
			var name = stripExtension(file);
			var entry = ensureEntry(entries, name);
			entry.imageFile = '$imageDirectory/$file';
			entry.xmlFile = imageXml.get(normalizeKey(name));
		}

		for (file in readDirectoryFiles(imageDirectory, ".xml"))
		{
			var name = stripExtension(file);
			var entry = ensureEntry(entries, name);
			entry.xmlFile = '$imageDirectory/$file';
		}
	}

	static function readDirectoryFiles(directory:String, extension:String):Array<String>
	{
		var result:Array<String> = [];

		try
		{
			if (!FileSystem.exists(directory) || !FileSystem.isDirectory(directory))
				return result;

			for (file in FileSystem.readDirectory(directory))
			{
				if (StringTools.endsWith(file.toLowerCase(), extension))
					result.push(file);
			}
		}
		catch (error:Dynamic) {}

		result.sort(compareNames);
		return result;
	}
	#end

	static function loadConfig(entry:CharacterEntry):CharacterConfig
	{
		if (entry == null)
			return null;

		var text:String = null;
		var source:String = null;

		#if sys
		if (entry.dataFile != null && FileSystem.exists(entry.dataFile))
		{
			try
			{
				text = File.getContent(entry.dataFile);
				source = entry.dataFile;
			}
			catch (error:Dynamic) {}
		}
		#end

		if (text == null && entry.dataAsset != null && Assets.exists(entry.dataAsset))
		{
			try
			{
				text = Assets.getText(entry.dataAsset);
				source = entry.dataAsset;
			}
			catch (error:Dynamic) {}
		}

		if (text == null)
			return null;

		var doctype = findDoctype(text);
		var root:Xml = null;
		var configError:String = null;

		try
		{
			var parsed = Xml.parse(text);
			root = parsed.firstElement();

			if (root == null)
				configError = "EMPTY CONFIG";
		}
		catch (error:Dynamic)
		{
			configError = "INVALID CONFIG";
		}

		if (doctype == null && root != null && root.nodeName == "character")
			doctype = "<!DOCTYPE codename-engine-character>";

		return {root: root, doctype: doctype, source: source, error: configError};
	}

	static function findDoctype(text:String):String
	{
		var start = text.indexOf("<!DOCTYPE");

		if (start < 0)
			return null;

		var end = text.indexOf(">", start);

		if (end < 0)
			return null;

		return text.substr(start, end - start + 1);
	}

	static function buildAnimationData(entry:CharacterEntry, config:CharacterConfig):Array<AnimationInfo>
	{
		var characterName = entry == null ? BrokenCharacter.NAME : entry.name;
		var result:Array<AnimationInfo> = [];

		for (i in 0...ANIMATION_NAMES.length)
		{
			result.push({
				name: ANIMATION_NAMES[i],
				prefix: '$characterName${ANIMATION_SUFFIXES[i]}',
				fps: 24,
				looped: true,
				offsetX: 0,
				offsetY: 0,
				available: false
			});
		}

		if (config == null || config.root == null)
			return result;

		for (node in config.root.elementsNamed("anim"))
		{
			var name = node.get("name");

			if (name == null)
				continue;

			var index = animationIndex(name);

			if (index < 0)
				continue;

			var info = result[index];
			var prefix = node.get("anim");

			if (prefix != null && prefix != "")
				info.prefix = prefix;

			var fps = readFloat(node.get("fps"), 24);

			if (fps > 0)
				info.fps = fps;

			var loop = node.get("loop");
			info.looped = loop == null || loop == "true";
			info.offsetX = readFloat(node.get("x"), 0);
			info.offsetY = readFloat(node.get("y"), 0);
		}

		return result;
	}

	static function animationIndex(name:String):Int
	{
		var lower = name.toLowerCase();

		for (i in 0...ANIMATION_NAMES.length)
		{
			if (ANIMATION_NAMES[i].toLowerCase() == lower)
				return i;
		}

		return -1;
	}

	static function loadFrames(entry:CharacterEntry):FlxAtlasFrames
	{
		if (entry == null)
			return null;

		try
		{
			#if sys
			if (entry.imageFile != null && entry.xmlFile != null && FileSystem.exists(entry.imageFile) && FileSystem.exists(entry.xmlFile))
			{
				var image = BitmapData.fromBytes(ByteArray.fromBytes(File.getBytes(entry.imageFile)));
				var xml = File.getContent(entry.xmlFile);

				if (image != null && xml != null && xml != "")
					return FlxAtlasFrames.fromSparrow(image, xml);
			}
			#end

			if (entry.imageAsset != null && entry.xmlAsset != null && Assets.exists(entry.imageAsset) && Assets.exists(entry.xmlAsset))
				return SparrowLoader.load(entry.imageAsset, entry.xmlAsset);
		}
		catch (error:Dynamic) {}

		return null;
	}

	static function entryHasAtlas(entry:CharacterEntry):Bool
	{
		if (entry == null)
			return false;

		#if sys
		if (entry.imageFile != null && entry.xmlFile != null && FileSystem.exists(entry.imageFile) && FileSystem.exists(entry.xmlFile))
			return true;
		#end

		return entry.imageAsset != null && entry.xmlAsset != null && Assets.exists(entry.imageAsset) && Assets.exists(entry.xmlAsset);
	}

	static function entryHasConfig(entry:CharacterEntry):Bool
	{
		var config = loadConfig(entry);
		return config != null && config.error == null && config.root != null && config.root.nodeName == "character";
	}

	static function isBrokenEntry(entry:CharacterEntry):Bool
	{
		return entry != null && normalizeKey(entry.name) == BrokenCharacter.NAME;
	}

	static function hasPrefix(frames:FlxAtlasFrames, prefix:String):Bool
	{
		if (frames == null || prefix == null)
			return false;

		for (frame in frames.frames)
		{
			if (frame.name != null && frame.name.indexOf(prefix) == 0)
				return true;
		}

		return false;
	}

	static function countFrames(frames:FlxAtlasFrames, prefix:String):Int
	{
		if (frames == null || prefix == null)
			return 0;

		var count = 0;

		for (frame in frames.frames)
		{
			if (frame.name != null && frame.name.indexOf(prefix) == 0)
				count++;
		}

		return count;
	}

	static function stripExtension(file:String):String
	{
		var dot = file.lastIndexOf(".");

		return dot < 0 ? file : file.substr(0, dot);
	}

	static function readFloat(value:String, fallback:Float):Float
	{
		if (value == null)
			return fallback;

		var parsed = Std.parseFloat(value);

		return Math.isNaN(parsed) ? fallback : parsed;
	}

	static function formatInt(value:Float):String
	{
		return Std.string(Math.round(value));
	}

	static function formatNumber(value:Float):String
	{
		return Std.string(value);
	}

	static function normalizeKey(name:String):String
	{
		var key = name.toLowerCase();
		key = StringTools.replace(key, "-", "");
		key = StringTools.replace(key, "_", "");
		key = StringTools.replace(key, " ", "");

		return key;
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
