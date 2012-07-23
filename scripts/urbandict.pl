#UrbanDictionary script
#this uses Mojo::DOM rather than their API
#will be using their json soap api soon. 
sub urbandict {
	my ($server, $target, @cmd) = @_;
	if (!$cmd[1]) {
		my $str = "Please include a word or phrasez.";
		send_msg($server, $target, $str);
	}
	else {
		my $ua = LWP::UserAgent->new;
		$ua->agent("libwww-perl/6.02");
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

return 1; #return true