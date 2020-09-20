implement Esd;

include "sys.m";
include "draw.m";
include "math.m";
include "arg.m";
include "esd.m";

sys		: Sys;
arg		: Arg;
math		: Math;
Connection	: import Sys;

Esd : module
{
	init : fn(nil : ref Draw->Context, nil : list of string);
};

SAME, DIFFERENT : con 1 << iota;
port		:= ESD_PORT;
debug		:= 1;
pgrp		: int;
client_endian	:= SAME;

init(nil : ref Draw->Context, args : list of string)
{
	sys = load Sys Sys->PATH;
	arg = load Arg Arg->PATH;
        math = load Math Math->PATH;
	if (arg == nil || math == nil)
	{
		raise sys->sprint("err: could not load %s : %r", Arg->PATH+"and "+Math->PATH);
	}
	arg->init(args);
	arg->setusage("esd [-p port]");

	pgrp = sys->pctl(sys->NEWPGRP, nil);

	while((c := arg->opt()) != 0)
	{
		case c
		{
			'p'	=> port = int arg->earg();
             		*	=>
				arg->usage();
				exit;
		}
	}

	(n, conn) := sys->announce("tcp!*!"+string port);
	if (n < 0)
	{
		sys->print("Esd : announce failed : %r\n");
		exit;
	}

	while (1)
	{
		listen(conn);
	}
}

listen(conn : Connection)
{
	buf := array [sys->ATOMICIO] of byte;
	
	(ok, c) := sys->listen(conn);
	if (ok < 0)
	{
		error(sys->sprint("Listen failed : %r\n"));
	}

	rfd := sys->open(conn.dir + "/remote", Sys->OREAD);
	n := sys->read(rfd, buf, len buf);
	spawn hdlrthread(c);


	return;
}

hdlrthread(conn : Connection)
{
	buf := array [sys->ATOMICIO] of byte;

	#	The connections data file is not opened by default,
	#	must explicitly do so to accept the new connection
	rdfd := sys->open(conn.dir + "/data", Sys->OREAD);
	wdfd := sys->open(conn.dir + "/data", Sys->OWRITE);
	rfd := sys->open(conn.dir + "/remote", Sys->OREAD);

	#	The client IP is now available, once we have accepted connection.
	#	The following will print the actual client IP address:
	iplen := sys->read(rfd, buf, len buf);
	debugprint(sys->sprint("Got new connection from %s",
			string buf[:iplen]));

	#	Read Key. BUG: Currently ignore the key sent
	keylen := sys->read(rdfd, buf, ESD_KEY_LEN);
	if (keylen != ESD_KEY_LEN)
	{
		error(sys->sprint("Runt key from client, length %d",
			keylen));
	}
	debugprint("client sent key :"+string buf[:keylen]);

	#	Read Endianness.
	endianlen := sys->read(rdfd, buf, ESD_ENDIAN_LEN);
	if (endianlen != ESD_ENDIAN_LEN)
	{
		error(sys->sprint("Runt endianess from client, length %d",
			endianlen));
	}
	debugprint("client sent endian: "+string buf[:endianlen]);
	if (int buf[0] == 'N')
	{
		client_endian = DIFFERENT;
	}

	#	Send response
	debugprint("About to write response to client...");
	if (sys->write(wdfd, scrub(OPCODE_RESPONSE), ESD_OPCODE_LEN) !=
		ESD_OPCODE_LEN)
	{
		error(sys->sprint("Could not write response to client: %r"));
	}
	debugprint("Wrote response to client...");

	#	Currently only accept "stream" writes. Read the opcode type from client
	oplen := sys->read(rdfd, buf, ESD_OPCODE_LEN);
	if (oplen != ESD_OPCODE_LEN)
	{
		error(sys->sprint("Runt opcode from client, length %d",
			oplen));
	}
		
	scrub(buf[:ESD_OPCODE_LEN]);	
	if (buf[0] == OPCODE_STREAM[0] && buf[1] == OPCODE_STREAM[1] &&
		buf[2] == OPCODE_STREAM[2] && buf[3] == OPCODE_STREAM[3])
	{
		debugprint("got a stream opcode...");
		#	Read and configure format and rate
		if (sys->read(rdfd, buf, ESD_FMT_LEN+ESD_RATE_LEN) != ESD_FMT_LEN+ESD_RATE_LEN)
		{
			error("Runt read getting format and rate from client");
		}
		configure_audio(scrub(buf[:ESD_FMT_LEN]), scrub(buf[ESD_FMT_LEN:ESD_FMT_LEN+ESD_RATE_LEN]));

		#	Read and discard name. Don't support Esd sample playing etc.
		if (sys->read(rdfd, buf, ESD_NAME_LEN) != ESD_NAME_LEN)
		{
			error("Runt read getting stream name from client");
		}

		#afd := sys->open("/tmp/junk.data", Sys->OWRITE);
		afd := sys->open("/dev/audio", Sys->OWRITE);
		if (afd == nil)
		{
			error(sys->sprint(
				"Could not open /dev/audio for writing: %r"));
		}
	
		#
		#	Read actual sound data and write to audio device.
		#	Writes are done in units smaller than ATOMICIO due 
		#	to some strange things occuring on large writes.
		#	Not yet sure who's the culprit.
		#
		chunklen := sys->read(rdfd, buf, 1024);
		while(chunklen != 0)
		{
			if (sys->write(afd, buf[:chunklen], chunklen) != chunklen)
			{
				error(sys->sprint(
					"Could not write %d bytes to /dev/audio: %r",
					chunklen));
			}
			debugprint(sys->sprint("wrote %d bytes to /dev/audio", chunklen));
			chunklen = sys->read(rdfd, buf, 1024);
		}
	}
	else
	{
		sys->sprint("Unknown opcode from client, %d%d%d%d",
			int buf[0], int buf[1], int buf[2], int buf[3]);
	}


	return;
}

#	Scrub() rearranges the byte order. Scrub is used
#	both taking the return value, or knowing it acts
#	on array reference.
scrub(data : array of byte) : array of byte
{
	if (client_endian == SAME)
	{
		return data;
	}

	for (i := 0; i < len data/2; i++)
	{
		tmp1 := int data[i];
		tmp2 := int data[len data - i - 1];

sys->print("\n\n%d --> %d\n", tmp1, tmp2);

		data[i] = byte tmp2;
		data[len data - i - 1] = byte tmp1;
	}
	
	return data;
}

configure_audio(fmt : array of byte, rate: array of byte)
{
	debugprint("ignoring config info, hope you don't mind");
}

debugprint(s: string)
{
	if (debug)
	{
		sys->print("Esd::DEBUG %s\n", s);
	}

	return;
}

error(s: string)
{
	raise "fail: Esd:: "+s;

	exit;
}

