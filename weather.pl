# Weather Script
# If you like this check out more at ratherwute.com
# Wayne - wayne@ratherwute.com
use v5.10;
use strict;
use warnings;
use LWP::UserAgent;

my $ua = LWP::UserAgent->new;
$ua->agent('Mozilla/5.0');
my $ctemp = '';

sub get_weather {
	my (@cmd)  = @_;
	my $str;
	if (!$cmd[1]) {
		$str = "Please try ~weather zipcode/city,country";
	}
	if ($cmd[1] eq "help") {
		$str = "Use it like this: ~weather zipcode or ~weather city,country";
		$str .= " If the city has a space in it, use an underscore.  i.e., ~weather San_Diego,California";
	}
	$ua->timeout(10);
	my $url = 'http://38.102.136.104/auto/raw/'.$cmd[1];
	my $results = $ua->get($url);
	my @badarray = split(/[|]\s*/, $results->content);
	if (!$results->is_success) {
		$str = "Sorry, no weather available for your location, For help and formatting use: ~weather help";
	}
	elsif (!$badarray[0]) {
		$str = "Sorry, no weather available for your location, For help and formatting use: ~weather help";
	}
	else {
		my @goodarray = split(/[|]\s*/, $results->content);
		if ($goodarray[1] eq "") { 
			$str = "\002Conditions for $goodarray[18], $goodarray[19] at $goodarray[0]:\002 $goodarray[8] \002Temp:\002 $goodarray[1] F \002Humidity:\002 $goodarray[4] \002Barometer:\002 $goodarray[7] \002Wind:\002 $goodarray[6] mph";
		}
		else {
			my $ctemp = sprintf( "%4.1f", ($goodarray[1] - 32) * (5 / 9) );
			$str = "\002Conditions for $goodarray[18], $goodarray[19] at $goodarray[0]:\002 $goodarray[8] \002Temp:\002 $goodarray[1] F/$ctemp C \002Humidity:\002 $goodarray[4] \002Barometer:\002 $goodarray[7] \002Wind:\002 $goodarray[6] mph";
		}

	}
	return $str;
}		

sub send_msg {
	my ($server, $target, $text, $commandtype) = @_;
	return unless defined $text && $text ne '';
	if ($commandtype eq 'MSG') {
		Irssi::timeout_add_once(50, sub { $server->command("MSG $target $text") }, undef);
	}
	else {
		Irssi::timeout_add_once(50, sub { $server->command("NOTICE $target $text") }, undef);
	}
}

sub message_public {
	my ($server, $text, $nick, $addr, $target) = @_;
	my @cmd = split /\s+/, $text;

	given ($cmd[0]) {

  		when ('~weather') { # weather private msg
			my $commandtype = "notice";
			send_msg($server, $nick, get_weather(@cmd), $commandtype);
		}
		when ('@weather') { # weather public msg
			my $commandtype = "MSG";
			send_msg($server, $target, get_weather(@cmd), $commandtype);
		}
		when ('%weather') { # DerTauman harrassment
			my $commandtype = "MSG";
			my $dertauman = "DerTauman";
			send_msg($server, $dertauman, get_weather(@cmd), $commandtype);
		}
	}
  
}

sub message_own_public {
	my ($server, $text, $target) = @_;
	message_public( $server, $text, $server->{nick}, "localhost", $target );
}

Irssi::signal_add_last("message public", \&message_public);
Irssi::signal_add_last("message own_public", \&message_own_public);