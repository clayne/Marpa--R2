#!/usr/bin/env perl
# Copyright 2014 Jeffrey Kegler
# This file is part of Marpa::R2.  Marpa::R2 is free software: you can
# redistribute it and/or modify it under the terms of the GNU Lesser
# General Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Marpa::R2 is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser
# General Public License along with Marpa::R2.  If not, see
# http://www.gnu.org/licenses/.

# This example searches for mismatched braces --
# curly, square and round.

use 5.010;
use strict;
use warnings;
use Marpa::R2 2.097_002;
use Data::Dumper;
use Test::More tests => 3;
use Getopt::Long ();

my $verbose;
die if not Getopt::Long::GetOptions( verbose => \$verbose );

my $grammar = << '=== GRAMMAR ===';
:default ::= action => [ name, value ]
lexeme default = action => [ name, value ] latm => 1 # to add token names to ast

text ::= pieces
pieces ::= piece*
piece ::= filler | balanced

balanced ::= 
    lparen pieces rparen
  | lcurly pieces rcurly
  | lsquare pieces rsquare

# x5b is left square bracket
# x5d is right square bracket
filler ~ [^(){}\x5B\x5D]+

lparen ~ '('
rparen ~ ')'
lcurly ~ '{'
rcurly ~ '}'
lsquare ~ '['
rsquare ~ ']'

=== GRAMMAR ===

my $g = Marpa::R2::Scanless::G->new( { source => \($grammar) } );

my @tests = (
    [ 'z}ab)({[]})))(([]))zz', q{} ],
    [ '9\090]{[][][9]89]8[][]90]{[]\{}{}09[]}[', q{} ],
    [ '([]([])([]([]', q{}, ],
    [ '([([([([', q{}, ],
);

for my $test (@tests) {
    my ( $string, $expected_result ) = @{$test};
    my $actual_result = test( $g, $string );
    diag("Input: $string") if $verbose;
    Test::More::is( $actual_result, $expected_result,
        qq{Result of "$string"} );
} ## end for my $test (@tests)

sub test {
    my ( $g, $string ) = @_;
    $DB::single = 1;
    my @found = ();
    diag("Input: $string") if $verbose;
    my $input_length = length $string;
    my $pos          = 0;

    my %tokens = ();
    my %matching = ();
    for my $char (split //xms, '(){}[]') {
        $tokens{$char} = [ ( length $string ), 1 ];
        $string .= $char;
    }
    for my $pair (qw% () [] {} %) {
        my ($left, $right) = split //xms, $pair;
        $matching{$left} = $tokens{$right};
        $matching{$right} = $tokens{$left};
    }

    state $recce_debug_args = { trace_terminals => 1, trace_values => 1 };
    # state $recce_debug_args = {};

    # One pass through this loop for every target found,
    # until we reach end of string without finding a target

    my $recce = Marpa::R2::Scanless::R->new(
        {   grammar   => $g,
            rejection => 'event',
        },
        $recce_debug_args
    );
    $pos = $recce->read( \$string, $pos, $input_length );

    READ: while ( $pos < $input_length ) {

        say STDERR join " ", __LINE__, "pos=$pos";

        EVENT:
        for my $event ( @{ $recce->events() } ) {
            my ($name) = @{$event};
            if ( $name eq q{'rejected} ) {
                my $nextchar = substr $string, $pos, 1;
                my $token = $matching{$nextchar};
                die "Rejection at pos $pos: ", substr( $string, $pos, 10 )
                    if not defined $token;
                my $result = $recce->resume( @{$token} );
                die "Read of Ruby slippers token failed"
                    if $result != $token->[0] + 1;
                next EVENT;
            } ## end if ( $name eq q{'rejected} )
            die join q{ }, "Spurious event at position $pos: '$name'";
        } ## end EVENT: for my $event ( @{ $recce->events() } )

        $pos = $recce->resume( $pos, $input_length - $pos );
        say STDERR join " ", __LINE__, "pos=$pos";

    } ## end READ: while ( $pos < $input_length )

} ## end sub test

# vim: expandtab shiftwidth=4: