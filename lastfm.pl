use v5.10;
use strict;
use warnings;
use feature ':5.10';

use LWP::UserAgent;
use List::MoreUtils qw{uniq};
use Encode;
use Carp;
use JSON;

binmode STDOUT, ":utf8";

#last.fm API key
our $api_key = 'put your api key here';
our $nick_user_map;
our $user_nick_map = {}; # derived from $nick_user_map
our $api_cache = {};
if( open my $cachefile, '<', 'lastfm_cache.json' ) {
	$api_cache = decode_json(scalar <$cachefile>);
	$nick_user_map = get_cache('mappings', 'nick_user');
	build_nick_map();
	close $cachefile;
}
$nick_user_map //= {};

sub build_nick_map {
	return unless $nick_user_map;
	for my $nick (keys %$nick_user_map) {
		next if $nick eq '#expire';
		my $user = $$nick_user_map{$nick};
		my $map = $$user_nick_map{$user} //= {};
		$$map{$nick} = 1;
	}
}

sub _delete_if_expired($$) {
	my ($hash, $key) = @_;
	return undef unless $hash && $key;
	my $item = $$hash{$key};
	return undef unless defined $item;

	# backwards compatibility
	delete $$hash{$key} && return undef unless $$item{'#expire'};

	if ($item && $$item{'#expire'} > 0 && $$item{'#expire'} < time) {
		delete $$hash{$key};
		return undef;
	}
	return $item;
}

sub clean_cache {
	for my $cache (values %$api_cache) {
		for (keys %$cache) {
			_delete_if_expired $cache, $_;
		}
	}
}

sub _text($) {
	my $tag = shift;
	return undef unless defined $tag;
	return $$tag{'#text'} if ref $tag;
	return $tag;
}

sub del_cache {
	croak "Insufficient arguments" unless @_ >= 2;
	my ($subcache, $key) = @_;
	die "Invalid cache $subcache" unless defined $subcache;
	$$api_cache{$subcache} //= {};
	delete $$api_cache{$subcache}{$key};
}

sub get_cache {
	croak "Insufficient arguments" unless @_ >= 2;
	my ($subcache, $key) = @_;
	die "Invalid cache $subcache" unless defined $subcache;
	my $cache = $$api_cache{$subcache} //= {};

	return undef unless defined $key;
	return _delete_if_expired $cache, $key;
}

sub upd_cache {
	my $cache = get_cache(@_);
	return $cache if $cache;
	return set_cache(@_);
}

sub set_cache {
	croak "Insufficient arguments" unless @_ >= 3;
	my ($subcache, $key, $value, $expire) = @_;
	die "Invalid cache $subcache" unless defined $subcache;
	my $cache = $$api_cache{$subcache} //= {};
	$expire //= 3600*24*7 * 10; # 1 week by default

	return undef unless defined $key;
	if( ref $value eq 'CODE' ) { # JSON can't store code; evaluate
		my @res = $value->();
		$value = @res > 1 ? [@res] : $res[0];
	}

	if( ref $value eq 'HASH' ) {
		$$cache{$key} = $value;
	} else {
		$$cache{$key} = { '#text' => $value };
	}

	if($expire > 0) {
		$$cache{$key}{'#expire'} = (time) + $expire;
	} else {
		$$cache{$key}{'#expire'} = -1;
	}

	return $$cache{$key};
}

sub write_cache {
	clean_cache;
	set_cache('mappings', 'nick_user', $nick_user_map, -1);
	open my $cachefile, '>', 'lastfm_cache.json';
	syswrite $cachefile, encode_json($api_cache);
	close $cachefile;
}

our $ua = LWP::UserAgent->new;
$ua->timeout(10);

our $prevreqtime;
our $lastreqtime;
our $reqcount = 0;

sub _clean($) {
	$_ = encode_utf8(shift);
	s/ /+/g;
	s/([^-A-Za-z0-9+])/%@{[sprintf "%2X", ord $1]}/g;
	return $_;
}

sub artist_gettoptags { # for artist.gettoptags API call
	my $res = shift;
	my $name = $$res{arid} ? $$res{arid} : $$res{artist};
	my $tag = 'artist.gettoptags';
	return upd_cache($tag, $name, sub {
		get_last_fm_data($tag, $$res{arid} ? 'mbid' : 'artist',  $name);
	});
}

sub get_last_fm_data {
	my $method = shift;
	my %params;
	if( $_[0] && ref $_[0] eq 'HASH' ) {
		%params = @{$_[0]};
	} else {
		my $_ = { @_ };
		%params = %$_;
	}

	my @paramary = map { join "=", _clean $_, _clean $params{$_} } keys %params;
	my $paramstr = scalar(@paramary) ? ("&". (join "&", @paramary)) : "";

	$lastreqtime = time;
	$prevreqtime //= $lastreqtime;
	sleep 1 if ($lastreqtime == $prevreqtime && $reqcount >= 5);
	if( $lastreqtime != $prevreqtime ) {
		$reqcount = 0;
	} else {
		$reqcount++;
	}
	my $resp = $ua->get("http://ws.audioscrobbler.com/2.0/?format=json&api_key=$api_key&method=$method$paramstr");
	return decode_json $resp->content if $resp->is_success;
	undef;
}

sub usercompare {
	my @user = @_[0,1];

	my $str = "'$user[0]' vs '$user[1]': ";
	my $data = get_last_fm_data( 'tasteometer.compare', type1 => 'user', type2 => 'user',
	                                                    value1 => $user[0], value2 => $user[1] );
	return "Error comparing $user[0] with $user[1]" unless $data && $$data{comparison}{result};
	my $res = $$data{comparison}{result};
	$str .= (sprintf "%2.1f", $$res{score} * 100) ."%";
	if( $$res{artists}{artist} && $$res{artists}{'@attr'}{matches} ) {
		$str .= " - Common artists include: ";
		$str .= join ", ", map { $$_{name} } (ref $$res{artists}{artist} eq 'ARRAY' ? @{$$res{artists}{artist}} : $$res{artists}{artist});
	}
	return $str;
}
sub nick_map($) {
	my $nick = shift;
	return $$nick_user_map{$nick} // $nick
}
#Some users requested this, so I added it. 
sub usertopartists {
	my ($nick, $ignerr, @cmd) = @_;
	my $user = $cmd[1] ? $cmd[1] : $nick;
	$user = nick_map $user;
	if ($cmd[1]) {
		$user = $cmd[1];
		$user = nick_map $user;
	}
	my $cached = get_cache('accountless', $user);
	return $ignerr ? _text $cached : undef if $cached;
	my $data = get_last_fm_data( 'user.gettopartists', limit => 8, user => $user, period => '7day');
	return  "$user either doesn't exist or has no recent top artists" unless $data && $$data{topartists}{artist};
	my $toptracks = join ", ", map { $$_{name} } (ref $$data{topartists}{artist} eq 'ARRAY' ? @{$$data{topartists}{artist}} : $$data{topartists}{artist});
	my $str = "Recent top artists of '$user': ";
	$str .= "(";
	$str .= $toptracks;
	$str .= ")";
	return $str;
}
#This is just a funny addition
#if the user has less than 50 plays of Judas Priest, they are false.
#it's very roughly coded, i am not proud of it. 
sub userfalse {
	my ($nick, $ignerr, @cmd) = @_;
	my $user = $cmd[1] ? $cmd[1] : $nick;
	$user = nick_map $user;
	if ($cmd[1]) {
		$user = $cmd[1];
		$user = nick_map $user;
	}
	my $cached = get_cache('accountless', $user);
	return $ignerr ? _text $cached : undef if $cached;
	my $str;
	my $data = get_last_fm_data( 'artist.getinfo', limit => 1, username => $user, artist => 'Judas Priest');
	return "$user has never listened to Judas Priest.  $user needs to leave the hall." unless $data && $$data{artist}{stats}{userplaycount};
	my $playcount = join ", ", map { $$_{userplaycount} } (ref $$data{artist}{stats} eq 'ARRAY' ? @{$$data{artist}{stats}} : $$data{artist}{stats});
	my $playlimit = 666;
	if ($playcount < $playlimit) {
		my $needed = $playlimit - $playcount;
		$str = "$user has only $playcount Judas Priest plays.  $user is a poseur.  At least $needed additional plays required to be trve.";
	}
	else {
		$str = "$user has $playcount Judas Priest plays.  $user is trve."; 
	}
	return $str;
}
#Returns playcount of given band per user. 
sub userPlays {
	my ($nick, $ignerr, @cmd) = @_;
	my $indexsize = scalar(@_);
	my $artist = join(" ",splice(@_,3,$indexsize));
	my $user = nick_map $nick;
	my $cached = get_cache('accountless', $user);
	return $ignerr ? _text $cached : undef if $cached;
	my $str;
	my $data = get_last_fm_data( 'artist.getinfo', limit => 1, username => $user, artist => $artist, autocorrect => 1);
	return "Last.fm has no record of $artist" unless $data && $$data{artist}{name};
	return "$user has never listened to $artist" unless $data && $$data{artist}{stats}{userplaycount};
	my $playcount = join ", ", map { $$_{userplaycount} } (ref $$data{artist}{stats} eq 'ARRAY' ? @{$$data{artist}{stats}} : $$data{artist}{stats});
	$str = "$user has $playcount ";
	$str .= join("",$$data{artist}{name});
	$str .= " plays.";
	return $str;
}
#gets artist and returns similar and tags. 
sub getArtist {
	my (@cmd) = @_;
	my $indexsize = scalar(@_);
	my $artist = join(" ",splice(@_,3,$indexsize));
	my $data = get_last_fm_data( 'artist.getinfo', limit => 1,  artist => $artist, autocorrect => 1);
	return "Last.fm has no record of $artist" unless $data && $$data{artist}{name};
	my $str = join("",$$data{artist}{name});
	$str .= " have ";
	$str .= join("",$$data{artist}{stats}{playcount});
	$str .= " plays and ";
	$str .= join("",$$data{artist}{stats}{listeners});
	$str .= " listeners.";
	if (ref $$data{artist}{similar} eq "HASH") {
		$str .= "  Similar artists include: (";
		$str .= join ", ", map { $$_{name} } (ref $$data{artist}{similar}{artist} eq 'ARRAY' ? @{$$data{artist}{similar}{artist}} : $$data{artist}{similar}{artist});
		$str .= ")";
	}
	if (ref $$data{artist}{tags} eq "HASH") {
		$str .= " Tags: (";
		$str .= join ", ", map { $$_{name} } (ref $$data{artist}{tags}{tag} eq 'ARRAY' ? @{$$data{artist}{tags}{tag}} : $$data{artist}{tags}{tag});
		$str .= ")";
	}
	return $str;
}
	
sub get_user_np {
	my $user = shift;

	my %res;
	my $data = get_last_fm_data( 'user.getrecenttracks', limit => 1, user => $user );
	my ($prevtime, $prevlen);
	if( $data && (my $tracks = $$data{recenttracks}{track}) ) {
		my @tracks = (ref $tracks eq 'ARRAY' ? @$tracks : $tracks);
		for( @tracks ) {
			my $info = get_last_fm_data( 'track.getinfo', username => $user,
			                              $$_{mbid} ? 'mbid' : 'track', $$_{mbid} ? $$_{mbid} : $$_{name},
			           $$_{mbid} ? () : (artist => _text $$_{artist}));
			if( $$_{'@attr'}{nowplaying} ) {
				$res{name}   = $$_{name};
				$res{artist} = _text $$_{artist};
				$res{arid}   = $$_{artist}{mbid} if ref $$_{artist};
				$res{album}  = _text $$_{album} if $$_{album};
				$res{alid}   = $$_{album}{mbid} if ref $$_{album};
				$res{mbid}   = $$_{mbid} if $$_{mbid} && !ref $$_{mbid};
				$res{url}    = $$_{url};
				my $tags = artist_gettoptags(\%res);
				$res{tags} = [map { $$_{name} } grep { $$_{count} } (ref $$tags{toptags}{tag} eq 'ARRAY' ? @{$$tags{toptags}{tag}} : $$tags{toptags}{tag})] if $tags;
				$res{tags} = [grep { defined && !($_ ~~ ['touhou', 'anime']) } @{$res{tags}}[0..4]];
				pop @{$res{tags}} until @{$res{tags}} <= 4;

				$res{len}   = ($$info{track}{duration} // 0) / 1000; # miliseconds
				$res{loved} = $$info{track}{userloved};
				$res{count} = $$info{track}{userplaycount} if $$info{track}{userplaycount};
			} elsif ($$info{track}{duration} && $$_{date} && $$_{date}{uts}) {
				$prevlen  = $$info{track}{duration};
				$prevtime = $$_{date}{uts} - $prevlen;
			}
		}
		unless ($res{name}) {
			%res = (warn => "'$user' is not listening to anything right now. ". (@tracks < 1 || ref $tracks[0] ne 'HASH' ? "" :
			"The last played track is @{[_text $tracks[0]->{artist}]} - $tracks[0]->{name}, back in @{[_text $tracks[0]->{date}]} UTC."));
		}

		my $now = time;
		if ($res{len} && $prevtime && ($now - $prevtime) <= $res{len}) {
			$res{pos} = $now - $prevtime;
			$res{pos} += $prevlen if $res{pos} < 0;
		}

	} else {
		%res = (error => "User '$user' not found or error accessing his/her recent tracks.");
	}
	return \%res;
}

sub _secs_to_mins {
	my $s = (shift);
	return sprintf "%02d:%02d", $s / 60, $s % 60;
}

sub format_user_np {
	my ($user, $data) = @_;
	my $str = "'$user' is now playing: ";
	$str .= "$$data{artist} - ";
	$str .= "$$data{name} - ";
	$str .= "$$data{album}" if $$data{album};
	if($$data{count}) {
		$str .= " [". ($$data{loved} ? "♥ - " : "") ."playcount $$data{count}x]" ;
	}
	$str .= " (". join( ', ', @{$$data{tags}} ) .")" if $$data{tags} && @{$$data{tags}};
	$str .= " [";
	$str .= _secs_to_mins($$data{pos}) . "/" if $$data{pos};
	$str .= _secs_to_mins($$data{len}) . "] ";
	
	#This grabs a bit.ly url for the long last.fm url it works if you want to uncomment it.
	#use your own login and key
	#bit.ly keeps going down so i'm disabling it.
	#my $lwp = LWP::UserAgent->new;
	#$lwp->agent("Perl::Bitly/1.0");
	#bit.ly user login and API key	
	#my $api_login = "";
	#my $api_key = "";
	#my $url = $$data{url};
	#my $api_src = "http://api.bit.ly/shorten?longUrl=".$url."&login=".$api_login."&apiKey=".$api_key;
	#my $response = $lwp->get($api_src);
	#my $raw_data = $response->decoded_content;
	#foreach my $line (split(/\n/,$raw_data))
	#{
	#	if ($line =~ m/shortURL/i)
	#	{
	#		my @url_bitly = split(/([{}\s\"])shortUrl/,$line);
	#		my @lil_bitly = split(/\"/,$url_bitly[2]);
	#		$str .= "(". $lil_bitly[2] .")";
	#		last;
	#	}
	#}
	if (($user eq "TheRealTauman") && ($$data{artist} eq "Ihsahn")) {
		$str = "DerTauman is touching himself to Ihsahn... Again.";
	}
	return $str;
}

$SIG{INT} = sub { write_cache; exit };

sub send_msg {
	my ($server, $target, $text) = ($_[0], $_[1], join(' ', @_[2..$#_]));
	return unless defined $text && $text ne '';
	Irssi::timeout_add_once(50, sub { $server->command("MSG $target $text") }, undef);
}

sub now_playing {
	my ($nick, $ignerr, @cmd) = @_;
	my $user = $cmd[1] ? $cmd[1] : $nick;
	$user = nick_map $user;

	my $cached = get_cache('accountless', $user);
	return $ignerr ? _text $cached : undef if $cached;

	my $np = get_user_np($user);
	if ($$np{error}) {
		set_cache('accountless', $user, $$np{error});
		return $ignerr ? $$np{error} : undef;
	}
	elsif ($$np{warn}) { return $ignerr ? $$np{warn} : '' }
	else { return format_user_np($user, $np) }
}

sub message_public {
	my ($server, $text, $nick, $addr, $target) = @_;
	my @cmd = split /\s+/, $text;

	my $send = sub {
	};
	given ($cmd[0]) {
		when ('~np') { # now playing
			send_msg($server, $target, now_playing($nick, 1, @cmd));
			write_cache;
		}
		when ('~top') { # top artists
			send_msg($server, $target, usertopartists($nick, 1, @cmd));
			write_cache;
		}
		when ('~band') { # Get band
			send_msg($server, $target, getArtist($nick, 1, @cmd));
			write_cache;
		}
		when ('~false') { # checks if user is a false. 
			send_msg($server, $target, userfalse($nick, 1, @cmd));
			write_cache;
		}
		when ('~plays') { # checks user plays of given artist. 
			send_msg($server, $target, userPlays($nick, 1, @cmd));
			write_cache;
		}
		when ('911') { # bring on the metal police 
			my @nicks = ("BrutalN00dle","kwamaking","Skuld","StompinBroknGlas","Shamed","Mike","thegauntlet","nakedcups","Fenriz","BrutalMobile");
			if (grep {$_ eq $nick} @nicks) {
				my $str = "...........__\_@@\@__";
				my $str2 = "..... ___//___?____\\________";
				my $str3 = "...../--o-METAL-POLICE------@}";
				my $str4 = "....`=={@}=====+===={@}--- ' WHAT SEEMS TO BE THE PROBLEM HERE?";
				send_msg($server, $target, $str);
				send_msg($server, $target, $str2);
				send_msg($server, $target, $str3);
				send_msg($server, $target, $str4);
			}
			elsif ($nick eq "DerTauman") {
				my $str5 = "Calling the police on false pretenses is a crime";
				send_msg($server, $target, $str5);
			}
		}
		when ('MANOWAR') { # no mas manowar 
			my $str = "Move along";
			send_msg($server, $target, $str);
		}
		when ('amirite?') { # ya u rite
			my $str = "ya u rite";
			send_msg($server, $target, $str);
		}
		when ('faggot') { # kick the poseurs 
			Irssi::timeout_add_once(50, sub { $server->command("KICK $target $nick leave the hall") }, undef);
		}
		when ('~compare') { # tasteometer comparison
			unless (@cmd > 1) { send_msg($server, $target, "Command ~compare needs someone to compare to.") }
			else {
				my @users = (@cmd[1,2]);
				unshift @users, $nick unless $cmd[2];
				map { $_ = nick_map $_ } @users[0,1];
				send_msg($server, $target, usercompare(@users));
			}
		}
		when ('~setuser') {
			unless (@cmd > 1) { send_msg($server, $target, "Command ~setuser needs a last.fm username.") }
			elsif($cmd[1] eq $nick) { send_msg($server, $target, "$nick: You already are yourself.") }
			else {
				my $username = $cmd[1];
				my $ircnick = $nick;
				if ($cmd[2]) {
					if ($nick eq $server->{nick}) {
						$username = $cmd[2];
						$ircnick = $cmd[1];
					} else {
						send_msg($server, $target, "You can only associate your own nick. Use ~setuser your_last_fm_username");
						return;
					}
				}
				my $data = get_last_fm_data( 'user.getrecenttracks', limit => 1, user => $username );
				if ($data && $$data{recenttracks}{track}) {
					send_msg($server, $target, "'$ircnick' is now associated with http://last.fm/user/$username");
					$$nick_user_map{$ircnick} = $username;
					$$user_nick_map{$username}{$ircnick} = 1;
					write_cache;
				} else {
					send_msg($server, $target, "Could not find the '$username' last.fm account.");
				}
			}
		}
		when ('~deluser') {
			my $ircnick = $nick eq $server->{nick} ? ($cmd[1] // $nick) : $nick;
			my $username = $$nick_user_map{$ircnick};
			if ($username) {
				delete $$user_nick_map{$username}{$ircnick};
				delete $$nick_user_map{$ircnick};
				del_cache('accountless', $username) if get_cache('accountless', $username);
				send_msg($server, $target, "Removed the mapping for '$ircnick'");
				write_cache;
			} elsif (get_cache('accountless', $ircnick)) {
				del_cache('accountless', $ircnick);
				send_msg($server, $target, "Removed $ircnick from invalid account cache");
				write_cache;
			} else {
				send_msg($server, $target, "Mapping for '$ircnick' doesn't exist");
			}
		}
		when ('~whois') {
			unless (@cmd > 1) {
				send_msg($server, $target, ".whois needs a last.fm username");
				return;
			}
			my $user = $cmd[1];
			my $nick = $$nick_user_map{$user};
			if (my $map = $$user_nick_map{$user}) {
				my @nicks = sort keys %$map;
				my $end = pop @nicks;
				my $list = join ', ', @nicks;
				$list = $list ? "$list and $end" : $end;
				send_msg($server, $target, "$user is also known as $list");
			}
			elsif ($nick) {
				my $map = $$user_nick_map{$nick};
				my @nicks = sort grep { $_ ne $user and $_ ne $nick } keys %$map;
				my $end = pop @nicks;
				my $list = join ', ', @nicks;
				my $main = $list || $end ? " ($nick)" : "";
				$list = $end && $list ? "$list and $end" : $end ? $end : $list ? "" : $nick;
				send_msg($server, $target, "$user$main is also known as $list");
			}
			else {
				send_msg($server, $target, "$user is only known as $user");
			}
		}
		default {
			return;
		}
	}
}

sub message_own_public {
	my ($server, $text, $target) = @_;
	message_public( $server, $text, $server->{nick}, "localhost", $target );
}

Irssi::signal_add_last("message public", \&message_public);
Irssi::signal_add_last("message own_public", \&message_own_public);
return 1;
