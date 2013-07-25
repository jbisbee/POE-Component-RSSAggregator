package POE::Component::RSSAggregator;
use strict;
use vars qw($VERSION);
$VERSION = 0.10;

=head1 NAME

POE::Component::RSSAggregator - A Simple POE RSS Aggregator

=head1 SYNOPSIS

    use POE;
    use POE::Component::RSSAggregator;
    use XML::RSS::Feed::Factory;

    my @feeds = (
	{
	    url   => "http://www.jbisbee.com/rdf/",
	    name  => "jbisbee",
	    delay => 10,
	    debug => 1,
	},
	{
	    url   => "http://lwn.net/headlines/rss",
	    name  => "lwn",
	    delay => 300,
	    debug => 1,
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
	    feeds    => [feed_factory(@define_feeds)],
	    debug    => 1,
	    callback => $session->postback("handle_feed"),
	);
    }

    sub handle_feed
    {
	my ($heap,$kernel,$feed) = (@_[HEAP, KERNEL], $_[ARG1]->[0]);
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
    croak __PACKAGE__ . "->new() feeds ARRAY ref is required" 
	unless ref $params{feeds} eq "ARRAY";
    my $test = ref $params{callback};
#    croak __PACKAGE__ . "->new callback CODE ref is required" 
#    	unless ref $params{callback} =~ /CODE/;
    my $self = bless \%params, $class;
    $self->init();
    return $self;
}

sub feeds
{
    my ($self) = @_;
    return $self->{feed_objs};
}

sub init
{
    my ($self) = @_;
    if ($self->{feeds}) {
	for my $hash (@{$self->{feeds}}) {
	    my $obj = "XML::RSS::Feed";
	    $self->{feed_objs}->{$hash->{name}} = $obj->new(%$hash);
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
	    $self => [qw(_start fetch response _stop)],
	],
    );
}

sub _start
{
    my ($self,$kernel,$heap) = @_[OBJECT,KERNEL,HEAP];
    for my $rssfeed (values %{$self->{feed_objs}}) {
	$kernel->yield('fetch', $rssfeed);
    }
}

sub fetch
{
    my ($self,$kernel,$rssfeed) = @_[OBJECT,KERNEL,ARG0];
    $rssfeed->failed_to_fetch(0);
    $rssfeed->failed_to_parse(0);
    my $req = HTTP::Request->new(GET => $rssfeed->url);
    $kernel->post($self->{http_alias},'request','response',$req,$rssfeed);
    $self->{alarm_ids}{$rssfeed->name} = $kernel->delay_set('fetch', $rssfeed->delay, $rssfeed);
}

sub response
{
    my ($self,$kernel,$request_packet,$response_packet) = 
	@_[OBJECT,KERNEL,ARG0,ARG1];
    my ($req,$rssfeed) = @$request_packet;
    my $res = $response_packet->[0];
    if ($res->is_success) {
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
    my ($self,$kernel,$heap) = @_[OBJECT,KERNEL,HEAP];
}

1;
