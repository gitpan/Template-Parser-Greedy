use 5.006;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Template::Parser::Greedy',
    VERSION_FROM      => 'lib/Template/Parser/Greedy.pm', # finds $VERSION
    PREREQ_PM         => {
        'Template::Parser'  => '2.82',
        'Test::More'        => 0
    }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Template/Parser/Greedy.pm', # retrieve abstract from module
       AUTHOR         => 'chocolateboy <chocolate.boy@email.com>') : ()),
);
