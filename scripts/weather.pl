# Weather Script
sub get_weather {
	my @cmd  = @_;
	if (!$cmd[1]) {
		return $str = "Please try ~weather zipcode/city,country";
	}
	if ($cmd[1] eq "help") {
		$str = "Use it like this: ~weather zipcode or ~weather city,country";
		$str .= " If the city has a space in it, use an underscore.  i.e., ~weather San_Diego,California";
		return $str;
	}
	my $ua = LWP::UserAgent->new;
	$ua->agent('Mozilla/5.0');
	my $str;
	my $ctemp;
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
return 1; #return true