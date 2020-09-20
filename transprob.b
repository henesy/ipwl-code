#
#	Transprob, (C) 2002 p. Stanley-Marbell <pip@gemusehaken.org>
#
#	Reads in a file contaning numbers, and outputs a table of the 
#	transition probabilities of going from one value to another.
#
#	Example:
#
#		transprob -c 2 -s '0,1,2,3,4,5,6,7,8' -f q.data
#
#	This will output the transition probability matrix for values
#	in the second column of the file q.data going from all
#	combinations of 0..8 to 0..8.
#
#	TODO: handle stdin input and do -o output
#
implement Transprob;

include "sys.m";
include "draw.m";
include "bufio.m";
include "arg.m";
include "math.m";

sys	: Sys;
draw	: Draw;
arg	: Arg;
bufio	: Bufio;

Iobuf	: import bufio;

states	: array of int;
nstates : int = 0;

Transprob : module
{
	init : fn(nil : ref Draw->Context, args : list of string);
};

init(nil : ref Draw->Context, args : list of string)
{
	curstate, prevstate	: int;
	column			: int = 0;
	inputfile		: string;
	statelist		: list of string;
	maxtrans		: int = -1;


	sys = load Sys Sys->PATH;
	arg = load Arg Arg->PATH;
	bufio = load Bufio Bufio->PATH;

	stderr := sys->fildes(2);
	if (arg == nil || bufio == nil)
	{
		sys->print("Could not load Bufio/Arg modules : %r\n");
		exit;
	}

	arg->init(args);
	arg->setusage("transprob [-s states] [-c col] [-f infile] [-m max]");

	while((c := arg->opt()) != 0)
	{
		case c
		{
			's' =>
			{
				tmp := arg->earg();
				(nstates, statelist) = sys->tokenize(tmp, ",");
				states = array [nstates] of int;
				for (i := 0; i < nstates; i++)
				{
					states[i] = int hd statelist;
					statelist = tl statelist;
				}
			}

			'c' => column = int arg->earg();
			'f' => inputfile = arg->earg();
			'm' => maxtrans = int arg->earg(); 
			*   => arg->usage();
		}
	}
	args = arg->argv();

	sys->fprint(stderr, "Column [%d] specified\n", column);
	sys->fprint(stderr, "input file is [%s]\n", inputfile);
	sys->fprint(stderr, "There were [%d] states specified\n", nstates);

	filebuf := bufio->open(inputfile, Bufio->OREAD);
	if (filebuf == nil)
	{
		sys->print("Could not open [%s] : %r\n", inputfile);
		exit;
	}

	probmatrix := array [nstates] of {* => array [nstates] of {* => 0}};
	
	ntrans := 0;
	while ((line := filebuf.gets('\n')) != nil)
	{
		prevstate = curstate;

		(nil, tokens) := sys->tokenize(line, " \t");
		for (i := 0; (i < column) && (tokens != nil); i++)
		{
			curstate = int hd tokens;
			tokens = tl tokens;
		}

		if (ntrans != 0)
		{
			probmatrix[idx(prevstate)][idx(curstate)]++;
		}
		ntrans++;

		if (maxtrans != -1 && ntrans >= maxtrans)
		{
			break;
		}
	}

	sum := 0.0;
	for (i := 0; i < nstates; i++)
	{
		rowsum := 0;
		j := 0;

		for (j = 0; j < nstates; j++)
		{
			rowsum += probmatrix[i][j];
		}

		for (j = 0; j < nstates; j++)
		{
			sys->print("%f ", (real probmatrix[i][j])/
					((real rowsum) + Math->MachEps));
			sum += (real probmatrix[i][j])/
                                        ((real rowsum) + Math->MachEps);
		}
		sys->print("\n");
	}
	sys->print("Sum of entries in trans prob matrix is [%f]\n", sum);

	return;
}

idx(state : int) : int
{
	for (i := 0; i < nstates; i++)
	{
		if (states[i] == state)
		{
			return i;
		}
	}

	#	Could not find state ?
	sys->print("Error: i know nothing of state [%d]. Exiting...\n", state);
	exit;

	return 0; # ha!
}


