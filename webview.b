implement WebView;

include "sys.m";
	sys	: Sys;
	FD: import sys;

include "draw.m";

include "url.m";
	url	: Url;
	ParsedUrl: import url;

include "html.m";
include	"arg.m";
include "string.m";


webgrab	: Webgrab;
str	: String;
html	: HTML;
arg	: Arg;

debug	: int;
FMTWIDTH: con 60;

WebView : module
{
	init : fn(ctxt : ref Draw->Context, args : list of string);
};

#Webgrab : module
#{
#	init : fn(ctxt : ref Draw->Context, args : list of string);
#	httpget : fn(u: ref Url->ParsedUrl) : 
#		(string, array of byte, ref Sys->FD, ref Url->ParsedUrl);
#	readconfig : fn();
#};

Webgrab: module
{
	init: fn(ctxt: ref Draw->Context, args: list of string);
	httpget: fn(u: ref ParsedUrl) : (string, array of byte, ref Sys->FD, ref ParsedUrl);
	readconfig: fn();
};


init(ctxt : ref Draw->Context, args : list of string)
{
	body : string;


	sys = load Sys Sys->PATH;

	(there, nil) := sys->stat("/net/cs");
	if (there == -1)
	{
		cs := load WebView "/dis/lib/cs.dis";
		if (cs == nil)
		{
			raise sys->sprint("Could not load /dis/lib/cs.dis : %r");
		}
		cs->init(nil, nil);
	}

	webgrab = load Webgrab "/dis/webgrab.dis";
	if (webgrab == nil)
	{
		raise sys->sprint("Could not load /dis/webgrab.dis : %r");
	}
	webgrab->init(ctxt, "init"::nil);
	webgrab->readconfig();

	str = load String String->PATH;
	if (str == nil)
	{
		raise sys->sprint("Could not load %s : %r", String->PATH);
	}

	html = load HTML HTML->PATH;
	if (html == nil)
	{
		raise sys->sprint("Could not load %s : %r", HTML->PATH);
	}

	url = load Url Url->PATH;
	if (url == nil)
	{
		raise sys->sprint("Could not load %s : %r", Url->PATH);
	}
	url->init();

	arg = load Arg Arg->PATH;
	if (arg == nil)
	{
		raise sys->sprint("Could not load %s : %r", Arg->PATH);
	}
	arg->init(args);

	while((c := arg->opt()) != 0)
	{
		case c
		{
			'd' => debug = 1;
             		*   =>
			{
				sys->print("usage : webview [-d] <URIs>\n");
				exit;
			}
		}
	}
	args = arg->argv();

	while (args != nil)
	{
		u := url->makeurl(hd args);

		if (debug)
		{
			sys->print("Calling webgrab with URL: %s\n", u.tostring());
		}

		(err, bytes, fd, realurl) := webgrab->httpget(u);

		if (debug)
		{
			sys->print("webgrab returned:\n\terr: \"%s\"\n\tbytes: %s\n",
				err, string bytes);

			if((fd != nil) && (realurl != nil))
			{
				sys->print("\tfd: %d\n\turl: %s\n",
					fd.fd, realurl.tostring());
			}
		}

		if (fd != nil)
		{
			buf := array[Sys->ATOMICIO] of byte;
			while((n := sys->read(fd, buf, len buf)) > 0)
			{
				body = body + string buf[:n];
			}
		}

		if (debug)
		{
			sys->print("Lookup from [%s]\n", realurl.tostring());
		}

		munch((string bytes)+body);

		args = tl args;
		body = nil;
	}
}

munch(body : string)
{
	nrecords : int = 1;
	block : string;

	(nlines, lines) := sys->tokenize(sys->sprint("%s", body), "\n");

	if(debug)
	{
		sys->print("Got %d lines\n", nlines);
	}

	while (lines != nil)
	{
		sys->print("\n");

		while (lines != nil)
		{
			block = block + hd lines;
			lines = tl lines;
		}

		htmltxtprint(block);
		block = nil;
	}

	sys->print("\n");
}

htmltxtprint(s : string)
{
	index 	:= 0;
	inli 	:= 0;

	tokens := html->lex(array of byte s, HTML->Latin1, 0);
	for (i := 0; i < len tokens; i++)
	{
		text := tokens[i].text;

		# sys->print("text = [%s], index = [%d], len text = [%d]\n", 
		# text, index, len text);

		if (tokens[i].tag == HTML->Data)
		{
			strlen := len text;
			if ((index + strlen) >= FMTWIDTH)
			{
				(nil, sl) := sys->tokenize(text, " \t");
				while (sl != nil)
				{
					index += len (hd sl);
					if (index >= FMTWIDTH)
					{
						sys->print("\n");
						if (inli)
							sys->print("\t");

						index = 0;
					}

					sys->print("%s ", hd sl);
					sl = tl sl;
				}

				sys->print("\n");
				if (inli)
					sys->print("\t");

				index = 0;
			}
			else
			{
				sys->print("%s ", text);

				index += len text;
				if (index >= FMTWIDTH)
				{
					sys->print("\n");
	
					if (inli)
						sys->print("\t");

					index = 0;
				}
			}
		}

		if (tokens[i].tag == HTML->Tli)
		{
			sys->print("\n\n\t");
			index = 0;
			inli = 1;
		}
		else if(tokens[i].tag == HTML->Tli+HTML->RBRA)
		{
			inli = 0;
		}
		else if (html->isbreak(tokens[i:i+1], 0))
		{
			sys->print("\n");
			index = 0;
		}
	}
}
