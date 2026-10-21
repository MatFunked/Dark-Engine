package input;

enum abstract NoteDirection(Int) from Int to Int
{
	var LEFT = 0;
	var DOWN = 1;
	var UP = 2;
	var RIGHT = 3;

	static final DIRECTIONS:Array<NoteDirection> = [LEFT, DOWN, UP, RIGHT];

	public static function all():Array<NoteDirection>
	{
		return DIRECTIONS.copy();
	}
}
