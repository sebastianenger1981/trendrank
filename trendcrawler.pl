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
# Fremde Bibliotheksprogramme einbinden
# dahinter stehen die Installationsanweisungen für die externen Bibliotheken
###
use Data::Dumper;			# perl -MCPAN -e 'force install "Data::Dumper"'	
use Config::Simple; 		# perl -MCPAN -e 'force install "Config::Simple"'	
use Net::Twitter;			# perl -MCPAN -e 'force install "Net::Twitter::Lite"'	
use Scalar::Util 'blessed';	# perl -MCPAN -e 'force install "Scalar::Util"'	
use POSIX qw(strftime);		# perl -MCPAN -e 'force install "POSIX"'	
use LWP::UserAgent;			# perl -MCPAN -e 'force install "LWP::UserAgent"'	
use Regexp::Common;			# perl -MCPAN -e 'force install "Regexp::Common"'	
use Google::Data::JSON;		# perl -MCPAN -e 'force install "Google::Data::JSON"'	
use File::Path;				# perl -MCPAN -e 'force install "File::Path"'

###
# Variablen vordefinieren und initialisieren
###
my $UA 						= LWP::UserAgent->new();
my $Config 					= Config::Simple->new(filename=>"trendcrawler.cfg");
my $Keywords				= $Config->param(-block=>"KeywordListingGerman");
my $Google					= $Config->param(-block=>"Google");
my $Twitter					= $Config->param(-block=>"Twitter");
my $TimeStamp				= join ("-", (localtime));
my $Hash					= "";
my %Hash 					= ();

###
# Konstanten festlegen
###
use constant GoogleHtml     => "./html/google/";
use constant TwitterHtml    => "./html/twitter/";
eval { mkpath(GoogleHtml); mkpath(TwitterHtml); };		# File::Path

###
# Externes Twitter Modul konfigurieren und mit Werten aus der Konfigurationsdatei belegen
###
my $nt = Net::Twitter->new(
	traits   				=> [qw/API::RESTv1_1/],
	consumer_key       		=> $Twitter->{'consumer_key'},
	consumer_secret     	=> $Twitter->{'consumer_secret'},
	access_token        	=> $Twitter->{'access_token'},
	access_token_secret 	=> $Twitter->{'access_token_secret'},
	ssl                 	=> 1,  ## enable SSL! ##
	decode_html_entities   	=> 1,
);

###
# Für alle Keywords der Konfigurationsdatei führe die Suche nach Twitter und Google Trends durch
###
while ( my ($key, $searchQuery) = each(%$Keywords) ) {
	print localtime . " ) Suche bei Twitter nach Keywords: $searchQuery\n";
	twitterCustomSearch($searchQuery);
	print localtime . " ) Suche bei Google nach Keywords: $searchQuery\n";
	googleParseSearch($searchQuery);
}

exit(0);

###
# Twitter Suche durchführen
###
sub twitterCustomSearch($)
{
	my $input 		= shift;
	my $yesterday 	= time() - 30 * 60 * 24 * 60; #tweets from max n=120 days ago
	my $timestamp 	= strftime "%Y-%m-%d", ( localtime($yesterday) );
	my $result 		= $nt->search($input, {lang => 'en', count => 100, since => $timestamp});
	writeHtml("<hr><h1><strong><b>Trending Twitter Keywords: $input<b><strong></h1><br /><br />", TwitterHtml.$TimeStamp.".twitter-$input-page.html");		
	my $identity; # Last returned id 
	foreach my $status (@{$result->{'statuses'}}) {
		my $s 		= $status->{text}; # Tweeted Text
		my $content = twitterBeautify($s);
		if (length($content) >= 23 ){
			writeHtml($content, TwitterHtml.$TimeStamp.".twitter-$input-page.html");		
		};
	};
	
	return 1;
}

###
# Google Suche durchführen
###
sub googleParseSearch($)
{
	my $input 	= shift;
	my $json 	= googleCustomSearch($input);
	my $gdata 	= Google::Data::JSON->new(json => $json);
	my $hash  	= $gdata->as_hash;
	my %hash 	= ();
	my $arrRef 	= $hash->{'results'};

	writeHtml("<hr><h1><strong><b>Trending Google Keywords: $input<b><strong></h1><br /><br />", GoogleHtml.$TimeStamp.".google-$input-page.html");	
	foreach my $hashref (@$arrRef) {

		my $resultUrl 	= $hashref->{unescapedUrl};
		my $content 	= "Title: " . $hashref->{titleNoFormatting} . "<br>";
		$content 		.= "Content: " . $hashref->{contentNoFormatting} . "<br>";
		$content 		.= "Url: " . makeLinkable($resultUrl) . "<br>";
		$content 		.= "Image: <img src=\"".$hashref->{richSnippet}->{cseImage}->{src}."\" alt=\"search\" />" . "<br>";
		
		if ( !$Hash{$resultUrl} ) {
			$Hash{$resultUrl} = $resultUrl;
			writeHtml($content, GoogleHtml.$TimeStamp.".google-$input-page.html");		
		}
		$content = "";
	}
	return 1;
}

###
# Ausgabe HTML Datei mit Trends drin schreiben
###
sub writeHtml($)
{
	my $input = shift;
	my $file = shift;
	
	open (OUT, "+>>$file");
		binmode(OUT, ":utf8");
		print OUT "$input<br><hr><br>\n";
	close OUT; 
	
	return;
}

###
# Google Custom Search Wert aus Konfigurationsdatei auslesen und mit Hilfe des übergebenen Keywortes HTTP Request für Suche stellen
###
sub googleCustomSearch($)
{
	my $input 	= shift;
	my $uri 	= $Google->{'custom_search_page'};
	return get($uri.$input);
}

###
# Aus einem Text- einen HTML Anker Link bilden
###
sub makeLinkable($)
{
	my $input = shift;
	$input =~ s[($RE{URI}{HTTP})][<a href="$1" target="_blank">$1</a>]g;
	return $input;
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
# Inhalt der Twitter Tweets ordentlich für Ausgabe formatieren
###
sub twitterBeautify($)
{
	my $input	= shift;
	my $link	= "";
	my @c 		= split(" ",$input);
	my $text	= "";
	foreach my $c (@c){
		$c = trim($c);
		next if ($c =~/\@/ig);		
		if ( $c =~ /^https?:\/\//ig ){
			#print "\tc found link=$c\n";
			$link = make_longlink($c);
			if ( $Hash{$link} ) {
				return "";
			} else {
				$Hash{$link} = $link;
			}
			$text .= " ". makeLinkable($link). " ";
			#$text .= "$link ";
		} else {
			$text .= "$c ";
		}
	}
	return "Content: ". $text."<br>\n";
}

###
# Aus einem kurzen Link von einem Linkverkürzer wieder den Original Link machen
###
sub make_longlink($)
{
	my $shortlink	= shift;
	my $response 	= $UA->head($shortlink);
	if ( $response->is_success ) {
		return $response->request->uri->as_string;
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