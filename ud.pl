# urban Dictionary script
# If you like this check out more at ratherwute.com
# Wayne - wayne@ratherwute.com
use v5.10;
use strict;
use warnings;
use LWP::UserAgent;
use Mojo::DOM;
my $ua = LWP::UserAgent->new;
$ua->agent("libwww-perl/6.02");

sub send_msg {

	my ($server, $target, $text) = ($_[0], $_[1], join(' ', @_[2..$#_]));
	return unless defined $text && $text ne '';
	Irssi::timeout_add_once(50, sub { $server->command("MSG $target $text") }, undef);
}
sub message_public {

	my ($server, $text, $nick, $addr, $target) = @_;
	my @cmd = split /\s+/, $text;
	given ($cmd[0]) {
  		when ('~ud') { # checking
			if (!$cmd[1]) {
				my $str = "Please include a word or phrase.";
				send_msg($server, $target, $str);
			}
			else {
				my $entry;
				my $indexsize = scalar(@cmd);
				my $term = join("+",splice(@cmd,1,$indexsize));
				my $url = 'http://www.urbandictionary.com/define.php?term='.$term;
				my $content = $ua->get($url);
				my $html = $content->content;
				my $dom = Mojo::DOM->new;
				$dom->parse($html);
				if ($dom->at('#entries')) {
					$entry = substr($dom->at('#entries')->all_text, 0, 350).'... (http://www.urbandictionary.com/define.php?term='.$term.')';
				}
				else {
					$term =~ s/\+/ /g;
					$entry = "$term has not been defined on Urban Dictionary";
				}
				send_msg($server, $target, $entry);
			}
		}
	}
}

Irssi::signal_add_last("message public", \&message_public);
return 1;