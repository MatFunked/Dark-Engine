package minigames;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.util.FlxColor;

class BaseMinigame extends FlxSubState
{
	public var context(default, null):MinigameContext;
	public var result(default, null):MinigameResult = MinigameResult.CANCELLED;
	public var elapsed(default, null):Float = 0;
	public var finished(default, null):Bool = false;
	public var remaining(get, never):Float;

	var endNotified:Bool = false;
	var backdrop:FlxSprite;

	public function new(context:MinigameContext)
	{
		super(0xFF0B0B12);
		this.context = context;

		if (context.camera != null)
			cameras = [context.camera];
	}

	override public function create():Void
	{
		super.create();

		backdrop = new FlxSprite(0, 0);
		backdrop.makeGraphic(FlxG.width, FlxG.height, 0xFF0B0B12);
		backdrop.scrollFactor.set(0, 0);

		if (context.camera != null)
			backdrop.cameras = [context.camera];

		add(backdrop);
		onStart();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (finished)
			return;

		this.elapsed += elapsed;
		onUpdate(elapsed);

		if (!finished && context.duration > 0 && this.elapsed >= context.duration)
			lose();
	}

	override public function destroy():Void
	{
		if (!endNotified)
			notifyEnd();

		context = null;
		backdrop = null;
		super.destroy();
	}

	public function win():Void
	{
		finish(MinigameResult.WIN);
	}

	public function lose():Void
	{
		finish(MinigameResult.LOSE);
	}

	public function cancel():Void
	{
		finish(MinigameResult.CANCELLED);
	}

	public function finish(minigameResult:MinigameResult):Void
	{
		if (finished)
			return;

		finished = true;
		result = minigameResult;

		if (minigameResult == MinigameResult.WIN)
			onWin();
		else if (minigameResult == MinigameResult.LOSE)
			onLose();

		notifyEnd();
		close();
	}

	public function get_remaining():Float
	{
		if (context == null || context.duration <= 0)
			return 0;

		return Math.max(0, context.duration - elapsed);
	}

	public function onStart():Void {}

	public function onUpdate(elapsed:Float):Void {}

	public function onWin():Void {}

	public function onLose():Void {}

	public function onEnd():Void {}

	function notifyEnd():Void
	{
		if (endNotified)
			return;

		endNotified = true;
		onEnd();
	}
}
