#!/usr/bin/perl -I/home/masterarbeit/software

###
# Bildschirm leeren
###
print "\033[2J";    #clear the screen
print "\033[0;0H"; #jump to 0,0

###
# Bibliothek einbinden
###
use lib "/home/masterarbeit/software";
use strict;

###
# Installationsanweisungen für benötige Module
###	
# perl -MCPAN -e 'force install "URI"'
# perl -MCPAN -e 'force install "AnyEvent"'		
# perl -MCPAN -e 'force install "Data::Dumper"'	
# perl -MCPAN -e 'force install "Encode"'
# perl -MCPAN -e 'force install "Regexp::Common"'	
# perl -MCPAN -e 'force install "WWW::Alexa::TrafficRank"'
# perl -MCPAN -e 'force install "AnyEvent::Google::PageRank"'	
# perl -MCPAN -e 'force install "Time::HiRes"'


###
# Fremde Bibliotheksprogramme einbinden
# dahinter stehen die Installationsanweisungen für die externen Bibliotheken
###
use URI;							
use AnyEvent;						
use Data::Dumper;					
use Encode qw(encode decode); 		
use Regexp::Common;					
use WWW::Alexa::TrafficRank;					
use AnyEvent::Google::PageRank; 	
use Time::HiRes qw( gettimeofday ); 

###
# Variablen vordefinieren und initialisieren
###
my $UA 								= LWP::UserAgent->new( timeout => 10 );
my $AlexaObject						= WWW::Alexa::TrafficRank->new();
my $PageRankObject					= AnyEvent::Google::PageRank->new( timeout => 10 );
my $TrendRankOutFile				= "trendrank_voll_berechnet.txt";

my $AlexaGewichtungsfaktor			= 0.2;
my $GooglePRGewichtungsfaktor		= 0.05;
my $TwitterGewichtungsfaktor		= 0.25;
my $FacebookGewichtungsfaktor		= 0.35;
my $DmozGewichtungsfaktor			= 0.1;
my $SpeedGewichtungsfaktor			= 0.05;
my $enc 							= 'utf-8'; # in dieser Kodierung ist das Script gespeichert

my $url = $ARGV[0];
open(W,"+>>$TrendRankOutFile");
binmode(W, ":utf8");

		next if (length($url)<10);
	
		if ($url !~ /^https?/ig ){
			$url = "http://".$url;
		}

		print "#" x 75;
		print "\n";
		print "Bestimme Trend Rank der Webseite: $url\n"; 
		my $AlexaRank 		= checkAlexa($url);
		my $AlexaFactor 	= calcAlexaFactor($AlexaRank);
		print "Alexa Rank: $AlexaRank -> Trend Factor: $AlexaFactor";	
		print "\n";
		my $PageRank 		= checkGooglePR($url);	
		my $PageFactor 		= calcGoogleFactor($PageRank);
		print "Google Page Rank: $PageRank -> Trend Factor: $PageFactor";	
		print "\n";
		my $TwitterRank 	= checkTwitterLinks($url);	
		my $TwitterFactor 	= calcTwitterFactor($TwitterRank);
		print "Anzahl Twitter Links: $TwitterRank -> Trend Factor: $TwitterFactor";	
		print "\n";
		my $FacebookRank	= checkFacebookLikes($url);	
		my $FacebookFactor	= calcFacebookFactor($FacebookRank);
		print "Anzahl Facebook Likes: $FacebookRank -> Trend Factor: $FacebookFactor";	
		print "\n";
		my $DmozRank 		= checkDmoz($url);	
		my $DmozFactor 		= calcDmozFactor($DmozRank);
		print "Dmoz.org Eintrag: $DmozRank -> Trend Factor: $DmozFactor";	
		print "\n";
		my $SpeedRank 		= checkDownloadTime($url);	
		my $SpeedFactor		= calcSpeedFactor($SpeedRank);
		print "Website Download Zeit: $SpeedRank -> Trend Factor: $SpeedFactor";	
		print "\n";
		my $TrendRank 		= sprintf ("%.2f",$AlexaFactor+$PageFactor+$TwitterFactor+$FacebookFactor+$DmozFactor+$SpeedFactor);
		print "TrendRank für '$url': '$TrendRank'";
		print W "\nTrendrank:$TrendRank\n#################\n";
		print "\n";
close W;
exit(0);


my $NW_Table = <<END;
Name							: Gewichtungsfaktor : Zielerreichungsfaktor
####################### 		: ############# : #####################	
Alexa							: 20%			: 	
Google PR						: 5%			: 
Twitter Links					: 25%			: 
Facebook Likes					: 35%			: 
Dmoz							: 10%			: 		
Website Download Zeit			: 5%			: 

Rankingfaktoren
####################################################################
Alexa Rank 1-25 				:				: 10
Alexa Rank 26-50 				:				: 9
Alexa Rank 51-150 				:				: 8
Alexa Rank 151-350 				:				: 7
Alexa Rank 351-750 				:				: 6
Alexa Rank 751-1500				:				: 5
Alexa Rank 1501-5000			:				: 4
Alexa Rank 5001-12000			:				: 3
Alexa Rank 12001-25000			:				: 2
Alexa Rank 25001-				:				: 1
Alexa Rank 0					:				: 1
####################################################################
Google Page Rank 10 			:				: 10
Google Page Rank 9 				:				: 9
Google Page Rank 8 				:				: 8
Google Page Rank 7 				:				: 7
Google Page Rank 6 				:				: 6
Google Page Rank 5				:				: 5
Google Page Rank 4				:				: 4
Google Page Rank 3				:				: 3
Google Page Rank 2				:				: 2
Google Page Rank 1 				:				: 1
Google Page Rank 0				:				: 1
####################################################################
Twitter Link Count 0-25 		:				: 1
Twitter Link Count 26-50 		:				: 2
Twitter Link Count 51-150 		:				: 3
Twitter Link Count 151-350 		:				: 4
Twitter Link Count 351-750 		:				: 5
Twitter Link Count 751-1500		:				: 6
Twitter Link Count 1501-5000	:				: 7
Twitter Link Count 5001-12000	:				: 8
Twitter Link Count 12001-25000	:				: 9
Twitter Link Count 25001-		:				: 10
####################################################################
Facebook Like Count 0-25 		:				: 1
Facebook Like Count 26-50 		:				: 2
Facebook Like Count 51-150 		:				: 3
Facebook Like Count 151-350 	:				: 4
Facebook Like Count 351-750 	:				: 5
Facebook Like Count 751-1500	:				: 6
Facebook Like Count 1501-5000	:				: 7
Facebook Like Count 5001-12000	:				: 8
Facebook Like Count 12001-25000	:				: 9
Facebook Like Count 25001-		:				: 10
####################################################################
Dmoz Eintrag vorhanden (j)		:				: 7
Dmoz Eintrag nicht vorhanden (n):				: 0
####################################################################
Website Download Zeit 0.45 		:				: 1
Website Download Zeit 0.41 		:				: 2
Website Download Zeit 0.35 		:				: 3
Website Download Zeit 0.31 		:				: 4
Website Download Zeit 0.25 		:				: 5
Website Download Zeit 0.21		:				: 6
Website Download Zeit 0.18		:				: 7
Website Download Zeit 0.15		:				: 8
Website Download Zeit 0.13		:				: 9
Website Download Zeit 0.1		:				: 10
END

###
# Speed Teilnutzwert berechnen
###
sub calcSpeedFactor($)
{
	my $input = shift;
	my $factorVal;
	if ( $input <= 0.1 ) {
		$factorVal = 10;
	} elsif ( $input <= 0.13 ) {
		$factorVal = 9;
	} elsif ( $input <= 0.15 ) {
		$factorVal = 8;
	} elsif ( $input <= 0.18 ) {
		$factorVal = 7;
	} elsif ( $input <= 0.21 ) {
		$factorVal = 6;
	} elsif ( $input <= 0.25 ) {
		$factorVal = 5;
	} elsif ( $input <= 0.31 ) {
		$factorVal = 4;
	} elsif ( $input <= 0.35 ) {
		$factorVal = 3;
	} elsif ( $input <= 0.41 ) {
		$factorVal = 2;
	} elsif ( $input <= 0.45 ) {
		$factorVal = 1;
	} else {
		$factorVal = 1;
	}

	return sprintf ("%.3f",$factorVal*$SpeedGewichtungsfaktor);
}

###
# Dmoz Teilnutzwert berechnen
###
sub calcDmozFactor($)
{
	my $input = shift;
	return sprintf ("%.3f",$input*$DmozGewichtungsfaktor*7);
}

###
# Facebook Teilnutzwert berechnen
###
sub calcFacebookFactor($)
{
	my $input = shift;
	my $factorVal;
	if ( $input >= 0 && $input <= 25 ) {
		$factorVal = 1;
	} elsif ( $input >= 26 && $input <= 50 ) { 
		$factorVal = 2;
	} elsif ( $input >= 51 && $input <= 150 ) { 
		$factorVal = 3;
	} elsif ( $input >= 151 && $input <= 350 ) { 
		$factorVal = 4;
	} elsif ( $input >= 351 && $input <= 750 ) { 
		$factorVal = 5;
	} elsif ( $input >= 751 && $input <= 1500 ) { 
		$factorVal = 6;
	} elsif ( $input >= 1501 && $input <= 5000 ) { 
		$factorVal = 7;
	} elsif ( $input >= 5001 && $input <= 12000 ) { 
		$factorVal = 8;
	} elsif ( $input >= 12001 && $input <= 25000 ) { 
		$factorVal = 9;
	} elsif ( $input >= 25001 ) { 
		$factorVal = 10;
	} elsif ( $input == 0 ) { 
		$factorVal = 1;
	} else {
		$factorVal = 1;
	}
	return sprintf ("%.3f",$factorVal*$FacebookGewichtungsfaktor);
}

###
# Twitter Teilnutzwert berechnen
###
sub calcTwitterFactor($)
{
	my $input = shift;
	my $factorVal;
	if ( $input >= 0 && $input <= 25 ) {
		$factorVal = 1;
	} elsif ( $input >= 26 && $input <= 50 ) { 
		$factorVal = 2;
	} elsif ( $input >= 51 && $input <= 150 ) { 
		$factorVal = 3;
	} elsif ( $input >= 151 && $input <= 350 ) { 
		$factorVal = 4;
	} elsif ( $input >= 351 && $input <= 750 ) { 
		$factorVal = 5;
	} elsif ( $input >= 751 && $input <= 1500 ) { 
		$factorVal = 6;
	} elsif ( $input >= 1501 && $input <= 5000 ) { 
		$factorVal = 7;
	} elsif ( $input >= 5001 && $input <= 12000 ) { 
		$factorVal = 8;
	} elsif ( $input >= 12001 && $input <= 25000 ) { 
		$factorVal = 9;
	} elsif ( $input >= 25001 ) { 
		$factorVal = 10;
	} elsif ( $input == 0 ) { 
		$factorVal = 1;
	} else {
		$factorVal = 1;
	}
	return sprintf ("%.3f",$factorVal*$TwitterGewichtungsfaktor);
}

###
# Google PageRank Teilnutzwert berechnen
###
sub calcGoogleFactor($)
{
	my $input = shift;
	return sprintf ("%.3f",$input*$GooglePRGewichtungsfaktor);
}

###
# Alexa Teilnutzwert berechnen
###
sub calcAlexaFactor($)
{
	my $input = shift;
	my $factorVal;
	if ( $input >= 1 && $input <= 25 ) {
		$factorVal = 10;
	} elsif ( $input >= 26 && $input <= 50 ) { 
		$factorVal = 9;
	} elsif ( $input >= 51 && $input <= 150 ) { 
		$factorVal = 8;
	} elsif ( $input >= 151 && $input <= 350 ) { 
		$factorVal = 7;
	} elsif ( $input >= 351 && $input <= 750 ) { 
		$factorVal = 6;
	} elsif ( $input >= 751 && $input <= 1500 ) { 
		$factorVal = 5;
	} elsif ( $input >= 1501 && $input <= 5000 ) { 
		$factorVal = 4;
	} elsif ( $input >= 5001 && $input <= 12000 ) { 
		$factorVal = 3;
	} elsif ( $input >= 12001 && $input <= 25000 ) { 
		$factorVal = 2;
	} elsif ( $input >= 25001 ) { 
		$factorVal = 1;
	} elsif ( $input == 0 ) { 
		$factorVal = 1;
	} else {
		$factorVal = 1;
	}
	return sprintf ("%.3f",$factorVal*$AlexaGewichtungsfaktor);
}

###
# Domainnamen vom übergebenen URI einsammeln
###
sub getDomain($)
{
	my $input = shift;
	my $url = URI->new( $input );
	return $url->host;
}

###
# Download Zeitraum für Webseite messen
###
sub checkDownloadTime($)
{
	my $input 		= shift;
	my $prep_start 	= gettimeofday ;
	get($input);
	my $prep_end 	= gettimeofday;

	my $val = sprintf ("%.7f",$prep_end-$prep_start);
	return $val;
}

###
# Alexa Rank einer Webseite bestimmen
###
sub checkAlexa($)
{
	my $input 	= shift;
	my $dom		= getDomain($input);
	my $rank 	= $AlexaObject->get($dom);
	if ($rank !~ /\d/ig ){
		return 0;
	} else {
		return $rank;
	}
}
###
# Twitter Links einer URI bestimmen
###
sub checkGooglePR($)
{
	my $input 	= shift;
	my $dom		= getDomain($input);
	$dom 		= "http://".$dom;
	my $cv 		= AnyEvent->condvar;
	$cv->begin;	
	my $returnRank;
	$PageRankObject->get($dom, sub {
		my ($rank, $headers) = @_;
		#print "$url - ", defined($rank) ? $rank : "fail: $headers->{Status} - $headers->{Reason}", "\n";
		$returnRank = $rank;
		$cv->end;
	});
	$cv->recv;
	return $returnRank;
}

###
# Twitter Links einer Webseite bestimmen
###
sub checkTwitterLinks($)
{
	my $input 			= shift;
	my $twitterQuery 	= "http://urls.api.twitter.com/1/urls/count.json?url=".$input;   
	my $jsonContent		= get($twitterQuery);
	$jsonContent 		=~ /:(.*),/ig;
	return $1;
}

###
# Facebook Likes einer Webseite berechnen
###
sub checkFacebookLikes($)
{
	my $input 				= shift;
	my $facebookQuery 		= "select like_count from link_stat WHERE url ='" . $input ."'";
	my $facebookGraphQuery 	= "https://api.facebook.com/method/fql.query?query=".$facebookQuery."&format=json";
	my $jsonContent			= get($facebookGraphQuery);
	my (undef,$like_count)	= split(":",$jsonContent );
	$like_count 			=~ s/\D//ig;
	return $like_count;
}

###
# Dmoz.org Eintrag einer Webseite prüfen
###
sub checkDmoz($)
{
	my $input 			= shift;
	my $dom				= getDomain($input);
	my $dmozQuery 		= "http://www.dmoz.org/search?q=".$dom;
	my $dmozContent 	= get($dmozQuery);
	if ($dmozContent 	=~ m/<a href=\"$input/ig){
		return 1;
	} else {
		return 0;
	}

	return 0;
}

###
# HTTP GET Request senden
###
sub get($)
{
	my $input = shift;
	my $response 	= $UA->get($input);
	if ( $response->is_success ) {
		return $response->content;
	}
}

###
# Zeichen Space entfernen
###
sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}