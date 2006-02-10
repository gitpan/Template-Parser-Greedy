#!perl

use strict;
use warnings;

use Test::More tests => 80;
use Template;
use Template::Parser::Greedy qw(:all);

my ($want_special, $want_num);

$want_special->{'undef_undef'}  = '|.|';                        # new(undef, undef)
$want_special->{''}             = '|.|';                        # new()
$want_special->{'_'}            = '|\s\f\r\n\t.\s\f\r\n\t|';    # [% ... %]

$want_num->{'0_0'} = '|\s\f\r\n\t.\s\f\r\n\t|';
$want_num->{'0_1'} = '|\s\f\r\n\t.\f\r\n\t|';
$want_num->{'0_2'} = '|\s\f\r\n\t.\s\f\r\n\t|';
$want_num->{'0_3'} = '|\s\f\r\n\t.|';
$want_num->{'0_4'} = '|\s\f\r\n\t.\s|';
$want_num->{'1_0'} = '|\s\f\r.\s\f\r\n\t|';
$want_num->{'1_1'} = '|\s\f\r.\f\r\n\t|';
$want_num->{'1_2'} = '|\s\f\r.\s\f\r\n\t|';
$want_num->{'1_3'} = '|\s\f\r.|';
$want_num->{'1_4'} = '|\s\f\r.\s|';
$want_num->{'2_0'} = '|\s\f\r\s.\s\f\r\n\t|';
$want_num->{'2_1'} = '|\s\f\r\s.\f\r\n\t|';
$want_num->{'2_2'} = '|\s\f\r\s.\s\f\r\n\t|';
$want_num->{'2_3'} = '|\s\f\r\s.|';
$want_num->{'2_4'} = '|\s\f\r\s.\s|';
$want_num->{'3_0'} = '|.\s\f\r\n\t|';
$want_num->{'3_1'} = '|.\f\r\n\t|';
$want_num->{'3_2'} = '|.\s\f\r\n\t|';
$want_num->{'3_3'} = '|.|';
$want_num->{'3_4'} = '|.\s|';
$want_num->{'4_0'} = '|\s.\s\f\r\n\t|';
$want_num->{'4_1'} = '|\s.\f\r\n\t|';
$want_num->{'4_2'} = '|\s.\s\f\r\n\t|';
$want_num->{'4_3'} = '|\s.|';
$want_num->{'4_4'} = '|\s.\s|';

my %whitespace = (
    " "        => '\s',
    "\f"     => '\f',
    "\r"     => '\r',
    "\n"     => '\n',
    "\n"     => '\n',
    "\t"     => '\t'
);

my %modifier = (
    '0'        => '+',    
    '1'        => '-',    
    '2'        => '=',    
    '3'        => '~',
    '4'        => '^'
);

my $whitespace = " \f\r\n\t";
my $arg_tt2    = "|$whitespace\[% '.' %]$whitespace|"; 
my @chomps     = sort (keys(%$want_special), keys (%$want_num));

my $modifier_template = Template->new({
    PARSER => Template::Parser::Greedy->new(PRE_CHOMP => 0, POST_CHOMP => 0)
});

########################## constants ######################

ok(CHOMP_GREEDY == 3, 'CHOMP_GREEDY == 3');
ok(CHOMP_COALESCE == 4, 'CHOMP_COALESCE == 4');

########################## constructor args ######################

for my $key (@chomps) {
    my @tests;

    if ($key eq 'undef_undef') {
        # 1) two undefined args: new(PRE_CHOMP => undef, POST_CHOMP => undef)
        push @tests, [
            Template->new({ PARSER => Template::Parser::Greedy->new(PRE_CHOMP => undef, POST_CHOMP => undef ) }),
            $arg_tt2,
            $want_special,
            "new(PRE_CHOMP => undef, POST_CHOMP => undef)"
        ];
    } elsif ($key eq '') {
        # 2) no args: new()
        push @tests, [
            Template->new({ PARSER => Template::Parser::Greedy->new() }),
            $arg_tt2,
            $want_special,
            "new()"
        ];
    } elsif ($key eq '_') {
        # 3) no modifiers: [% ... %]
        push @tests, [
            $modifier_template,
            "|$whitespace\[% '.' %]$whitespace|",
            $want_special,
            "\[% '.' %]"
        ];
    } else {
        my ($pre_num, $post_num) = split ('_', $key);
        my ($pre_mod, $post_mod) = @modifier{$pre_num, $post_num};

        for ([ $pre_num, $post_num, '' ], [ $pre_mod, $post_mod, "'" ]) {
            my $q = $_->[2];
            # numeric args 
            # modifier args 
            push @tests, [
                Template->new({ PARSER => Template::Parser::Greedy->new(PRE_CHOMP => $_->[0], POST_CHOMP => $_->[1]) }),
                $arg_tt2,
                $want_num,
                "new(PRE_CHOMP => $q$_->[0]$q, POST_CHOMP => $q$_->[1]$q)"
            ];
        }

        push @tests, [
            $modifier_template,
            "|$whitespace\[%$pre_mod '.' $post_mod%]$whitespace|",
            $want_num,
            "\[%$pre_mod '.' $post_mod%]"
        ];
    }

    for my $test (@tests) {
        my ($template, $tt2, $want, $description) = @$test;
        my $got = '';

        $template->process(\$tt2, {}, \$got) || die $template->error();
        $got =~ s/(\s)/$whitespace{$1}/eg;

        ok($got eq $want->{$key}, $description);
    }
}
