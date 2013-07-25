package POE::Component::RSSAggregator;
use strict;
use vars qw($VERSION);
$VERSION = 0.2;

=head1 NAME

POE::Component::RSSAggregator - A Simple POE RSS Aggregator

=head1 SYNOPSIS

    #!/usr/bin/perl -w
    use strict;
    use POE;
    use POE::Component::RSSAggregator;
    use XML::RSS::Feed::Factory;

    my @feeds = (
	{
	    url   => "http://www.jbisbee.com/rdf/",
	    name  => "jbisbee",
	    delay => 10,
	},
	{
	    url   => "http://lwn.net/headlines/rss",
	    name  => "lwn",
	    delay => 300,
	},
    );

    POE::Session->create(
	inline_states => {
	    _start      => \&init_session,
	    handle_feed => \&handle_feed,
	}
    );

    $poe_kernel->run();

    sub init_session
    {
	my ($kernel, $heap, $session) = @_[KERNEL, HEAP, SESSION];
	$heap->{rssagg} = POE::Component::RSSAggregator->new(
	    feeds    => \@feeds,
	    debug    => 1,
	    callback => $session->postback("handle_feed"),
	    tmpdir   => '/tmp', # optional caching
	);
    }

    sub handle_feed
    {
	my ($kernel,$feed) = (@_[KERNEL], $_[ARG1]->[0]);
	for my $headline ($feed->late_breaking_news) {
	    # do stuff with the XML::RSS::Headline object
	    print $headline->headline . "\n";
	}
    }

=head1 USAGE

The premise is this, you watch RSS feeds for new headlines to appear and when
they do you trigger an event handle them.  The handle_feed event is given a 
XML::RSS::Feed object every time new headlines are found.

=head1 AUTHOR

Jeff Bisbee
CPAN ID: JBISBEE
jbisbee@cpan.org
http://search.cpan.org/author/JBISBEE/

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.


=head1 SEE ALSO

L<XML::RSS::Feed::Factory>, L<XML::RSS::Feed>, L<XML::RSS::Headline>

=cut

use POE;
use POE::Component::Client::HTTP;
use HTTP::Request;
use XML::RSS::Feed;
use Carp;

sub new
{
    my $class = shift;
    croak __PACKAGE__ . "->new() params must be a hash" if @_ % 2;
    my %params = @_;
    my $feeds = $params{feeds} || [];
    delete $params{feeds};
    croak __PACKAGE__ . "->new() feeds ARRAY ref is required" unless ref $feeds eq "ARRAY";
    my $self = bless \%params, $class;
    $self->init($feeds);
    return $self;
}

sub feeds
{
    my ($self) = @_;
    return $self->{feed_objs};
}

sub feed
{
    my ($self,$name) = @_;
    return exists $self->{feed_objs}{$name} ? $self->{feed_objs}{$name} : undef;
}

sub add_feed
{
    my ($self,$kernel,$feed_hash) = @_[OBJECT,KERNEL,ARG0];
    if (exists $self->{feed_objs}{$feed_hash->{name}}) {
	warn "[$feed_hash->{name}] !! Add Failed: Feed name already exists\n";
	return;
    }
    warn "[$feed_hash->{name}] Added\n" if $self->{debug};
    $self->_create_feed_object($feed_hash);
    # Test to remove it after 10 seconds
    $kernel->yield('fetch', $feed_hash->{name});
}

sub remove_feed
{
    my ($self,$kernel,$name) = @_[OBJECT,KERNEL,ARG0];
    unless (exists $self->{feed_objs}{$name}) {
	warn "[$name] !! Remove Failed: Unknown feed\n";
	return;
    }
    $kernel->call('rssagg','pause_feed','jbisbee');
    delete $self->{feed_objs}{$name};
    warn "[$name] Removed RSS Feed\n" if $self->{debug};
}

sub pause_feed
{
    my ($self,$kernel,$name) = @_[OBJECT,KERNEL,ARG0];
    unless (exists $self->{feed_objs}{$name}) {
	warn "[$name] !! Pause Failed: Unknown feed\n";
	return;
    }
    unless (exists $self->{alarm_ids}{$name}) {
	warn "[$name] !! Pause Failed: Feed currently on pause\n";
	return;
    }
    $kernel->alarm_remove($self->{alarm_ids}{$name});
    delete $self->{alarm_ids}{$name};
    warn "[$name] Paused RSS Feed\n" if $self->{debug};
}

sub resume_feed
{
    my ($self,$kernel,$name) = @_[OBJECT,KERNEL,ARG0];
    unless (exists $self->{feed_objs}{$name}) {
	warn "[$name] !! Resume Failed: Unknown feed\n";
	return;
    }
    if (exists $self->{alarm_ids}{$name}) {
	warn "[$name] !! Resume Failed: Feed currently active\n";
	return;
    }
    warn "[$name] Resumed RSS Feed\n" if $self->{debug};
    $kernel->yield('fetch',$name);
}

sub init
{
    my ($self,$feeds) = @_;
    if ($feeds) {
	for my $feed_hash (@{$feeds}) {
	    if (ref $feed_hash eq "HASH") {
		$self->_create_feed_object($feed_hash);
	    }
	    else {
		# XXX fix this!  actually check to see if the hashes are XML::RSS::Feed objects
		warn "[!!] the use of XML::RSS::Feed::Factory has been depricated\n";
		$self->{feed_objs}{$feed_hash->{name}} = $feed_hash;
	    }
	}
    }
    unless ($self->{http_alias}) {
	$self->{http_alias} = 'ua';
	POE::Component::Client::HTTP->spawn(
	    Alias   => $self->{http_alias},
	    Timeout => 60,
	    Agent   => 'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.1) ' . 
		       'Gecko/20020913 Debian/1.1-1',
	);
    }
    POE::Session->create(
	object_states => [
	    $self => [qw(_start add_feed remove_feed pause_feed resume_feed fetch response _stop)],
	],
    );
}

sub _create_feed_object
{
    my ($self,$feed_hash) = @_;
    warn "[$feed_hash->{name}] Creating XML::RSS::Feed object\n" if $self->{debug};
    $feed_hash->{tmpdir} = $self->{tmpdir} if -d $self->{tmpdir};
    $feed_hash->{debug} = $self->{debug} if $self->{debug};
    if (my $rssfeed = XML::RSS::Feed->new(%$feed_hash)) {
	$self->{feed_objs}->{$rssfeed->name} = $rssfeed;
    }
    else {
	warn "[$feed_hash->{name}] !! Error attempting to create XML::RSS::Feed object\n";
    }
}

sub _start
{
    my ($self,$kernel) = @_[OBJECT,KERNEL];
    $kernel->alias_set($self->{alias} || 'rssagg');
}

sub fetch
{
    my ($self,$kernel,$feed_name) = @_[OBJECT,KERNEL,ARG0];
    unless (exists $self->{feed_objs}{$feed_name}) {
	warn "[$feed_name] Unknown Feed\n";
	return;
    }

    my $rssfeed = $self->{feed_objs}{$feed_name};
    $rssfeed->failed_to_fetch(0);
    $rssfeed->failed_to_parse(0);
    my $req = HTTP::Request->new(GET => $rssfeed->url);
    warn "[".$rssfeed->name."] Attempting to fetch\n" if $self->{debug};
    $kernel->post($self->{http_alias},'request','response',$req,$rssfeed->name);
    $self->{alarm_ids}{$rssfeed->name} = 
	$kernel->delay_set('fetch', $rssfeed->delay, $rssfeed->name);
}

sub response
{
    my ($self,$kernel,$request_packet,$response_packet) = 
	@_[OBJECT,KERNEL,ARG0,ARG1];
    my ($req,$feed_name) = @$request_packet;
    unless (exists $self->{feed_objs}{$feed_name}) {
	warn "[$feed_name] Unknown Feed\n";
	return;
    }

    my $rssfeed = $self->{feed_objs}{$feed_name};
    my $res = $response_packet->[0];
    if ($res->is_success) {
	warn "[" . $rssfeed->name. "] Fetched " . $rssfeed->url . "\n" if $self->{debug};
	$rssfeed->parse($res->content);
	$self->{callback}->($rssfeed) unless $rssfeed->failed_to_parse;
    }
    else {
	$rssfeed->failed_to_fetch(1);
	warn "[!!] Failed to fetch " . $req->uri . "\n";
    }
}

# not sure whats needs be cleaned up yet
sub _stop {
    my ($self,$kernel) = @_[OBJECT,KERNEL];
}

1;
