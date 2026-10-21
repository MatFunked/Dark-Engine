package;

import flixel.FlxG;
import flixel.FlxGame;
import openfl.display.Sprite;
import states.MainMenuState;

class Main extends Sprite
{
	public static inline var GAME_WIDTH:Int = 1280;
	public static inline var GAME_HEIGHT:Int = 720;
	public static inline var TARGET_FPS:Int = 60;

	public function new()
	{
		super();

		addChild(new FlxGame(GAME_WIDTH, GAME_HEIGHT, MainMenuState.new, TARGET_FPS, TARGET_FPS, true));

		FlxG.fixedTimestep = true;
	}
}
