#!perl -T
use Test::More tests => 1;

BEGIN { use_ok('POE::Component::RSSAggregator'); }
diag( "Testing POE::Component::RSSAggregator $POE::Component::RSSAggregator::VERSION, Perl $], $^X" );
