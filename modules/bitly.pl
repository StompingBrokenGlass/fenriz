#Bit.ly api script
#this is for passing some long URL's into a much smaller format.

#This grabs a bit.ly url for the long last.fm url it works if you want to uncomment it.
#use your own login and key
#bit.ly keeps going down so i'm disabling it.

sub bitly {
	my ($url) = @_;
	$url =~ s/\+/ /g;
	my $lwp = LWP::UserAgent->new;
	$lwp->agent("Perl::Bitly/1.0");
	$lwp->timeout(5);
	#bit.ly user login and API key	
	my $api_login = "kwamaking";
	my $api_key = "R_37f6ef3f9c212cdd28f22bf515240b69";
	my $api_src = "http://api.bit.ly/shorten?longUrl=".$url."&login=".$api_login."&apiKey=".$api_key;
	my $response = $lwp->get($api_src);
	if (!$response->is_success) { 
		return;
	}
	else {
		my $decoded_content = decode_json($response->content);
		my $tinyurl = $decoded_content->{'results'}{$url}{'shortUrl'};
		return "(".$tinyurl.")";
	}
}
return 1; #return true