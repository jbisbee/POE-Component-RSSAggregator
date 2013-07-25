#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 2;
use POE;

# so I don't have to keep typing it... :)
my $package = 'POE::Component::RSSAggregator';

use_ok($package);
isa_ok($package->new(callback => \&fake), $package);

$poe_kernel->run();

sub fake {}
