#!/usr/bin/env raku

#use Grammar::Tracer;
#use Grammar::Debugger;

=begin comment
==============
room: Master bedroom
 # comment
Missy's chest of drawers {M's drsr}	19 x 64
bedside table			        25 d      # (diameter)
lounge chair			        21 x 49
table, drop-leaf oak (open)	42 e 51 # ellipse
rocker, platform	        22 x 30.2

desk (by bed)			        20 r      # radius
t    20 r      # radius
    20.2 r
=end comment

my $s = q:to/HERE/;
t    20 r      # radius
    20.2 r
 some text 6x4
HERE

class DLA {
    method dimension($/) {
        # split the leading text into <description> 
        say "DEBUG grammar dimension action: |{~$/}|";
    }
}

grammar DL {
    regex TOP {
        \s* 
        [
        | <.blank-line>
        | <.comment>
        | <furniture>
        | <room>
        ]
        \s*
    }

    regex furniture {
        <furn-text> <dimension> <.comment>?
    }

    regex furn-text {
        # must have at least one non-space
        \S <-[\d]>*
    }
    token room {
        ^ \s* 'room:' \N* <comment>?
    }

    # dimension grammar
    token dimension {
        <number> \s* <dimen-symbol> \s* <number>? <.ws>? $
        #<number> \s* <dimen-symbol> \s* <number>? <.ws>? $
        #<number> \s* <dimen-symbol> \s* <number>? <.ws>? $
    }
    token dimen-symbol {
        d|r|x|e
    }
    # number grammar
    token integer { 
        \d+ 
    }
    token radix-point {
        '.'|','
    }
    token floating-point {
        <integer>? <radix-point> <integer>
    }
    token number {
        | <integer>
        | <floating-point>
    }
    token ws {
        | <blank-line>
        | <comment>
    }

    # whitespace
    token blank-line {
         ^ \s* $
    }
    token comment {
        | ^ \s* '#' \N* $
        | '#' \N* $
        | ^ \s* '='+ \s* $
    }
}

=begin comment
}

    token short-name {
        '{' \N* '}'
    }
    token furniture {
        <description>? [<short-name> <description>?]? <dimension>
    }


}
=end comment


my $ifil = 'test-furniture-input.txt';

my $prog = $*PROGRAM.basename;
if !@*ARGS.elems {
    say qq:to/HERE/;
    Usage: $prog go

    Tests the grammar on the data line in the input file:
      $ifil

    Using Andrew Shitov's book online here:
      <https://https://andrewshitov.com/2020/02/23/chapter-1-creating-a-simple-interpreter/>
    HERE
    exit;
}

#my @lines = $ifil.IO.lines;
my @lines = $s.lines;
for @lines -> $line {
    my $res = DL.parse: $line, :actions(DLA.new); #, :rule<dimension>;
    note "[$line] =>";
    note $res ?? $res !! 'Parse Failed!';
}


=finish
my $code = slurp $ifil;
my $res = Draw.parse: $code;
say $res;
grammar Draw {
    rule TOP {
        <statement>* <comment>* %% \n
    }
    rule statement {
        | <furniture>
        | <room>
    }
    token number {
        <|w> \s* \d+ [['.'|','] \d*]? \s* <|w>
    }
    token dimension {
        <|w> \s* <number> \s* <dimen-symbol> \s* <number>? \s* <|w>
    }
    token furniture {
        ^ <descript> <short-name>? <dimension>
    }
    token dimen-symbol {
        d|r|x|e
    }
    token descript {
        ^ N+ <!after before $<
    }
}
