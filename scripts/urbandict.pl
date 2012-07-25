#UrbanDictionary script
#this uses Mojo::DOM rather than their API
#will be using their json soap api soon. 
sub urbandict {
	my ($server, $target, @cmd) = @_;
	if (!$cmd[1]) {
		my $str = 'Please include a word or phrase.';
		send_msg($server, $target, $str);
	}
	else {
		my $ua = LWP::UserAgent->new;
		$ua->agent("libwww-perl/6.02");
		my $entry;
		my $indexsize = scalar(@cmd);
		my $term = join("+",splice(@cmd,1,$indexsize));
		my $url = 'http://api.urbandictionary.com/v0/define?term='.$term;
		my $tinyurl = bitly("http://www.urbandictionary.com/define.php?term=$term");
		my $content = $ua->get($url);
		my $decoded_content = decode_json($content->content);
		if ($decoded_content->{'result_type'} ne 'exact') {
			$entry = 'UrbanDictionary: No results found!';
		}
		else {
			$entry = $decoded_content->{'list'}[0]{'word'}.': '.$decoded_content->{'list'}[0]{'definition'}.' Example: '.
			$decoded_content->{'list'}[0]{'example'}.' For more visit: '.$tinyurl;
		}
		send_msg($server, $target, $entry);
	}
}

return 1; #return true