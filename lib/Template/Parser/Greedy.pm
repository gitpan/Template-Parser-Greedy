package Template::Parser::Greedy;

require 5.006; # for warnings

use strict;
use warnings;

use vars qw($VERSION @EXPORT_OK %EXPORT_TAGS);
use vars qw($CHOMP_MODIFIER $CHOMP_REPLACE $LEADING_WHITESPACE_REGEX $TRAILING_WHITESPACE_REGEX);

use base qw(Template::Parser Exporter);

use constant CHOMP_GREEDY	=> 3;
use constant CHOMP_COALESCE => 4;

use Template::Constants qw(:chomp);

$VERSION	 = '1.00';

@EXPORT_OK	 = qw(CHOMP_GREEDY CHOMP_COALESCE);
%EXPORT_TAGS = (all => [ @EXPORT_OK ]);

$CHOMP_MODIFIER = {
    '+'		=> CHOMP_NONE,
    '-'		=> CHOMP_ALL,
    '~'		=> CHOMP_GREEDY,
    '='		=> CHOMP_COLLAPSE,
    '^'		=> CHOMP_COALESCE
};

$CHOMP_REPLACE = {
    CHOMP_NONE,		'',
    CHOMP_ALL,		'',
    CHOMP_COLLAPSE,	' ',
    CHOMP_GREEDY,	'',
    CHOMP_COALESCE,	' '
};

$LEADING_WHITESPACE_REGEX = {
	CHOMP_NONE,		'',
	CHOMP_ALL,		qr{((?:\n?[ \t]+)|\n)$},
	CHOMP_GREEDY,	qr{(\s+)$},
	CHOMP_COLLAPSE,	qr{((?:\n?[ \t]+)|\n)$},
	CHOMP_COALESCE,	qr{(\s+)$}
};

$TRAILING_WHITESPACE_REGEX = {
	CHOMP_NONE,		'',
	CHOMP_ALL,		qr{^((?:[ \t]+\n?)|\n)},
	CHOMP_GREEDY,	qr{^(\s+)},
	CHOMP_COLLAPSE,	qr{^((?:[ \t]+\n?)|\n)},
	CHOMP_COALESCE,	qr{^(\s+)}
};

sub new {
    my $class = shift;
    my $config = ($_[0] && UNIVERSAL::isa($_[0], 'HASH')) ? shift : { @_ };

	for my $chomp (qw(PRE_CHOMP POST_CHOMP)) {
		my $arg = $config->{$chomp};

		if (defined $arg) {
			if (exists $CHOMP_MODIFIER->{$arg}) {
				$config->{$chomp} = $CHOMP_MODIFIER->{$arg};
			} else { # make sure it's a valid option
				# keyed on the valid CHOMP constants
				die "invalid $chomp option: '$arg'" unless (exists $CHOMP_REPLACE->{$arg});
			}
		} else {
			$config->{$chomp} = CHOMP_GREEDY;
		}
	}

    return $class->SUPER::new($config);
}

#------------------------------------------------------------------------
# split_text($text)
#
# Split input template text into directives and raw text chunks.
#------------------------------------------------------------------------

sub split_text {
    my ($self, $text) = @_;
    my ($pre, $dir, $prelines, $dirlines, $postlines, $tags, @tags);
    my $style = $self->{STYLE}->[-1];
    my ($start, $end, $prechomp, $postchomp, $interp) = @$style{qw(START_TAG END_TAG PRE_CHOMP POST_CHOMP INTERPOLATE)};
    my @tokens = ();
    my $line = 1;

    return \@tokens unless ((defined $text) && (length $text));

    # extract all directives from the text
    my $directive_regex = qr{
        ^(.*?)          # $1 - start of line up to directive
         (?:
            $start      # start of tag
            (.*?)       # $2 - tag contents
            $end        # end of tag
         )
    }sx;

    while ($text =~ s/$directive_regex//s) {
        ($pre, $dir) = map { defined $_ ? $_ : '' } ($1, $2);
        $postlines = 0; # denotes lines chomped
        $prelines = ($pre =~ tr/\n//); # NULL - count only
        $dirlines = ($dir =~ tr/\n//); # ditto

        # the CHOMP modifiers may modify the preceding text
        $dir =~ s/^([-+~=^\#])?\s*//s; # remove leading whitespace and check for a '-' chomp flag

        if ($1 && ($1 eq '#')) {
            $dir = ($dir =~ /([-+~=^])$/) ? $1 : ''; # comment out entire directive except for any chomp flag
        } else {
            my $chomp = $1 ? $CHOMP_MODIFIER->{$1} : $prechomp;
			if ($chomp) {
				my $space = $CHOMP_REPLACE->{$chomp};
				my $leading_whitespace_regex = $LEADING_WHITESPACE_REGEX->{$chomp};

				# remove (or collapse) the selected whitespace before the directive
				$pre =~ s/$leading_whitespace_regex/$space/;
			}
        }

        $dir =~ s/\s*([-+~=^])?\s*$//s; # remove trailing whitespace and check for a '-' chomp flag

        my $chomp = $1 ? $CHOMP_MODIFIER->{$1} : $postchomp;
		if ($chomp) {
			my $space = $CHOMP_REPLACE->{$chomp};
			my $trailing_whitespace_regex = $TRAILING_WHITESPACE_REGEX->{$chomp};

			if ($text =~ /$trailing_whitespace_regex/) {
				my $trailing_whitespace = $1;

				# increment the line counter if necessary
				$postlines += ($trailing_whitespace =~ tr/\n/\n/); 

				# now remove (or collapse) the selected whitespace after the directive
				$text =~ s/$trailing_whitespace_regex/$space/;
			}
		}

        # any text preceding the directive can now be added
        if (length $pre) {
            push (@tokens, $interp ? [ $pre, $line, 'ITEXT' ] : ('TEXT', $pre));
        }

        # moved out of the preceding conditional: we might have outstanding newlines
        # to account for even if $pre is now zero length
        $line += $prelines;

        # and now the directive, along with line number information
        if (length $dir) {
            # the TAGS directive is a compile-time switch
            if ($dir =~ /^TAGS\s+(.*)/i) {
                my @tags = split(/\s+/, $1);

                if (scalar @tags > 1) {
                    ($start, $end) = map { quotemeta($_) } @tags;
                } elsif ($tags = $self->SUPER::TAG_STYLE->{$tags[0]}) {
                    ($start, $end) = @$tags;
                } else {
                    warn "invalid TAGS style: $tags[0]\n";
                }
            } else {
                # DIRECTIVE is pushed as: [ $dirtext, $line_no(s), \@tokens ]
                push @tokens, [
                    $dir,
                    ($dirlines ? sprintf("%d-%d", $line, $line + $dirlines) : $line),
                    $self->tokenise_directive($dir)
                ];
            }
        }

        # update line counter to include directive lines and any extra
        # newline chomped off the start of the following text
        $line += $dirlines + $postlines;
    }

    # anything remaining in the string is plain text 
    push (@tokens, $interp ? [ $text, $line, 'ITEXT' ] : ('TEXT', $text))
        if (length $text);

    return \@tokens;
}
    
1;

__END__

=head1 NAME

Template::Parser::Greedy - reader/writer friendly chomping for TT2 templates

=head1 SYNOPSIS

    use Template;
    use Template::Parser::Greedy;

    my $parser = Template::Parser::Greedy->new();

    my $config = {
        PARSER       => $parser,
        INCLUDE_PATH => ...
    };

    my $template = Template->new($config);

    $template->process(...) || die $template->error();

=head1 DESCRIPTION

It's easy to write readable templates in L<Template::Toolkit|Template Toolkit>, and it's easy to exercise
fine-grained control over the output of Template Toolkit templates. Achieving both at the same time, however,
can be tricky given the default parser's whitespace chomping rules, which consume no more than one newline
character on either side of a directive.

This means that template authors optimizing for readability (and writability) may be obliged to compromise
the indentation and spacing of the output and I<vice versa>. 

This module allows templates to be laid out in a readable way, while at the same time enhancing control
over the spacing of the generated output. It does this by providing two new options, C<CHOMP_GREEDY> and
C<CHOMP_COALESCE>, and their corresponding directive modifiers, C<~> and C<^>.

In addition, a new modifier, C<=>, for the old CHOMP_COLLAPSE option has been added.

=head2 Options

This module is a drop-in replacement for L<Template::Parser|Template::Parser>, and is fully backwards
compatible if the original set of chomp options or modifiers are used. The only difference is in the
default values assigned for PRE_CHOMP and POST_CHOMP. Template::Parser defaults to not chomping, while
Template::Parser::Greedy defaults to chomping all contiguous whitespace characters. This behaviour can be
specified explicitly by passing a value of 3, or by importing the symbolic constant C<CHOMP_GREEDY> e.g,

    use Template::Parser::Greedy qw(CHOMP_GREEDY);

    my $parser = Template::Parser::Greedy->new(
        PRE_CHOMP    => CHOMP_GREEDY,
        POST_CHOMP   => 0
    );

In addition, Template::Parser::Greedy allows all old and new chomp options to be specified by means
of the corresponding directive modifier. Thus:

    my $parser = Template::Parser::Greedy->new(
        PRE_CHOMP    => '+',
        POST_CHOMP   => '='
    );

Corresponds to

    my $parser = Template::Parser::Greedy->new(
        PRE_CHOMP    => CHOMP_NONE,
        POST_CHOMP   => 2
    );

And:

    my $parser = Template::Parser::Greedy->new(
        PRE_CHOMP    => '~',
        POST_CHOMP   => '^'
    );

is equivalent to: 

    my $parser = Template::Parser::Greedy->new(
        PRE_CHOMP    => CHOMP_GREEDY,
        POST_CHOMP   => 4
    );

=head2 Modifiers

Greedy chomping can be relaxed or revoked on a per-directive basis in templates that are greedy by default.
Likewise, greedy chomping can be selectively enabled in non-greedy templates by using the C<~> and C<^>
modifiers.

e.g.

    my $parser = Template::Parser::Greedy->new(
        PRE_CHOMP    => 2,
        POST_CHOMP   => 0
    );

    my $template = Template->new({ PARSER => $parser });

And, in the template:

    [BLOCK foo %]

        [%- IF 1 ~%]

            bar

        [%~ END +%]

    [% END %]

In this example, the C<~> modifier consumes all of the whitespace around the embedded text, and is
thus equivalent to:

    [%- IF 1 %]bar[% END +%]

The C<+> modifier at the end of the C<IF> block turns on C<CHOMP_NONE> for the suffixed whitespace,
which is therefore not chomped; and the C<-> modifier at the beginning of the C<IF> performs
a C<CHOMP_COLLAPSE> chomp, which collapses the indentation and one newline to a single space,
but leaves the whitespace before that intact.

Template::Parser does not provide a directive modifier for CHOMP_COLLAPSE, but it can be enabled
in Template::Parser::Greedy templates by using C<=>. e.g.

    [% IF 1 =%]

        ...

    [%= END %]

The greedy version of this modifier is C<^>. This can also be set globally by supplying a PRE/POST_CHOMP
value of 4, which is also available as the symbolic constant C<CHOMP_COALESCE>.

    use Template::Constants (:chomp);
    use Template::Parser::Greedy qw(CHOMP_COALESCE);

    my $parser = Template::Parser::Greedy->new(
        PRE_CHOMP    => CHOMP_COLLAPSE,
        POST_CHOMP   => CHOMP_COALESCE
    );

If both CHOMP_GREEDY and CHOMP_COALESCE are needed, they can be imported by using the C<:all> tag:

    use Template::Parser::Greedy qw(:all);

=head1 USAGE

As with the default parser, any whitespace inside the preceding or following text is preserved,
so boilerplate only needs to concern itself with its surrounding whitespace.

This leaves indentation and newlines under the explicit control of the template author, by any of the
mechanisms available in the Template technician's toolkit e.g. by using explicit newline and
indentation directives:

    [% nl = "\n" %]

    [% BLOCK foo %] [%# params: bar, indent %]
        [% outer = tab(indent) %]
        [% inner = tab(add(indent, 1)) %]
        [% outer %]

        <foo>
            [% FOR baz IN bar %]

                [% nl %] [% inner %]
                <bar baz="[% baz %]" />

            [% END %] [% nl %] [% outer %]
        </foo>
        
    [% END %]

Or by selectively turning off left and/or right chomping:

    [% IF 1 +%]

        ------------------------------------
        | alpha | beta | gamma | vlissides |
        ------------------------------------
        |  foo  | bar  |  baz  |    quux   |
        ------------------------------------

    [%+ END %]

Unlike their non-greedy counterparts, the CHOMP_GREEDY and CHOMP_COALESCE options and directives
happily digest carriage returns (along with [\n\f\t ]), so they are less likely to
do the wrong thing on non-Unix platforms.

=head1 SEE ALSO

=over

=item * L<Template|Template> 

=item * L<Template::Parser|Template::Parser> 

=item * L<Template::Parser::LocalizeNewlines|Template::Parser::LocalizeNewlines>

=item * http://www.mail-archive.com/templates@template-toolkit.org/msg07575.html

=item * http://www.mail-archive.com/templates@template-toolkit.org/msg07659.html

=back

=head1 VERSION

1.00

=head1 AUTHOR

chocolateboy E<lt>chocolate.boy@email.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by chocolateboy

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
