#!perl

use strict;
use warnings;

use Test::More tests => 1;
use Template;
use Template::Parser::Greedy;

my $config = { PARSER => Template::Parser::Greedy->new() };
my $template = Template->new($config);
my $got = '';

# line numbers start at 1
my $t2 = q|
	[% nl = "\n" %]
03	[% END %]|;

eval {
    $template->process(\$t2, {}, \$got) || die $template->error();
};

# There is a bug in Template::Parser, which doesn't handle the pre-directive line count
# correctly if the prefix matches /^\n[ \t]*$/ i.e. if all of the prefix is consumed

ok ($@ =~ /input text line 3: unexpected token \(END\)/, 'Template::Parser line count bug');
