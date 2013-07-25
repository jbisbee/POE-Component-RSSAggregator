package POE::Component::RSSAggregator;
use strict;
use vars qw($VERSION);
$VERSION = 0.02;

=head1 NAME

POE::Component::RSSAggregator - A Simple POE RSS Aggregator

=head1 SYNOPSIS

    use POE;
    use POE::Component::RSSAggregator;
    use XML::RSS::Feed::Factory;

First define the RSS Feeds you would like to watch

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

Create a new PoCo::RSSAggregator object and use the feed_factory function
XML::RSS:Feed::Factory to generate your XML::RSS::Feed objects.

    my $rssagg = POE::Component::RSSAggregator->new(
	feeds    => [feed_factory(@feeds)],
	debug    => 1,
	callback => \&new_headlines,
    );

Tell POE to run

    $poe_kernel->run();

Every time a request is made the rss feed object is returned and you
can see if things have changed - $feed->late_breaking_news

    sub handle_feed
    {
	my ($feed) = @_;
	if ($feed->late_breaking_news) {
	    for my $headline ($feed->late_breaking_news) {
		print $headline->url . "\n";
	    }
	}
    }


=head1 USAGE

The short version is that fetch RSS feeds every 'delay' second
adn when new headlines are found the XML::RSS::Feed::Headline
objects are recived via the registerd call back function.

=head1 AUTHOR

	Jeff Bisbee
	CPAN ID: JBISBEE
	jbisbee@cpan.org
	http://www.jbisbee.com/perl/modules/

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.


=head1 SEE ALSO

L<XML::RSS::Feed::Factory>, L<XML::RSS::Feed>, L<XML::RSS::Feed::Headline>

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
    croak __PACKAGE__ . "->new callback CODE ref is required" 
	unless ref $params{callback} eq "CODE";
    my $self = bless \%params, $class;
    $self->init();
    return $self;
}

sub init
{
    my ($self) = @_;
    if ($self->{feeds}) {
	for my $hash (@{$self->{feeds}}) {
	    my $obj = $hash->{obj} || "XML::RSS::Feed";
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
    $kernel->delay_add('fetch',$rssfeed->delay,$rssfeed);
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
