package Plugins::ShairTunes2W::AIRPLAY;

use strict;
use warnings;

use base qw(Slim::Player::Protocols::HTTP);
use Slim::Utils::Strings qw(string);
use Slim::Utils::Misc;
use Slim::Utils::Log;
use Slim::Utils::Prefs;

Slim::Player::ProtocolHandlers->registerHandler( 'airplay', __PACKAGE__ );

my $log   = logger( 'plugin.shairtunes' );
my $prefs = preferences( 'plugin.shairtunes' );

sub isRemote { 1 }

sub bufferThreshold { $prefs->get('bufferThreshold') // 255; }

sub canDoAction {
    my ( $class, $client, $url, $action ) = @_;
    
	$log->info( "Action=$action" );

    return Plugins::ShairTunes2W::Plugin->sendAction($client, $action);
}

sub canHandleTranscode {
    my ( $self, $song ) = @_;

    return 1;
}

sub getStreamBitrate {
    my ( $self, $maxRate ) = @_;
	
	my $rate = Slim::Player::Song::guessBitrateFromFormat( ${*$self}{'contentType'}, $maxRate );
	$log->info("bitrate: $rate");
	
	return $rate;
}

sub isAudioURL { 1 }

# XXX - I think that we scan the track twice, once from the playlist and then again when playing
sub scanUrl {
    my ( $class, $url, $args ) = @_;

    Slim::Utils::Scanner::Remote->scanURL( $url, $args );
}

sub canDirectStream {
    my ( $class, $client, $url ) = @_;
	
	return 0 if $client->isSynced(1);
	
    $log->debug( "canDirectStream $url" );

    $url =~ s{^airplay://}{http://};
	
    return $class->SUPER::canDirectStream($client, $url);
}

# To support remote streaming (synced players, slimp3/SB1), we need to subclass Protocols::HTTP
sub new {
    my $class  = shift;
    my $args   = shift;
    
    my $client = $args->{client};
    my $song   = $args->{song};
	my $url    = $args->{url};
	
	$url =~ s/airplay/http/;
	
	my $sock = $class->SUPER::new( {
		url     => $url,
        song    => $song,
        client  => $client,
		bitrate => 1_411_200,
    } ) || return;
	
	$log->debug("NEW: $url");

    ${*$sock}{contentType} = $prefs->get('useFLAC') ? 'flc' : 'wav';

    return $sock;
}

sub contentType {
    my $self = shift;

    return ${*$self}{'contentType'};
}

sub getMetadataFor {
    my ( $class, $client, $url, $forceCurrent, $song ) = @_;

	my $metaData = Plugins::ShairTunes2W::Plugin->getAirTunesMetaData($url);
	
	if ( $song && defined $metaData->{duration} ) {
		$song->track->secs( $metaData->{duration} ) ;
		$song->startOffset( $metaData->{position} -  $metaData->{offset} );
	}	
		
	if ( $client->isPlaying && defined $metaData->{duration} )	{ 
		$client->streamingSong->duration( $metaData->{duration} ) if $client->streamingSong;
		$client->playingSong()->startOffset( $metaData->{position} -  $metaData->{offset} );
	}	
		
    return $metaData;
}

1;

# Local Variables:
# tab-width:4
# indent-tabs-mode:t
# End:
