#
#	PortScanner, (C) 2003 p. Stanley-Marbell
#	pip@gemusehaken.org
#
implement PortScanner;

include "sys.m";
include "draw.m";
include "arg.m";
#include "rfc1700.m";

arg	: Arg;
sys	: Sys;


PortScanner : module
{
	init : fn(nil : ref Draw->Context, args : list of string);
};

init(nil : ref Draw->Context, args : list of string)
{
        sys = load Sys Sys->PATH;
	arg = load Arg Arg->PATH;
	if (arg == nil)
	{
		raise sys->sprint("Could not load %s : %r", Arg->PATH);
	}

	arg->init(args);
	arg->setusage("portscanner [-b start port] [-e end port] hostname");

	#	Defaults
	begin := 1;
	end := 65535;
	delay := 10;

	while((c := arg->opt()) != 0)
	{
		case c
		{
			'b' => begin = int arg->earg();
			'e' => end = int arg->earg();
			'd' => delay = int arg->earg();
             		*   =>
				arg->usage();
		}
	}

	if (len (args = arg->argv()) != 1)
		arg->usage();

	hostname := hd args;
	portchan := chan of (int, string);
	nports := 1 + (end-begin);

	n := 0;

	spawn tcpscan(portchan, begin, end, delay, hostname);

	loop:
	for(;;)
		alt {
		(ok, addr) := <- portchan =>
			if(ok)
				sys->print("Open: %s\n", addr);
		n++;
		if(n >= nports)
			break loop;

		* =>
			sys->sleep(delay);
		}

	exit;
}

# Dispatch processes to connect to ports
tcpscan(portchan: chan of (int, string), begin, end, delay : int, hostname : string)
{
	for (i := begin; i <= end; i++)
	{
		addr := "tcp!"+hostname+"!"+(string i);

		spawn scan(portchan, addr);
		
		sys->sleep(delay);
	}

}

# Scan a port
scan(portchan: chan of (int, string), addr: string) {
	(ok, nil) := sys->dial(addr, nil);
	if (ok >= 0)
		portchan <-= (1, addr);
	else
		portchan <-= (0, nil);
}
