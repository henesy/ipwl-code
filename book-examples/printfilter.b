#
#       Software from the book "Inferno Programming with Limbo"
#       published by John Wiley & Sons, January 2003.
#
#       p. Stanley-Marbell <pip@gemusehaken.org>
#
implement Filter;

include "sys.m";
include "styx.m";
include "filter.m";

sys : Sys;
styx : Styx;
Smsg : import styx;

init(nil, nil : array of ref Sys->FD)
{
	sys = load Sys Sys->PATH;

	styx = load Styx Styx->PATH;
	if (styx == nil)
	{
		raise sys->sprint("fail:Could not load %s : %r", Styx->PATH);
	}

	filtername = "Print Filter : Print Styx messages in filter pipeline.";
	sys->print("Filter module \"%s\" initialised.\n", filtername);
}

rewrite(fmsg : ref Filtermsg)
{
	sys->print("%s\n", fmsg.styxmsg.print());
}
