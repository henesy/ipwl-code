#
#	Matches: prints the number of occurrences of each character in
#	the supplied string argument. It is useful for debugging files
#	in, e.g. LaTeX when you're missing some matching parens.
# 
#	(C) 2003 p. Stanley-Marbell
#
#	TODO: read stdin
#
implement Matches;

include "sys.m";
include "draw.m";
include "arg.m";
include "bufio.m";

Matches : module
{
	init : fn(nil : ref Draw->Context, nil : list of string);
};

init(nil : ref Draw->Context, args : list of string)
{
	sys := load Sys Sys->PATH;
	bufio := load Bufio Bufio->PATH;
	Iobuf: import bufio;
	arg := load Arg Arg->PATH;

	arg->init(args);
	arg->setusage("matches <runes> filename");

	if (len args != 3)
		arg->usage();

	matches := hd tl args;

	counts := array [len matches] of { * => big 0 };

	filename := hd tl tl args;

	reader := bufio->open(filename, bufio->OREAD);
	if(reader == nil)
		raise sys->sprint("err: could not open %s - %r", filename);

	for(;;){
		r := reader.getc();
		if(r <= 0)
			break;
		
		for(i := 0; i < len matches; i++)
			if(matches[i] == r)
				counts[i]++;
				
	}

	for (i := 0; i < len matches; i++)
		sys->print("%c\t%bd occurences\n", matches[i], counts[i]);

	reader.close();

	exit;
}
