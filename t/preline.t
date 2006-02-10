#!perl

use strict;
use warnings;

use Test::More tests => 1;
use Template;
use Template::Parser::Greedy;

my $config = { PARSER => Template::Parser::Greedy->new() };
my $template = Template->new($config);
my $got = '';

my $t2 = "1\n2\n3\n4\n5\n6\n7\n8\n9\n[% END %]";

eval {
    $template->process(\$t2, {}, \$got) || die $template->error();
};

# T2 gets this wrong (line 11) - should be line 10
# see t2_line_count_bug.t

ok ($@ =~ /input text line 10: unexpected token \(END\)/, 'prelines');
