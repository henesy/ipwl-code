#
#	ESD Audio device. Serves /dev/audio and /dev/audioctl, and
#	sends received audio to an Esound daemon, either local or
#	somewhere on the network. Esound is the Enlightenment sound
#	"thingy", and is available as a server application on many
#	Unices. This program negotiates the ESD protocol etc.
#
#	/dev/audio accepts audio data. /dev/audioctl accepts a 
#	restricted set of the usual Inferno audio header commands:
#
#		rate n
#			Where n is the sampling rate. E.g., 44100,
#			22050, 8000, etc.
#
#		chans n
#			Where n is'1' for mono and '2' for stereo
#
#		bits n
#			Bits per sample. Valid values for n are '8' 
#			and '16'
#
#		enc e
#			Where e is the encoding method. This is 
#			currently not supported.
#
#		The device defaults to 16 bit samples, 44.1KHz, stereo
#
#		BUGS: we should mimic /dev/audioctl exactly.
#
#	This software copyright 2003 Phillip Stanley-Marbell
#		Contact: pip@gemusehaken.org, pstanley@ece.cmu.edu
#
implement EsdAudioDev;

include "sys.m";
include "draw.m";
include "arg.m";
include "esd.m";

EsdAudioDev : module
{
	init : fn(nil : ref Draw->Context, nil : list of string);
};

sys	: Sys;
arg	: Arg;

#	Defaults
hostname	:= "localhost";
port		:= 16001;
binddir		:= "/dev";
debug		:= 1;
current_format	: array of byte;
current_rate	: array of byte;
current_name	: array of byte;
current_chans	:= 2;
current_bits	:= 16;

pgrp		: int;
esdresetchan	: chan of int;

init(nil : ref Draw->Context, args : list of string)
{
	sys = load Sys Sys->PATH;
	arg = load Arg Arg->PATH;
	if (arg == nil)
	{
		raise sys->sprint("Could not load %s : %r", Arg->PATH);
	}

	arg->init(args);
	arg->setusage("esdaudiodev [-p port] [-d directory] [-h hostname]");

	pgrp = sys->pctl(sys->NEWPGRP, nil);

	while((c := arg->opt()) != 0)
	{
		case c
		{
			'p'	=> port = int arg->earg();
			'd'	=> binddir = string arg->earg();
			'h'	=> hostname = string arg->earg();
             		*	=>
				arg->usage();
		}
	}

	current_format	= FMT_16BIT_STEREO_STREAM;
	current_rate	= RATE_44100;
	current_name	= ESD_NAME;

	sys->bind("#s", binddir, sys->MBEFORE);
	datachanref := sys->file2chan(binddir, "audio");
	ctlchanref := sys->file2chan(binddir, "audioctl");

	if (datachanref == nil || ctlchanref == nil)
	{
		sys->print("EsdAudioDev:: Couldn't create chan file in %s : %r\n",
			binddir);
		exit;
	}

	spawn dataworker(datachanref);
	spawn ctlworker(ctlchanref);


	return;
}

dataworker(chanref : ref sys->FileIO)
{
	esddatachan := chan of array of byte;
	esdresetchan = chan of int;
	spawn esdconnect(esddatachan, esdresetchan);

	while (1)
	alt
	{
		#	For now, ignore reads
		(off, nbytes, fid, rc) := <-chanref.read =>
		{
			if (rc == nil) break;

			#	Finished serving contents of data[]
			rc <-= (nil, "");
		}

		(offset, writedata, fid, wc) := <-chanref.write =>
		{
			if (wc == nil)
			{
				break;
			}

			esddatachan <- = writedata;
			wc <-= (len writedata, "");
		}
	}
}

ctlworker(chanref : ref sys->FileIO)
{
	index 	:= 0;
	data	: array of byte;


	while (1)
	alt
	{
		(off, nbytes, fid, rc) := <-chanref.read =>
		{
			if (rc == nil) break;
			
			if (index == 0)
			{
				data = array of byte 
					("rate "+string current_rate+"\n"+
					"chans "+string current_chans+"\n"+
					"bits "+string current_bits+"\n");
			}
			
			if (index < len data)
			{
				end := min(index+nbytes, len data);
				rc <-= (data[index:end], "");
				index = end;
			}
			else
			{
				#	Finished serving contents of data[]
				rc <-= (nil, "");
				index = 0;
			}
		}

		(offset, writedata, fid, wc) := <-chanref.write =>
		{
			if (wc == nil)
			{
				break;
			}

			wc <-= (len writedata, "");
			debugprint(string writedata);

			if (string writedata[:len "quit"] == "quit")
			{
				fd := sys->open("#p/"+string pgrp+"/ctl",
					sys->OWRITE);
				if (fd != nil)
				{
					sys->fprint(fd, "killgrp");

					#	Killgrp into ctl doesn't cause suicide, so:
					exit;
				}
				else
				{
					raise "fail: EsdAudioDev: could not terminate";
				}
			}

			if (string writedata[:len "rate"] == "rate")
			{
				(nil, l) := sys->tokenize(string writedata, " ");
				rate := hd tl l;

				if (int rate <= 0)
				{
					error("bogus sampling rate supplied");
					continue;
				}

				debugprint(sys->sprint("setting sampling rate to [%d]",
					int rate));
				current_rate = array [] of {byte ((int rate>>24)&16rFF),
				byte ((int rate>>16)&16rFF),
				byte ((int rate>>8)&16rFF),
				byte ((int rate>>0)&16rFF)};
				esdresetchan <-= 1;
			}

			if (string writedata[:len "chans"] == "chans")
			{
				(nil, l) := sys->tokenize(string writedata, " ");
				chans := hd tl l;

				if (int chans < 1 || int chans > 2)
				{
					error("bogus # of channels supplied");
					continue;
				}

				debugprint(sys->sprint("setting sampling chans to [%d]",
					int chans));
				current_chans = int chans;
				reset_format();
				esdresetchan <-= 1;
			}

			if (string writedata[:len "bits"] == "bits")
			{
				(nil, l) := sys->tokenize(string writedata, " ");
				bits := hd tl l;

				if (int bits != 8 && int bits != 16)
				{
					error("bogus sample #bits supplied");
					continue;
				}

				debugprint(sys->sprint("setting sampling #bits to [%d]",
					int bits));
				current_bits = int bits;
				reset_format();
				esdresetchan <-= 1;
			}
		}
	}
}

esdconnect(esddatachan : chan of array of byte, esdresetchan : chan of int)
{
	reply := array [ESD_OPCODE_LEN] of byte;
	n := 0;

	(ok, conn) := sys->dial("tcp!"+hostname+"!"+string port, nil);
	if (ok < 0)
	{
		error("error: could not connect to server");
	}
	debugprint(sys->sprint("connected to host %s...", hostname));
	

#	#	Send initial connect opcode. This seems to be valid only
#	#	for JEsd and not for the regular Esd:
#	n = sys->write(conn.dfd, OPCODE_INIT, ESD_OPCODE_LEN);
#	if (n != ESD_OPCODE_LEN)
#	{
#		error("could not write OPCODE_INIT");
#	}
#	debugprint(sys->sprint("wrote [%d] bytes to server", n));

	#	Send ESD key
	n = sys->write(conn.dfd, ESD_KEY, ESD_KEY_LEN);
	if (n != ESD_KEY_LEN)
	{
		error("could not write ESD_KEY");
	}
	debugprint(sys->sprint("wrote [%d] bytes to server", n));

	#	Send Endianness
	n = sys->write(conn.dfd, ESD_ENDIAN, ESD_ENDIAN_LEN);
	if (n != ESD_ENDIAN_LEN)
	{
		error("could not write ESD_ENDIAN");
	}
	debugprint(sys->sprint("wrote [%d] bytes to server", n));
	debugprint("sent initial init messages. about to read response....");

#	#	Get connect response
#	n = sys->read(conn.dfd, reply, len reply);
#
#	if (int reply[0] != 1)
#	{
#		error("server responded negatively on init sequence");
#	}
#	debugprint(
#		sys->sprint(
#		"server responded with [%d] bytes, value of first byte is [%d]",
#		n, int reply[0]));

	#	Send any received data as a stream
	debugprint("about to loop on receive stream / write to server...");
	while (1)
	alt
	{
		data := <- esddatachan =>
			n = sys->write(conn.dfd, OPCODE_STREAM, ESD_OPCODE_LEN);
			if (n != ESD_OPCODE_LEN)
			{
				error("could not write OPCODE_STREAM");
			}
			n = sys->write(conn.dfd, current_format, len current_format);
			if (n != len current_format)
			{
				error("could not write current_format");
			}
			n = sys->write(conn.dfd, current_rate, len current_rate);
			if (n != len current_rate)
			{
				error("could not write current_rate");
			}
			n = sys->write(conn.dfd, current_name, len current_name);
			if (n != len current_name)
			{
				error("could not write current_name");
			}


			n = sys->write(conn.dfd, data, len data);
			if (n != len data)
			{
				error("could not write data read from channel");
			}

		<- esdresetchan =>
			reply = nil;
			conn.dfd = nil;
			esdconnect(esddatachan, esdresetchan);
	}
}

reset_format()
{
	if (current_chans == 1)
	{
		if (current_bits == 8)
		{
			current_format	= FMT_8BIT_MONO_STREAM;
		}
		else if (current_bits = 16)
		{
			current_format	= FMT_16BIT_MONO_STREAM;
		}
	}
	else if (current_chans == 2)
	{
		if (current_bits == 8)
		{
			current_format	= FMT_8BIT_STEREO_STREAM;
		}
		else if (current_bits = 16)
		{
			current_format	= FMT_16BIT_STEREO_STREAM;
		}
	}

	return;
}

error(err: string)
{
	fd := sys->open(binddir+"/ctl", sys->OWRITE);
	if (fd != nil)
	{
		sys->fprint(fd, "error: %s", err);
	}
	else
	{
		raise "fail: EsdAudioDev: could not write to ctl file";
	}

	return;
}

debugprint(s: string)
{
	if (debug)
	{
		sys->print("EsdAudioDev::DEBUG %s\n", s);
	}

	return;
}

min (a, b : int) : int
{
	if (a < b)
		return a;
	return b;
}

