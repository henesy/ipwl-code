#
#	Unroll: unrolls a text file into characters, one per line
#	(C) 2003 p. Stanley-Marbell
#
#	TODO: read stdin by default
#
implement Unroll;

include "sys.m";
include "draw.m";
include "arg.m";
include "bufio.m";

Unroll : module
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
	arg->setusage("unroll filename");

	if (len args != 2)
		arg->usage();

	filename := hd tl args;

	reader := bufio->open(filename, bufio->OREAD);
	if(reader == nil)
		raise sys->sprint("err: could not open %s - %r", filename);

	for(;;){
		r := reader.getc();
		if(r <= 0)
			break;
		
		sys->print("%c\n", r);
	}

	reader.close();

	exit;
}
