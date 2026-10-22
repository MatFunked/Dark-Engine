package ui;

import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.util.FlxColor;

class HealthBar extends FlxGroup
{
	public static inline var BAR_WIDTH:Float = 420;
	public static inline var BAR_HEIGHT:Float = 18;

	var fill:FlxSprite;

	public function new(x:Float, y:Float)
	{
		super();

		var background = new FlxSprite(x - 2, y - 2);
		background.makeGraphic(Std.int(BAR_WIDTH + 4), Std.int(BAR_HEIGHT + 4), 0xFF05050A);
		add(background);

		fill = new FlxSprite(x, y);
		fill.makeGraphic(Std.int(BAR_WIDTH), Std.int(BAR_HEIGHT), FlxColor.WHITE);
		fill.origin.set(0, 0);
		add(fill);

		setHealth(0.5);
	}

	public function setCamera(camera:FlxCamera):Void
	{
		for (member in members)
			member.cameras = [camera];
	}

	public function setHealth(value:Float):Void
	{
		var clamped = Math.max(0, Math.min(1, value));
		fill.scale.x = clamped;
		fill.color = healthColor(clamped);
		fill.visible = clamped > 0;
	}

	public function getHealth():Float
	{
		return fill.scale.x;
	}

	inline function healthColor(value:Float):FlxColor
	{
		if (value >= 0.5)
			return 0xFF33DD66;
		if (value > 0.25)
			return 0xFFFFCC33;

		return 0xFFFF3344;
	}
}
