use ExtUtils::MakeMaker;
WriteMakefile(
    NAME         => 'POE::Component::RSSAggregator',
    VERSION_FROM => 'lib/POE/Component/RSSAggregator.pm',
    AUTHOR       => 'Jeff Bisbee (jbisbee@cpan.org)',
    ABSTRACT     => 'A Simple Clean POE RSS Aggregator',
    PREREQ_PM    => { 
	'POE::Component::Client::HTTP' => 0.51,
	'XML::RSS::Feed'               => 0.01,
	'HTTP::Request'                => 1.30,
    },
);
