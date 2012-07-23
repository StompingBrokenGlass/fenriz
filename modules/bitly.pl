#Bit.ly api script
#this is for passing some long URL's into a much smaller format.

#This grabs a bit.ly url for the long last.fm url it works if you want to uncomment it.
#use your own login and key
#bit.ly keeps going down so i'm disabling it.

sub bitly {
	my $url = shift;
	my $lwp = LWP::UserAgent->new;
	$lwp->agent("Perl::Bitly/1.0");
	#bit.ly user login and API key	
	my $api_login = "kwamaking";
	my $api_key = "R_37f6ef3f9c212cdd28f22bf515240b69";
	my $api_src = "http://api.bit.ly/shorten?longUrl=".$url."&login=".$api_login."&apiKey=".$api_key;
	my $response = $lwp->get($api_src);
	my $raw_data = $response->decoded_content;
	foreach my $line (split(/\n/,$raw_data))
	{
		if ($line =~ m/shortURL/i)
		{
			my @url_bitly = split(/([{}\s\"])shortUrl/,$line);
			my @lil_bitly = split(/\"/,$url_bitly[2]);
			$str .= "(". $lil_bitly[2] .")";
			last;
		}
	}
	return $str;
}
return 1; #return true