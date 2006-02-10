#!perl

use strict;
use warnings;

use Test::More tests => 1;
use Template;
use Template::Parser::Greedy;

my $config = { PARSER => Template::Parser::Greedy->new() };
my $template = Template->new($config);
my $got = '';
my $t2 = "[% IF 1 %]\n2\n3\n4\n5\n6\n7\n8\n9\n";

eval {
	$template->process(\$t2, {}, \$got) || die $template->error();
};

# T2 gets the line number wrong (i.e. it reports the start tag line rather than the line where it
# is discovered that the tag is unclosed); this is because line numbers are stored only in
# directive tokens, rather than internally in the parser during tokenisation
#
# Out of courtesy, we get it wrong as well (until T3 :-)

ok (($@ =~ /input text line 1: unexpected end of input/), 'postlines');
