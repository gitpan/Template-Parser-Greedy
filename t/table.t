#!perl

use strict;
use warnings;

use Test::More tests => 1;
use Template;
use Template::Parser::Greedy;

my $config = { PARSER => Template::Parser::Greedy->new() };
my $template = Template->new($config);
my $got = '';

my $t2 = <<EOT;
[% IF 1 +%]

    ------------------------------------
    | alpha | beta | gamma | vlissides |
    ------------------------------------
    |  foo  | bar  |  baz  |    quux   |
    ------------------------------------

[%+ END %]
EOT

my $want = <<EOT;


    ------------------------------------
    | alpha | beta | gamma | vlissides |
    ------------------------------------
    |  foo  | bar  |  baz  |    quux   |
    ------------------------------------

EOT

$template->process(\$t2, {}, \$got) || die $template->error();

ok($got eq $want, 'table');
