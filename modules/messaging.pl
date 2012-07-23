#Sending messages in irssi
#this is necessary in case the bot issues commands. 
sub message_own_public {
	my ($server, $text, $target) = @_;
	message_public( $server, $text, $server->{nick}, "localhost", $target );
}

sub send_msg {
	my ($server, $target, $text) = ($_[0], $_[1], join(' ', @_[2..$#_]));
	return unless defined $text && $text ne '';
	Irssi::timeout_add_once(50, sub { $server->command("MSG $target $text") }, undef);
}
#Made a special one for weather because I wanted it to Notice, instead of msg. 
#can probably find a different way to do this with some time. 
sub send_msg_weather {
	my ($server, $target, $text, $commandtype) = @_;
	return unless defined $text && $text ne '';
	if ($commandtype eq 'MSG') {
		Irssi::timeout_add_once(50, sub { $server->command("MSG $target $text") }, undef);
	}
	else {
		Irssi::timeout_add_once(50, sub { $server->command("NOTICE $target $text") }, undef);
	}
}

1; #return true