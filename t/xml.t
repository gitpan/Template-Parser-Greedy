#!perl

use strict;
use warnings;

use Test::More tests => 1;
use Template;
use Template::Parser::Greedy;

my $config = { PARSER => Template::Parser::Greedy->new() };
my $template = Template->new($config);
my $vars = { add => sub { $_[0] + 1 }, tab => sub { "    " x $_[0] } };
my $got = '';

my $t2 = <<EOT;
    [% nl = "\n" %]

    [% BLOCK foo %] [%# params: bar, indent %]
        [% outer = tab(indent) %]
        [% inner = tab(add(indent, 1)) %]
           
        [% outer %]
        <foo>

            [% FOR baz IN bar %]

                [% nl %] [% inner %]
                <bar baz="[% baz %]" />

            [% END %]

		[% nl %] [% outer %]
        </foo> 
        
    [% END %]

	[% INCLUDE foo(bar = [ 'alpha', 'beta', 'gamma', 'vlissides' ], indent = 0) %]
EOT

my $want = <<EOT;
<foo>
    <bar baz="alpha" />
    <bar baz="beta" />
    <bar baz="gamma" />
    <bar baz="vlissides" />
</foo>
EOT

chomp $want;

$template->process(\$t2, $vars, \$got) || die $template->error();

ok($got eq $want, 'XML');
