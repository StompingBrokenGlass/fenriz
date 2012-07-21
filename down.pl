# Checks if website is down
# If you like this check out more at ratherwute.com
# Wayne - wayne@ratherwute.com
use v5.10;
use strict;
use warnings;
use LWP::UserAgent;

my $ua = LWP::UserAgent->new;
$ua->agent('Mozilla/5.0');

sub send_msg {

	my ($server, $target, $text) = ($_[0], $_[1], join(' ', @_[2..$#_]));
	return unless defined $text && $text ne '';
	Irssi::timeout_add_once(50, sub { $server->command("MSG $target $text") }, undef);
}
sub message_public {

	my ($server, $text, $nick, $addr, $target) = @_;
	my @cmd = split /\s+/, $text;

	given ($cmd[0]) {

  		when ('~checksite') { # checking
			if (!$cmd[1]) {
				my $str = "Please include a website. i.e., ~checksite google.com.";
				send_msg($server, $target, $str);
			}
			else {
				my $url = 'http://downforeveryoneorjustme.com/'.$cmd[1];
				my $content = $ua->get($url);
				if($content->content =~ m/It's just you./i) {
					my $str = "$cmd[1] is up and running.";
					send_msg($server, $target, $str);
				}
				 else {
					my $str = "It's not just you, $cmd[1] is down.";
					send_msg($server, $target, $str);
				}
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