#
#       Software from the book "Inferno Programming with Limbo"
#       published by John Wiley & Sons, January 2003.
#
#       p. Stanley-Marbell <pip@gemusehaken.org>
#
implement Byte2char;

include "sys.m";
include "draw.m";

sys : Sys;

Byte2char : module {
	init : fn(nil : ref Draw->Context, args: list of string);
};

init(nil : ref Draw->Context, args: list of string) {
	sys = load Sys Sys->PATH;

	runes: list of string;
	if(len args < 2) {
		# μ
		μ := string array[] of {byte 16rce, byte 16rbc};
		runes = μ :: runes;
	} else
		runes = tl args;

	for(; runes != nil; runes = tl runes) {
		unistring: string;
		(unichar, utflen, status) := sys->byte2char(array of byte hd runes, 0);
		unistring[len unistring] = unichar;

		if (status == 0)
			sys->print("byte2char failed, invalid UTF-8 sequence\n");
		else
			sys->print("%d bytes used to create Unicode character '%s'\n", utflen, unistring);
	}
}
