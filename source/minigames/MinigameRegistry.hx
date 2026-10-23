package minigames;

class MinigameRegistry
{
	static var factories:Map<String, MinigameContext->BaseMinigame>;

	public static function create(type:String, context:MinigameContext):BaseMinigame
	{
		init();

		var factory = factories.get(normalize(type));
		return factory == null ? null : factory(context);
	}

	public static function register(type:String, factory:MinigameContext->BaseMinigame):Void
	{
		init();
		factories.set(normalize(type), factory);
	}

	public static function exists(type:String):Bool
	{
		init();
		return factories.exists(normalize(type));
	}

	static function init():Void
	{
		if (factories != null)
			return;

		factories = new Map<String, MinigameContext->BaseMinigame>();
		factories.set("pong", function(context:MinigameContext):BaseMinigame return new PongMinigame(context));
		factories.set("undertale", function(context:MinigameContext):BaseMinigame return new UndertaleMinigame(context));
		factories.set("timing", function(context:MinigameContext):BaseMinigame return new UndertaleMinigame(context));
	}

	static function normalize(type:String):String
	{
		if (type == null)
			return "";

		return StringTools.replace(StringTools.replace(StringTools.replace(type.toLowerCase(), " ", ""), "_", ""), "-", "");
	}
}
