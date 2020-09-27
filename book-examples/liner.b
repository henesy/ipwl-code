#
#       Software from the book "Inferno Programming with Limbo"
#       published by John Wiley & Sons, January 2003.
#
#       p. Stanley-Marbell <pip@gemusehaken.org>
#
implement Liner;

include "sys.m";
include "draw.m";
include "bufio.m";
include "arg.m";

sys : Sys;
bufio : Bufio;
Iobuf : import bufio;
                
Liner : module
{
	init : fn(ctxt : ref Draw->Context, argv : list of string);
};

init (nil : ref Draw->Context, argv : list of string)
{
	sys = load Sys Sys->PATH;
	bufio = load Bufio Bufio->PATH;
	arg := load Arg Arg->PATH;

	arg->init(argv);
	arg->setusage("liner filename ⋯");

	while((c := arg->opt()) != 0)
		case c {
		* => arg->usage();
		}

	argv = arg->argv();
	if(len argv < 1)
		arg->usage();

	param := argv;
	while (param != nil)
	{
		liner(hd param);

		param = tl param;
	}
}

liner(filename : string)
{             
	file_buf := bufio->open(filename, sys->OREAD);
	stdout := bufio->fopen(sys->fildes(1), sys->OWRITE);
	for(i := 0; ; i++) {
		line := file_buf.gets('\n');
		if (line == "")
			break;
		else
			stdout.puts(string i +"\t"+ line);
	}

	stdout.flush();
	stdout.close();
	file_buf.close();
}
