package notes;

import input.NoteDirection;

class NoteDetector
{
	public var windows:TimingWindows;

	public function new(?windows:TimingWindows)
	{
		this.windows = windows == null ? new TimingWindows() : windows;
	}

	public function judge(noteTime:Float, songTime:Float):Judgment
	{
		return windows.judge(noteTime, songTime);
	}

	public function findClosestNote(notes:Array<Note>, direction:NoteDirection, songTime:Float):Null<Note>
	{
		var closest:Note = null;
		var closestDistance:Float = windows.missWindow;

		for (note in notes)
		{
			if (note.hit || note.direction != direction)
				continue;

			var distance = Math.abs(note.time - songTime);

			if (distance <= closestDistance)
			{
				closest = note;
				closestDistance = distance;
			}
		}

		return closest;
	}

	public function hitNote(notes:Array<Note>, direction:NoteDirection, songTime:Float):Null<HitResult>
	{
		var note = findClosestNote(notes, direction, songTime);

		if (note == null)
			return null;

		var judgment = judge(note.time, songTime);
		note.hit = true;
		note.judgment = judgment;

		return {
			note: note,
			judgment: judgment,
			offset: songTime - note.time
		};
	}

	public function collectMissedNotes(notes:Array<Note>, songTime:Float):Array<Note>
	{
		var missed:Array<Note> = [];

		for (note in notes)
		{
			if (note.hit || songTime - note.time <= windows.missWindow)
				continue;

			note.hit = true;
			note.judgment = Judgment.MISS;
			missed.push(note);
		}

		return missed;
	}
}
