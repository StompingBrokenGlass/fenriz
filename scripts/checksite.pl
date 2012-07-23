#Checksite script. 
#scrapes downforeveryoneorjustme.com to see if website is up. 
sub checksite {
	my ($server, $target, $cmd) = @_;
	if (!$cmd[1]) {
		my $str = "Please include a website. i.e., ~checksite google.com.";
		send_msg($server, $target, $str);
	}
	else {
		my $ua = LWP::UserAgent->new;
		$ua->agent('Mozilla/5.0');
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
return 1; #return true