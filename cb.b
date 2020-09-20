#
#	Checkerboard, (C) 2002 p. Stanley-Marbell
#	pip@gemusehaken.org
#
implement Checkerboard;

include "sys.m";
include "draw.m";
include "bufio.m";
include "arg.m";
include "math.m";
include "imagefile.m";

sys 	: Sys;
bufio	: Bufio;
draw	: Draw;
img	: WImagefile;
arg	: Arg;
math	: Math;

Iobuf	: import bufio;
Image, Point, Display, Screen, Rect : import draw;


Checkerboard : module
{
	init : fn(nil : ref Draw->Context, args : list of string);
};

init(nil : ref Draw->Context, args : list of string)
{
	rows 			: list of string;
	inputfile, outputfile 	: string;			# stdin/stdout by default
	outfilebuf, infilebuf 	: ref Iobuf;		
	boxwidth, boxheight 	: int = 1;		# Scalars for height/width
	nrows, ncols 		: int = 0;
	logrith	: int = 0;
	colorldepth := Draw->CMAP8;
	colorfactor		:= Draw->Black;


	sys 		= load Sys Sys->PATH;
	draw 	= load Draw Draw->PATH;
	img 		= load WImagefile WImagefile->WRITEGIFPATH;
	bufio 	= load Bufio Bufio->PATH;
	arg 		= load Arg Arg->PATH;
	math	= load Math Math->PATH;

	arg->init(args);
	arg->setusage("cb [-c] [-l] [-i infile] [-o outfile] [-w boxwidth] [-h boxheight]");

	img->init(bufio);

	while((c := arg->opt()) != 0)
	{
		case c
		{
			'i' => inputfile = arg->earg();
			'o' => outputfile = arg->earg();
			'w' => boxwidth = int arg->earg();
			'h' => boxheight = int arg->earg();
			'c' => colorfactor = 1; colorldepth = Draw->RGB24;
			'l' => logrith = 1;
			*   => arg->usage();
		}
	}
	if (arg->argv() != nil)
	{
		arg->usage();
	}


	#		Read in the '1' and '0's input:
	if (inputfile == nil)
	{
		inputfile = "stdin";
		infilebuf = bufio->fopen(sys->fildes(0), Sys->OREAD);
	}
	else
	{
		infilebuf = bufio->open(inputfile, Sys->OREAD);
	}

	if (infilebuf == nil)
	{
		sys->print("Could not open [%s] for reading : %r\n",
			inputfile);
		exit;
	}

	while ((buf := infilebuf.gets('\n')) != nil)
	{
		(tmp, nil) := sys->tokenize(buf, " \t");
		ncols = max(ncols, tmp);
		rows = buf::rows;
	}
	nrows = len rows;
	rows = reverse(rows);


	#		Draw the boxes:
	ZP := Point(0, 0);
	display := Display.allocate(nil);

	outimage := display.newimage(
				Rect(
					ZP, 
					(ncols*boxwidth, nrows*boxheight)
				),  
				colorldepth, 
				0, 
				Draw->White
			);

	for (i := 0; i < nrows; i++)
	{
		(nil, bits) := sys->tokenize(hd rows, " \t");

		for (j := 0; bits != nil; j++)
		{
			boxcolor := int hd bits;
			if (logrith != 0)
			{
				boxcolor = int math->log1p(real boxcolor);
			}

			boxrect := Rect((j*boxwidth, i*boxheight), 
					((j+1)*boxwidth, (i+1)*boxheight));
			boximage := display.newimage(boxrect, colorldepth, 0,
					boxcolor*colorfactor);
			outimage.draw(outimage.r, boximage, nil, ZP);
			bits = tl bits;
		}

		rows = tl rows;
	}


	#		Output images as a GIF:
	if (outputfile == nil)
	{
		outputfile = "stdout";
		outfilebuf = bufio->fopen(sys->fildes(1),  Sys->OWRITE);
	}
	else
	{
		(there, nil) := sys->stat(outputfile);
		if (there == -1)
		{
			if (sys->create(outputfile, Sys->OWRITE, 8r644) == nil)
			{
				sys->print("Could not create output file [%s] : %r\n",
					outputfile);
				exit;
			}
		}

		outfilebuf = bufio->open(outputfile, Sys->OWRITE);
	}

	if (outfilebuf == nil)
	{
		sys->print("Could not open [%s] for writing : %r\n",
			outputfile);
		exit;
	}

	img->writeimage(outfilebuf, outimage);
	

	return;
}

max(a, b : int) : int
{
	if (a > b)
		return a;
	return b;
}

reverse(f : list of string) : list of string
{
	r : list of string;
                
	while (f != nil)
	{
		r = hd f::r;
		f = tl f;
	}
                
	return r;
}
