package notes;

import input.NoteDirection;

class Note
{
	public var time:Float;
	public var direction:NoteDirection;
	public var hit:Bool = false;
	public var judgment:Null<Judgment>;

	public function new(time:Float, direction:NoteDirection)
	{
		this.time = time;
		this.direction = direction;
	}
}
