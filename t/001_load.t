# -*- perl -*-

# t/001_load.t - check module loading and create testing directory

use Test::More tests => 2;

BEGIN { use_ok( 'POE::Component::RSSAggregator' ); }

sub testcallback { }
my $object = POE::Component::RSSAggregator->new(
    callback => \&testcallback,
);
isa_ok ($object, 'POE::Component::RSSAggregator');


