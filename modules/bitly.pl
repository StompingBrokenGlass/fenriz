#Bit.ly api script
#this is for passing some long URL's into a much smaller format.

#This grabs a bit.ly url for the long last.fm url it works if you want to uncomment it.
#use your own login and key
#bit.ly keeps going down so i'm disabling it.

sub bitly {
	my ($url) = @_;
	#this strips out the odd characters in the url.
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
		#since for some reason Bit.ly uses the given url as a key reference (why i have no idea)
		#we have to grab the key so we can use the key later to get the shorturl. 
		my %decoded_hash = %{$decoded_content->{'results'}};
		my @bigurl = keys %decoded_hash;
		#here is where we use that key value.  Stupid innit?
		my $tinyurl = $decoded_content->{'results'}{$bigurl[0]}{'shortUrl'};
		return "(".$tinyurl.")";
	}
}
return 1; #return true