#
#       Software from the book "Inferno Programming with Limbo"
#       published by John Wiley & Sons, January 2003.
#
#       p. Stanley-Marbell <pip@gemusehaken.org>
#
implement Pong;

include "sys.m";
include "draw.m";
include "keyring.m";
include "security.m";
include "daytime.m";
include "rand.m";

sys : Sys;
draw : Draw;
rand : Rand;
daytime : Daytime;

Display, Screen, Image, Rect, Point, Font: import draw;

MAXSPEED	: con 3;
INITGAMEDELAY	: con 30;

ZP		:= (0,0);

gamedelay	: int = INITGAMEDELAY;
gameover	: int = 0;
leftscore, rightscore : int = 0;
leftpaddlerect	: Rect;
rightpaddlerect	: Rect;
scoreboxrect	: Rect;
ballimage	: ref Image;
ballwin		: ref Image;
ballrect	: ref Rect;
scorebox	: ref Image;
font		: ref Font;
kbdpid		: int;

Pong : module
{
	init : fn(ctxt : ref Draw->Context, args : list of string);
};

init(ctxt : ref Draw->Context, nil : list of string)
{
	kbdchan		:= chan of int;
	cmdchan		:= chan of int;
	paddlespeed	:= 10;
	display 	: ref Display;
	gamescreen	: ref Screen;
	leftpaddle	: ref Image;
	rightpaddle	: ref Image;


	sys = load Sys Sys->PATH;
	draw = load Draw Draw->PATH;
	daytime = load Daytime Daytime->PATH;
	random := load Random Random->PATH;
	rand = load Rand Rand->PATH;
	rand->init(random->randomint(Random->ReallyRandom));

	if (ctxt == nil)
	{
		display = Display.allocate(nil);
		if (display == nil)
		{
			raise sys->sprint("fail:Cannot initialize display : %r");
		}
	}
	else
	{
		display = ctxt.display;
	}

	ballimage = display.open("ball.bit");
	if (ballimage == nil)
	{
		sys->print("Cannot read ball.bit : %r");
		exit;
	}

	spawn kbd(kbdchan);

	font = Font.open(display, "*default*");
	leftpaddlerect = Rect((0, 0), (10, 100));
	rightpaddlerect = Rect((display.image.r.dx() - 10, 0),
				(display.image.r.dx(), 100));
	scoreboxrect = Rect((display.image.r.dx() - 110, 10),
				(display.image.r.dx() - 20, 30));

	#	The game screen is a public screen
	gamescreen = Screen.allocate(display.image, 
			display.rgb(147, 221, 0), 1);
	if (gamescreen == nil)
	{
		raise sys->sprint("fail:Cannot allocate gamescreen on display : %r");
	}

	#	Paint the display black
	display.image.draw(display.image.r, display.rgb(147, 221, 0),
		display.ones, display.image.r.min);

	#	Draw the scorebox
	scorebox = gamescreen.newwindow(scoreboxrect, Draw->Red);
	scorebox.draw(scoreboxrect, scorebox, scorebox,
			scoreboxrect.min);

	#	Draw the paddles
	leftpaddle = gamescreen.newwindow(leftpaddlerect, Draw->Black);
	rightpaddle = gamescreen.newwindow(rightpaddlerect, Draw->Black);

	leftpaddle.draw(leftpaddlerect, leftpaddle, leftpaddle,
			leftpaddlerect.min);
	rightpaddle.draw(rightpaddlerect, rightpaddle, rightpaddle,
			rightpaddlerect.min);

	#	Initial score
	updatescore();

	#	Spawn a new thread to handle ball
	spawn	pongball(gamescreen, cmdchan);

	while (!gameover)
	{
		case (c := <- kbdchan)
		{
			'q'	=>
			{
				gameover = 1;
				cmdchan <- = 'q';
				endsplash(display);

				exit;
			}
			'x'	=>
			{
				leftpaddlerect = leftpaddlerect.addpt(
					(0, paddlespeed));
				leftpaddle.origin(ZP, leftpaddlerect.min);
			}
			'c'	=>
			{
				leftpaddlerect = leftpaddlerect.subpt(
						(0, paddlespeed));
				leftpaddle.origin(ZP, leftpaddlerect.min);
			}
			'a'	=>
			{
				rightpaddlerect = rightpaddlerect.addpt(
						(0, paddlespeed));
				rightpaddle.origin(ZP, rightpaddlerect.min);
			}
			's'	=>
			{
				rightpaddlerect = rightpaddlerect.subpt(
						(0, paddlespeed));
				rightpaddle.origin(ZP, rightpaddlerect.min);
			}
		}
	}
}

pongball(gamescreen : ref Screen, cmdchan : chan of int)
{
	vector		: ref Point;
	midx		: int = 0;


	midx = gamescreen.image.r.dx()/2;
	ballrect = ref Rect((midx, 0),
			(midx+ballimage.r.dx(), ballimage.r.dy()));
	ballwin = gamescreen.newwindow(*ballrect,
			Draw->Yellow);
	ballwin.draw(ballwin.r, ballimage, 
			nil, ballimage.r.min);
	vector = ref Point(rand->rand(MAXSPEED)+1,
			rand->rand(MAXSPEED)+1);

top:	while (1)
	alt
	{
		cmd := <-cmdchan =>
		{
			break top;	
		}

		* =>
		if (!(sys->millisec() % gamedelay))
		{
			if ((leftscore == 100) || (rightscore == 100))
			{
				endsplash(scorebox.display);
				gameover = 1;

				break top;
			}	
			moveball(gamescreen, vector);
			ballwin.origin(ZP, ballrect.min);
		}
	}
}

moveball(gamescreen : ref Screen, vector : ref Point)
{
	*ballrect = (*ballrect).addpt(*vector);

	#	If we hit bottom or top, reflect y-axis
	if ((ballrect.max.y >= gamescreen.image.r.max.y) ||
		(ballrect.min.y <= gamescreen.image.r.min.y))
	{
		*vector = (vector.x, -vector.y);
		return;
	}

	#	If we hit a paddle, reflect y-axis
	if (((*ballrect).Xrect(leftpaddlerect)) || 
		((*ballrect).Xrect(rightpaddlerect)))
	{
		*vector = (-vector.x, vector.y);
		return;
	}

	if (ballrect.max.x >= gamescreen.image.r.max.x)
	{
		leftscore++;
		updatescore();
		resetball(gamescreen, vector);
	}
	else if (ballrect.min.x <= gamescreen.image.r.min.x)
	{
		rightscore++;
		updatescore();
		resetball(gamescreen, vector);
	}
}

resetball(gamescreen : ref Screen, vector : ref Point)
{
	midx := gamescreen.image.r.dx()/2;
	ballrect = ref Rect((midx, 0), 
			(midx+ballimage.r.dx(), ballimage.r.dy()));

	ballwin.origin(ZP, ballrect.min);

	invert := 1;
	if (rand->rand(2))
	{
		invert = -1;  
	}

	*vector = Point(invert*(rand->rand(MAXSPEED)+1),
			rand->rand(MAXSPEED)+1);
}

updatescore()
{
	scorestring := sys->sprint("L %2d: R %2d",
			leftscore, rightscore);
	textbox := scorebox.r.inset(5);
	
	#	Wipe the scoreboard
	scorebox.draw(scorebox.r, scorebox.display.color(Draw->Red),
			scorebox.display.ones, scorebox.r.min);
	
	#	Re-draw
	scorebox.text(textbox.min, scorebox.display.color(Draw->White),
			(0, 0), font, scorestring);
	scorebox.draw(scorebox.r, scorebox, scorebox.display.ones, 
			scorebox.r.min);		
}

endsplash(display : ref Display)
{
	font = Font.open(display, "/fonts/lucida/unicode.32.font");
	if (font == nil)
	{
		sys->print("Could not load font : %r");
		return;
	}

	display.image.text(display.image.r.inset(display.image.r.dx()/3).min,
			display.color(Draw->Green), 
			(0, 0), font, "Game Over");

	display.image.draw(display.image.r, display.image,
			display.ones, display.image.r.min);

	fd := sys->open("#p/"+string kbdpid+"/ctl", sys->OWRITE);
	if (fd != nil)
	{
		sys->fprint(fd, "kill");
	}
}

kbd(kbdchan : chan of int)
{
	buf := array [1] of byte;

	#	Since this thread blocks on sys calls to read(), we will
	#	have to kill it forcefully when the game ends:
	kbdpid = sys->pctl(0,nil);

	kfd := sys->open("/dev/keyboard", sys->OREAD);
	if (kfd == nil)
	{
		raise sys->sprint("fail:Could not open /dev/cons : %r");
	}

	while (sys->read(kfd, buf, 1) == 1)
	{
		kbdchan <-= int buf[0];
	}
	raise sys->sprint("fail:Could not read from /dev/cons or ctxt.ckbd: %r");
}
