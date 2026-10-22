package notes;

enum abstract Judgment(String) from String to String
{
	var SICK = "Sick";
	var GOOD = "Good";
	var BAD = "Bad";
	var SHIT = "Shit";
	var MISS = "Miss";

	public inline function label():String
	{
		return this;
	}
}
