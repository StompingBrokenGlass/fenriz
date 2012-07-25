use Irssi;
use v5.10;
use strict;
use warnings;
use feature ':5.10';
use LWP::UserAgent;
use List::MoreUtils qw{uniq};
use Encode;
use Carp;
use JSON;
use Mojo::DOM;
binmode STDOUT, ":utf8";
use vars qw($VERSION %IRSSI);
$VERSION = '1.00';
%IRSSI = (
    authors     => 'Wayne aka kwamaking',
    contact     => 'wayne@ratherwute.com',
    name        => 'Fenriz: Irssi utility bot',
    description => 'Utility bot for Irssi ' .
                   'with last.fm support' ,
    license     => 'Public Domain',
);
#varoius included scripts
do $ENV{"HOME"}."/fenriz/scripts/urbandict.pl";
do $ENV{"HOME"}."/fenriz/scripts/lastfm.pl";
do $ENV{"HOME"}."/fenriz/scripts/weather.pl";
do $ENV{"HOME"}."/fenriz/scripts/checksite.pl";
do $ENV{"HOME"}."/fenriz/scripts/help.pl";
#messaging module sends data to irssi
do $ENV{"HOME"}."/fenriz/modules/messaging.pl";
#bit.ly url shortner api
do $ENV{"HOME"}."/fenriz/modules/bitly.pl";
#required for some of the last.fm commands
our $nick_user_map;
our $user_nick_map = {}; # derived from $nick_user_map
#this is the main sub that grabs commands from the window.
#some commands are sent to subs on the included files above
sub message_public {
	my ($server, $text, $nick, $addr, $target) = @_;
	my @cmd = split /\s+/, $text;
	given ($cmd[0]) {
		when (m/\~checksite/i) { #using a regex to ignore case on commands
			checksite($server, $target, @cmd);
		}
		when (m/\~weather/i) { # weather private msg
			my $commandtype = "notice";
			send_msg_weather($server, $nick, get_weather(@cmd), $commandtype);
		}
		when (m/\@weather/i) { # weather public msg
			my $commandtype = "MSG";
			send_msg_weather($server, $target, get_weather(@cmd), $commandtype);
		}
		when (m/\~ud/i) {
			urbandict($server, $target, @cmd);
		}
		when (m/\~help/i) {
			help($server, $target, $nick, @cmd);
		}
		#Last.fm commands, this is a huge set. 
		when (m/\~np/i) { # now playing
			send_msg($server, $target, now_playing($nick, 1, @cmd));
			write_cache();
		}
		when (m/\~top/i) { # top artists
			send_msg($server, $target, usertopartists($nick, 1, @cmd));
		}
		when (m/\~band/i) { # Get band
			send_msg($server, $target, getArtist($nick, 1, @cmd));
		}
		when (m/\~false/i) { # checks if user is a false. 
			send_msg($server, $target, userfalse($nick, 1, @cmd));
		}
		when (m/\~plays/i) { # checks user plays of given artist. 
			send_msg($server, $target, userPlays($nick, 1, @cmd));
		}
		when ("911") { # bring on the metal police 
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
		when (m/\~MANOWAR/i) { # no mas manowar 
			my $str = "Move along";
			send_msg($server, $target, $str);
		}
		when (m/\amirite\?/i) { # ya u rite
			my $str = "ya u rite";
			send_msg($server, $target, $str);
		}
		when (m/\faggot/i) { # kick the poseurs 
			Irssi::timeout_add_once(50, sub { $server->command("KICK $target $nick leave the hall") }, undef);
		}
		when (m/\~compare/i) { # tasteometer comparison
			#created sub routine because it's more involved in lastfm.pl
			startcompare($server, $text, $nick, $addr, $target, @cmd);
        }
		when (m/\~setuser/i) {
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
					write_cache();
				} else {
					send_msg($server, $target, "Could not find the '$username' last.fm account.");
				}
			}
		}
		when (m/\~deluser/i) {
			my $ircnick = $nick eq $server->{nick} ? ($cmd[1] // $nick) : $nick;
			my $username = $$nick_user_map{$ircnick};
			if ($username) {
				delete $$user_nick_map{$username}{$ircnick};
				delete $$nick_user_map{$ircnick};
				del_cache('accountless', $username) if get_cache('accountless', $username);
				send_msg($server, $target, "Removed the mapping for '$ircnick'");
				write_cache();
			} elsif (get_cache('accountless', $ircnick)) {
				del_cache('accountless', $ircnick);
				send_msg($server, $target, "Removed $ircnick from invalid account cache");
				write_cache();
			} else {
				send_msg($server, $target, "Mapping for '$ircnick' doesn't exist");
			}
		}
		when (m/\~whois/i) {
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
	}
}

#I don't know why these are necessary, but irssi documentation insists on it. 
Irssi::signal_add_last("message public", \&message_public);
Irssi::signal_add_last("message own_public", \&message_own_public);
