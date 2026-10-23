package minigames;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;

class PongMinigame extends BaseMinigame
{
	static inline var FIELD_X:Float = 48;
	static inline var FIELD_Y:Float = 100;
	static inline var FIELD_BOTTOM_MARGIN:Float = 100;
	static inline var BALL_SIZE:Int = 16;
	static inline var PADDLE_WIDTH:Float = 150;
	static inline var PADDLE_HEIGHT:Float = 16;
	static inline var PADDLE_SPEED:Float = 760;
	static inline var PADDLE_MARGIN:Float = 64;

	var ball:FlxSprite;
	var paddle:FlxSprite;
	var ballVelocity:FlxPoint = new FlxPoint();
	var timerText:FlxText;
	var fieldWidth:Float;
	var fieldHeight:Float;
	var ballSpeed:Float;

	public function new(context:MinigameContext)
	{
		super(context);
	}

	override public function onStart():Void
	{
		fieldWidth = FlxG.width - FIELD_X * 2;
		fieldHeight = FlxG.height - FIELD_Y - FIELD_BOTTOM_MARGIN;
		ballSpeed = speedForDifficulty(context.difficulty);

		var title = new FlxText(0, 30, FlxG.width, "PONG", 40);
		title.alignment = FlxTextAlign.CENTER;
		title.color = 0xFFFFE066;
		add(title);

		timerText = new FlxText(0, 74, FlxG.width, "", 18);
		timerText.alignment = FlxTextAlign.CENTER;
		timerText.color = 0xFF99AACC;
		add(timerText);

		var field = new FlxSprite(FIELD_X, FIELD_Y);
		field.makeGraphic(Std.int(fieldWidth), Std.int(fieldHeight), 0xFF111A2A);
		add(field);

		ball = new FlxSprite(0, 0);
		ball.makeGraphic(BALL_SIZE, BALL_SIZE, 0xFFFFE066);
		add(ball);

		paddle = new FlxSprite(0, FIELD_Y + fieldHeight - PADDLE_MARGIN);
		paddle.makeGraphic(Std.int(PADDLE_WIDTH), Std.int(PADDLE_HEIGHT), 0xFF66CCFF);
		add(paddle);

		var hint = new FlxText(0, FlxG.height - 62, FlxG.width, "A / D or LEFT / RIGHT: MOVE PADDLE", 18);
		hint.alignment = FlxTextAlign.CENTER;
		hint.color = FlxColor.GRAY;
		add(hint);

		resetBall();
	}

	override public function onUpdate(elapsed:Float):Void
	{
		movePaddle(elapsed);
		moveBall(elapsed);

		timerText.text = '${Math.ceil(remaining)}s';

		if (context.duration > 0 && this.elapsed >= context.duration)
			win();
	}

	override public function onWin():Void
	{
		timerText.text = "CLEARED";
		timerText.color = 0xFF66FF99;
	}

	override public function onLose():Void
	{
		timerText.text = "MISSED";
		timerText.color = 0xFFFF5566;
	}

	function movePaddle(elapsed:Float):Void
	{
		var direction = 0.0;

		if (FlxG.keys.pressed.LEFT || FlxG.keys.pressed.A)
			direction -= 1;

		if (FlxG.keys.pressed.RIGHT || FlxG.keys.pressed.D)
			direction += 1;

		paddle.x += direction * PADDLE_SPEED * elapsed;
		paddle.x = Math.max(FIELD_X, Math.min(FIELD_X + fieldWidth - paddle.width, paddle.x));
	}

	function moveBall(elapsed:Float):Void
	{
		ball.x += ballVelocity.x * elapsed;
		ball.y += ballVelocity.y * elapsed;

		if (ball.x <= FIELD_X)
		{
			ball.x = FIELD_X;
			ballVelocity.x = Math.abs(ballVelocity.x);
		}
		else if (ball.x + ball.width >= FIELD_X + fieldWidth)
		{
			ball.x = FIELD_X + fieldWidth - ball.width;
			ballVelocity.x = -Math.abs(ballVelocity.x);
		}

		if (ball.y <= FIELD_Y)
		{
			ball.y = FIELD_Y;
			ballVelocity.y = Math.abs(ballVelocity.y);
		}

		if (ballVelocity.y > 0
			&& ball.y + ball.height >= paddle.y
			&& ball.y <= paddle.y + paddle.height
			&& ball.x + ball.width >= paddle.x
			&& ball.x <= paddle.x + paddle.width)
		{
			ball.y = paddle.y - ball.height;
			ballVelocity.y = -Math.abs(ballVelocity.y);

			var hitOffset = (ball.x + ball.width * 0.5 - (paddle.x + paddle.width * 0.5)) / (paddle.width * 0.5);
			ballVelocity.x = Math.max(-ballSpeed, Math.min(ballSpeed, ballVelocity.x + hitOffset * 180));
			return;
		}

		if (ball.y > FIELD_Y + fieldHeight)
			lose();
	}

	function resetBall():Void
	{
		ball.setPosition(FIELD_X + fieldWidth * 0.5 - ball.width * 0.5, FIELD_Y + fieldHeight * 0.35);
		paddle.setPosition(FIELD_X + fieldWidth * 0.5 - paddle.width * 0.5, FIELD_Y + fieldHeight - PADDLE_MARGIN);
		ballVelocity.set(ballSpeed * 0.55, -ballSpeed * 0.85);
	}

	static function speedForDifficulty(difficulty:String):Float
	{
		switch (difficulty == null ? "" : difficulty.toLowerCase())
		{
			case "easy":
				return 280;
			case "hard":
				return 500;
			default:
				return 380;
		}
	}
}
