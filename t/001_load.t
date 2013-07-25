# -*- perl -*-

# t/001_load.t - check module loading and create testing directory

use Test::More tests => 2;

BEGIN { use_ok( 'POE::Component::RSSAggregator' ); }

my @test = ();
sub testcallback { }
my $object = POE::Component::RSSAggregator->new(
    feeds    => \@test,
    callback => \&testcallback,
);
isa_ok ($object, 'POE::Component::RSSAggregator');


