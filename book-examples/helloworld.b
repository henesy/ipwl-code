#
#       Software from the book "Inferno Programming with Limbo"
#       published by John Wiley & Sons, January 2003.
#
#       p. Stanley-Marbell <pip@gemusehaken.org>
#
implement HelloWorld;

include "sys.m";
include "draw.m";
include "helloworld.m";


init(nil: ref Draw->Context, nil: list of string)
{
	sys : Sys;
                
	#	This is a comment
	sys = load Sys Sys->PATH;

	sys->print("Hello World !\n");
}
