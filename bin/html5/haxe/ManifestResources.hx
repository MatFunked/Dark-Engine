package;

import haxe.io.Bytes;
import haxe.io.Path;
import lime.utils.AssetBundle;
import lime.utils.AssetLibrary;
import lime.utils.AssetManifest;
import lime.utils.Assets;

#if sys
import sys.FileSystem;
#end

#if disable_preloader_assets
@:dox(hide) class ManifestResources {
	public static var preloadLibraries:Array<Dynamic>;
	public static var preloadLibraryNames:Array<String>;
	public static var rootPath:String;

	public static function init (config:Dynamic):Void {
		preloadLibraries = new Array ();
		preloadLibraryNames = new Array ();
	}
}
#else
@:access(lime.utils.Assets)


@:keep @:dox(hide) class ManifestResources {


	public static var preloadLibraries:Array<AssetLibrary>;
	public static var preloadLibraryNames:Array<String>;
	public static var rootPath:String;


	public static function init (config:Dynamic):Void {

		preloadLibraries = new Array ();
		preloadLibraryNames = new Array ();

		rootPath = null;

		if (config != null && Reflect.hasField (config, "rootPath")) {

			rootPath = Reflect.field (config, "rootPath");

			if(!StringTools.endsWith (rootPath, "/")) {

				rootPath += "/";

			}

		}

		if (rootPath == null) {

			#if (ios || tvos || webassembly)
			rootPath = "assets/";
			#elseif android
			rootPath = "";
			#elseif (console || sys)
			rootPath = lime.system.System.applicationDirectory;
			#else
			rootPath = "./";
			#end

		}

		#if (openfl && !flash && !display)
		openfl.text.Font.registerFont (__ASSET__OPENFL__flixel_fonts_nokiafc22_ttf);
		openfl.text.Font.registerFont (__ASSET__OPENFL__flixel_fonts_monsterrat_ttf);
		
		#end

		var data, manifest, library, bundle;

		data = '{"name":null,"assets":"aoy4:pathy42:assets%2Fsongs%2Femma%2Fcharts%2Fhard.jsony4:sizei39897y4:typey4:TEXTy2:idR1y7:preloadtgoR0y33:assets%2Fsongs%2Femma%2Fmeta.jsonR2i249R3R4R5R7R6tgoR2i6263781R3y5:MUSICR5y39:assets%2Fsongs%2Femma%2Fsong%2FInst.oggy9:pathGroupaR9hR6tgoR2i6227302R3R8R5y46:assets%2Fsongs%2Femma%2Fsong%2FVoices-emma.oggR10aR11hR6tgoR2i5918341R3R8R5y46:assets%2Fsongs%2Femma%2Fsong%2FVoices-math.oggR10aR12hR6tgoR0y53:assets%2Fsongs%2Fsoft%20trolling%2Fcharts%2Fhard.jsonR2i31146R3R4R5R13R6tgoR0y44:assets%2Fsongs%2Fsoft%20trolling%2Fmeta.jsonR2i258R3R4R5R14R6tgoR2i5663512R3R8R5y50:assets%2Fsongs%2Fsoft%20trolling%2Fsong%2FInst.oggR10aR15hR6tgoR2i5662538R3R8R5y52:assets%2Fsongs%2Fsoft%20trolling%2Fsong%2FVoices.oggR10aR16hR6tgoR0y42:assets%2Fimages%2Fcharacters%2Fbfpapel.pngR2i2011223R3y5:IMAGER5R17R6tgoR0y42:assets%2Fimages%2Fcharacters%2Fbfpapel.xmlR2i3523R3R4R5R19R6tgoR0y39:assets%2Fimages%2Fcharacters%2Femma.pngR2i2044232R3R18R5R20R6tgoR0y39:assets%2Fimages%2Fcharacters%2Femma.xmlR2i3040R3R4R5R21R6tgoR0y39:assets%2Fimages%2Fcharacters%2Fmath.pngR2i1602227R3R18R5R22R6tgoR0y39:assets%2Fimages%2Fcharacters%2Fmath.xmlR2i3408R3R4R5R23R6tgoR0y41:assets%2Fimages%2Fcharacters%2Fmathbg.pngR2i320700R3R18R5R24R6tgoR0y41:assets%2Fimages%2Fcharacters%2Fmathbg.xmlR2i515R3R4R5R25R6tgoR0y40:assets%2Fdata%2Fcharacters%2Fbfpapel.xmlR2i470R3R4R5R26R6tgoR0y37:assets%2Fdata%2Fcharacters%2Femma.xmlR2i294R3R4R5R27R6tgoR0y40:assets%2Fdata%2Fcharacters%2FMath-BG.xmlR2i167R3R4R5R28R6tgoR0y37:assets%2Fdata%2Fcharacters%2Fmath.xmlR2i417R3R4R5R29R6tgoR0y35:assets%2Fimages%2Fnotes%2Fnotes.pngR2i1880R3R18R5R30R6tgoR0y35:assets%2Fimages%2Fnotes%2Fnotes.xmlR2i380R3R4R5R31R6tgoR2i8220R3R8R5y26:flixel%2Fsounds%2Fbeep.mp3R10aR32y26:flixel%2Fsounds%2Fbeep.ogghR6tgoR2i39706R3R8R5y28:flixel%2Fsounds%2Fflixel.mp3R10aR34y28:flixel%2Fsounds%2Fflixel.ogghR6tgoR2i6840R3y5:SOUNDR5R33R10aR32R33hgoR2i33629R3R36R5R35R10aR34R35hgoR2i15744R3y4:FONTy9:classNamey35:__ASSET__flixel_fonts_nokiafc22_ttfR5y30:flixel%2Ffonts%2Fnokiafc22.ttfR6tgoR2i29724R3R37R38y36:__ASSET__flixel_fonts_monsterrat_ttfR5y31:flixel%2Ffonts%2Fmonsterrat.ttfR6tgoR0y33:flixel%2Fimages%2Fui%2Fbutton.pngR2i248R3R18R5R43R6tgoR0y36:flixel%2Fimages%2Flogo%2Fdefault.pngR2i505R3R18R5R44R6tgh","rootPath":null,"version":2,"libraryArgs":[],"libraryType":null}';
		manifest = AssetManifest.parse (data, rootPath);
		library = AssetLibrary.fromManifest (manifest);
		Assets.registerLibrary ("default", library);
		

		library = Assets.getLibrary ("default");
		if (library != null) preloadLibraries.push (library);
		else preloadLibraryNames.push ("default");
		

	}


}

#if !display
#if flash

@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_songs_emma_charts_hard_json extends null { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_songs_emma_meta_json extends null { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_songs_emma_song_inst_ogg extends null { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_songs_emma_song_voices_emma_ogg extends null { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_songs_emma_song_voices_math_ogg extends null { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_songs_soft_trolling_charts_hard_json extends null { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_songs_soft_trolling_meta_json extends null { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_songs_soft_trolling_song_inst_ogg extends null { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_songs_soft_trolling_song_voices_ogg extends null { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_images_characters_bfpapel_png extends flash.display.BitmapData { public function new () { super (0, 0, true, 0); } }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_images_characters_bfpapel_xml extends null { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_images_characters_emma_png extends flash.display.BitmapData { public function new () { super (0, 0, true, 0); } }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_images_characters_emma_xml extends null { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_images_characters_math_png extends flash.display.BitmapData { public function new () { super (0, 0, true, 0); } }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_images_characters_math_xml extends null { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_images_characters_mathbg_png extends flash.display.BitmapData { public function new () { super (0, 0, true, 0); } }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_images_characters_mathbg_xml extends null { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_data_characters_bfpapel_xml extends null { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_data_characters_emma_xml extends null { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_data_characters_math_bg_xml extends null { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_data_characters_math_xml extends null { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_images_notes_notes_png extends flash.display.BitmapData { public function new () { super (0, 0, true, 0); } }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__assets_images_notes_notes_xml extends null { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__flixel_sounds_beep_mp3 extends null { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__flixel_sounds_flixel_mp3 extends null { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__flixel_sounds_beep_ogg extends null { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__flixel_sounds_flixel_ogg extends null { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__flixel_fonts_nokiafc22_ttf extends null { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__flixel_fonts_monsterrat_ttf extends null { }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__flixel_images_ui_button_png extends flash.display.BitmapData { public function new () { super (0, 0, true, 0); } }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__flixel_images_logo_default_png extends flash.display.BitmapData { public function new () { super (0, 0, true, 0); } }
@:keep @:bind @:noCompletion #if display private #end class __ASSET__manifest_default_json extends null { }


#elseif (desktop || cpp)

@:keep @:file("mods/Emma's Road - TAT UST/songs/emma/charts/hard.json") @:noCompletion #if display private #end class __ASSET__assets_songs_emma_charts_hard_json extends haxe.io.Bytes {}
@:keep @:file("mods/Emma's Road - TAT UST/songs/emma/meta.json") @:noCompletion #if display private #end class __ASSET__assets_songs_emma_meta_json extends haxe.io.Bytes {}
@:keep @:file("mods/Emma's Road - TAT UST/songs/emma/song/Inst.ogg") @:noCompletion #if display private #end class __ASSET__assets_songs_emma_song_inst_ogg extends haxe.io.Bytes {}
@:keep @:file("mods/Emma's Road - TAT UST/songs/emma/song/Voices-emma.ogg") @:noCompletion #if display private #end class __ASSET__assets_songs_emma_song_voices_emma_ogg extends haxe.io.Bytes {}
@:keep @:file("mods/Emma's Road - TAT UST/songs/emma/song/Voices-math.ogg") @:noCompletion #if display private #end class __ASSET__assets_songs_emma_song_voices_math_ogg extends haxe.io.Bytes {}
@:keep @:file("mods/Emma's Road - TAT UST/songs/soft trolling/charts/hard.json") @:noCompletion #if display private #end class __ASSET__assets_songs_soft_trolling_charts_hard_json extends haxe.io.Bytes {}
@:keep @:file("mods/Emma's Road - TAT UST/songs/soft trolling/meta.json") @:noCompletion #if display private #end class __ASSET__assets_songs_soft_trolling_meta_json extends haxe.io.Bytes {}
@:keep @:file("mods/Emma's Road - TAT UST/songs/soft trolling/song/Inst.ogg") @:noCompletion #if display private #end class __ASSET__assets_songs_soft_trolling_song_inst_ogg extends haxe.io.Bytes {}
@:keep @:file("mods/Emma's Road - TAT UST/songs/soft trolling/song/Voices.ogg") @:noCompletion #if display private #end class __ASSET__assets_songs_soft_trolling_song_voices_ogg extends haxe.io.Bytes {}
@:keep @:image("mods/Emma's Road - TAT UST/images/characters/bfpapel.png") @:noCompletion #if display private #end class __ASSET__assets_images_characters_bfpapel_png extends lime.graphics.Image {}
@:keep @:file("mods/Emma's Road - TAT UST/images/characters/bfpapel.xml") @:noCompletion #if display private #end class __ASSET__assets_images_characters_bfpapel_xml extends haxe.io.Bytes {}
@:keep @:image("mods/Emma's Road - TAT UST/images/characters/emma.png") @:noCompletion #if display private #end class __ASSET__assets_images_characters_emma_png extends lime.graphics.Image {}
@:keep @:file("mods/Emma's Road - TAT UST/images/characters/emma.xml") @:noCompletion #if display private #end class __ASSET__assets_images_characters_emma_xml extends haxe.io.Bytes {}
@:keep @:image("mods/Emma's Road - TAT UST/images/characters/math.png") @:noCompletion #if display private #end class __ASSET__assets_images_characters_math_png extends lime.graphics.Image {}
@:keep @:file("mods/Emma's Road - TAT UST/images/characters/math.xml") @:noCompletion #if display private #end class __ASSET__assets_images_characters_math_xml extends haxe.io.Bytes {}
@:keep @:image("mods/Emma's Road - TAT UST/images/characters/mathbg.png") @:noCompletion #if display private #end class __ASSET__assets_images_characters_mathbg_png extends lime.graphics.Image {}
@:keep @:file("mods/Emma's Road - TAT UST/images/characters/mathbg.xml") @:noCompletion #if display private #end class __ASSET__assets_images_characters_mathbg_xml extends haxe.io.Bytes {}
@:keep @:file("mods/Emma's Road - TAT UST/data/characters/bfpapel.xml") @:noCompletion #if display private #end class __ASSET__assets_data_characters_bfpapel_xml extends haxe.io.Bytes {}
@:keep @:file("mods/Emma's Road - TAT UST/data/characters/emma.xml") @:noCompletion #if display private #end class __ASSET__assets_data_characters_emma_xml extends haxe.io.Bytes {}
@:keep @:file("mods/Emma's Road - TAT UST/data/characters/Math-BG.xml") @:noCompletion #if display private #end class __ASSET__assets_data_characters_math_bg_xml extends haxe.io.Bytes {}
@:keep @:file("mods/Emma's Road - TAT UST/data/characters/math.xml") @:noCompletion #if display private #end class __ASSET__assets_data_characters_math_xml extends haxe.io.Bytes {}
@:keep @:image("assets/images/notes/notes.png") @:noCompletion #if display private #end class __ASSET__assets_images_notes_notes_png extends lime.graphics.Image {}
@:keep @:file("assets/images/notes/notes.xml") @:noCompletion #if display private #end class __ASSET__assets_images_notes_notes_xml extends haxe.io.Bytes {}
@:keep @:file("C:/HaxeToolkit/haxe/lib/flixel/5,6,1/assets/sounds/beep.mp3") @:noCompletion #if display private #end class __ASSET__flixel_sounds_beep_mp3 extends haxe.io.Bytes {}
@:keep @:file("C:/HaxeToolkit/haxe/lib/flixel/5,6,1/assets/sounds/flixel.mp3") @:noCompletion #if display private #end class __ASSET__flixel_sounds_flixel_mp3 extends haxe.io.Bytes {}
@:keep @:file("C:/HaxeToolkit/haxe/lib/flixel/5,6,1/assets/sounds/beep.ogg") @:noCompletion #if display private #end class __ASSET__flixel_sounds_beep_ogg extends haxe.io.Bytes {}
@:keep @:file("C:/HaxeToolkit/haxe/lib/flixel/5,6,1/assets/sounds/flixel.ogg") @:noCompletion #if display private #end class __ASSET__flixel_sounds_flixel_ogg extends haxe.io.Bytes {}
@:keep @:font("bin/html5/obj/webfont/nokiafc22.ttf") @:noCompletion #if display private #end class __ASSET__flixel_fonts_nokiafc22_ttf extends lime.text.Font {}
@:keep @:font("bin/html5/obj/webfont/monsterrat.ttf") @:noCompletion #if display private #end class __ASSET__flixel_fonts_monsterrat_ttf extends lime.text.Font {}
@:keep @:image("C:/HaxeToolkit/haxe/lib/flixel/5,6,1/assets/images/ui/button.png") @:noCompletion #if display private #end class __ASSET__flixel_images_ui_button_png extends lime.graphics.Image {}
@:keep @:image("C:/HaxeToolkit/haxe/lib/flixel/5,6,1/assets/images/logo/default.png") @:noCompletion #if display private #end class __ASSET__flixel_images_logo_default_png extends lime.graphics.Image {}
@:keep @:file("") @:noCompletion #if display private #end class __ASSET__manifest_default_json extends haxe.io.Bytes {}



#else

@:keep @:expose('__ASSET__flixel_fonts_nokiafc22_ttf') @:noCompletion #if display private #end class __ASSET__flixel_fonts_nokiafc22_ttf extends lime.text.Font { public function new () { #if !html5 __fontPath = "flixel/fonts/nokiafc22"; #else ascender = 2048; descender = -512; height = 2816; numGlyphs = 172; underlinePosition = -640; underlineThickness = 256; unitsPerEM = 2048; #end name = "Nokia Cellphone FC Small"; super (); }}
@:keep @:expose('__ASSET__flixel_fonts_monsterrat_ttf') @:noCompletion #if display private #end class __ASSET__flixel_fonts_monsterrat_ttf extends lime.text.Font { public function new () { #if !html5 __fontPath = "flixel/fonts/monsterrat"; #else ascender = 968; descender = -251; height = 1219; numGlyphs = 263; underlinePosition = -150; underlineThickness = 50; unitsPerEM = 1000; #end name = "Monsterrat"; super (); }}


#end

#if (openfl && !flash)

#if html5
@:keep @:expose('__ASSET__OPENFL__flixel_fonts_nokiafc22_ttf') @:noCompletion #if display private #end class __ASSET__OPENFL__flixel_fonts_nokiafc22_ttf extends openfl.text.Font { public function new () { __fromLimeFont (new __ASSET__flixel_fonts_nokiafc22_ttf ()); super (); }}
@:keep @:expose('__ASSET__OPENFL__flixel_fonts_monsterrat_ttf') @:noCompletion #if display private #end class __ASSET__OPENFL__flixel_fonts_monsterrat_ttf extends openfl.text.Font { public function new () { __fromLimeFont (new __ASSET__flixel_fonts_monsterrat_ttf ()); super (); }}

#else
@:keep @:expose('__ASSET__OPENFL__flixel_fonts_nokiafc22_ttf') @:noCompletion #if display private #end class __ASSET__OPENFL__flixel_fonts_nokiafc22_ttf extends openfl.text.Font { public function new () { __fromLimeFont (new __ASSET__flixel_fonts_nokiafc22_ttf ()); super (); }}
@:keep @:expose('__ASSET__OPENFL__flixel_fonts_monsterrat_ttf') @:noCompletion #if display private #end class __ASSET__OPENFL__flixel_fonts_monsterrat_ttf extends openfl.text.Font { public function new () { __fromLimeFont (new __ASSET__flixel_fonts_monsterrat_ttf ()); super (); }}

#end

#end
#end

#end