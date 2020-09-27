#
#       Software from the book "Inferno Programming with Limbo"
#       published by John Wiley & Sons, January 2003.
#
#       p. Stanley-Marbell <pip@gemusehaken.org>
#
implement StyxServer;

include "sys.m";
include "draw.m";
include "arg.m";
include "styx.m";
include	"styxlib.m";

sys		: Sys;
arg		: Arg;
styx		: Styx;
styxlib		: Styxlib;

Styxserver, Rmsg, Tmsg, Dirtab, Chan: import styxlib;

mntflg		:= Sys->MREPL;
mntpt		:= "/n/remote/";
numoranges	: int;
Qmax		: con 1024;
QSHIFT		: con 4;
Qroot, Qorange, Qnew, Qctl, Qdate, Qtime, Qline : con iota;
perms		:= array [Qmax] of {Qnew to Qtime => 8r400, * => 8r755};
mtimes		:= array [Qmax] of int;
atimes		:= array [Qmax] of int;
lengths 	:= array [Qmax] of int;

StyxServer : module
{
	init : fn(nil : ref Draw->Context, args : list of string);

	dirgen: fn(srv: ref Styxlib->Styxserver, c: ref Styxlib->Chan,
		tab: array of Styxlib->Dirtab, i: int): (int, Sys->Dir);
};

init(nil : ref Draw->Context, args : list of string)
{
	sys = load Sys Sys->PATH;
	styxlib = load Styxlib Styxlib->PATH;
	styx = load Styx Styx->PATH;
	arg = load Arg Arg->PATH;
	arg->init(args);

	while((c := arg->opt()) != 0)
	{
		case c
		{
			'b' => mntflg = Sys->MBEFORE;
			'a' => mntflg = Sys->MAFTER;
			'r' => mntflg = Sys->MREPL;
			'c' => mntflg |= Sys->MCREATE;
             		*   =>
			{
				sys->print("Usage : styxserver [-rabc] <mount point>\n");
				exit;
			}
		}
	}
	args = arg->argv();

	if (len args != 1)
	{
		sys->print("Usage : styxserver [-rabc] <mount point>\n");
		exit;
	}
	mntpt = hd args;

	styxpipe := array [2] of ref Sys->FD;
	sys->pipe(styxpipe);
	(tmsgchan, srv) := Styxserver.new(styxpipe[0]);

	sync := chan of int;
	spawn server(tmsgchan, srv, sync);
	<-sync;

	if (sys->mount(styxpipe[1], mntpt, mntflg, nil) < 0)
	{
		raise sys->sprint("fail:StyxServer mount failed : %r");
	}
}

server(tmsgchan : chan of ref Styxlib->Tmsg, srv : ref Styxserver,
	sync : chan of int)
{
	devgen := load Dirgenmod "$self";

	sync <-= 0;
	while ()
	{
		msg := <-tmsgchan;
		if (msg == nil)
		{
			exit;
		}

		pick m := msg
		{
			Readerror =>
			{
				raise sys->sprint("fail:Styxserver error reading Styx pipe : %r");
			}

			Nop	=>	srv.reply(ref Rmsg.Nop(m.tag));
			Attach	=>	srv.devattach(m);
			Clone	=>	srv.devclone(m);
			Clunk	=>	srv.devclunk(m);
			Create	=>	srv.reply(ref Rmsg.Error(m.tag,Styxlib->Eperm));
			Flush	=>	srv.devflush(m);
			Open	=>	srv.devopen(m, devgen, nil);

			Read	=>
			{
				c := srv.fidtochan(m.fid);

				if (c == nil)
				{
					srv.reply(ref Rmsg.Error(m.tag,Styxlib->Eperm));
					break;
				}

				if (c.isdir())
				{
					srv.devdirread(m, devgen, nil);
					break;
				}

				if (c.qid.path == Qnew)
				{
					if (((numoranges << QSHIFT) + Qline) < Qmax)
					{
						numoranges++;
					}

					srv.reply(ref Rmsg.Read(m.tag, m.fid, nil));

					break;
				}

				srv.reply(ref Rmsg.Error(m.tag,Styxlib->Eperm));
			}

			Remove	=>	srv.reply(ref Rmsg.Error(m.tag,Styxlib->Eperm));
			Stat	=>	srv.devstat(m, devgen, nil);
			Walk	=>	srv.devwalk(m, devgen, nil);
			Write	=>	srv.reply(ref Rmsg.Error(m.tag,Styxlib->Eperm));
			Wstat	=>	srv.reply(ref Rmsg.Error(m.tag,Styxlib->Eperm));
		}
	}
}

dirgen(nil : ref Styxserver, c : ref Chan, nil : array of Dirtab,
	entry : int) : (int, Sys->Dir)
{
	level := c.qid.path & ((1 << QSHIFT) - 1);

	#	Top level directory, say /n
	if (level == Qroot)
	{
		if (entry == 0)
		{
			return (1, packdir("orange", Qorange, Sys->CHDIR, 0));
		}
	}

	#	Second level directory, say, /n/orange
	if (level == Qorange)
	{
		if (entry == 0)
		{
			return (1, packdir("new", Qnew, 0, 0));
		}
		else if (entry <= numoranges)
		{
			which := entry - 1;
			return (1, packdir(sys->sprint("%d", which),
					Qline|(which<<QSHIFT), Sys->CHDIR, 0));
		}
	}

	#	Third level directory, say, /n/orange/5
	if (level == Qline)
	{
		line := (c.qid.path&~Sys->CHDIR) >> QSHIFT;

		case(entry)
		{
			0 =>	return (1, packdir("ctl", Qctl, 0, line));
			1 =>	return (1, packdir("date", Qdate, 0, line));
			2 =>	return (1, packdir("time", Qtime, 0, line));
		}
	}

	return (-1, packdir(nil, 0, 0, 0));
}

packdir(name : string, Q, dirflag, line : int) : Sys->Dir
{
	qid : Sys->Qid;

	qid.vers = 0;
	qid.path = Q;
	qid.path |= line << QSHIFT;
	qid.path |= dirflag;

	return Sys->Dir (name,
			"pip",
			"pip",
			qid,
			perms[Q] | (qid.path & Sys->CHDIR),
			atimes[Q],
			mtimes[Q],
			lengths[Q],
			'O',
			'O');
}
