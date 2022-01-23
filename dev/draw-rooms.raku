#!/usr/bin/env raku

use Text::Utils :strip-comment, :normalize-string, :count-substrs;

class Rdata {
    has $.title;
    has $.width;
    has $.depth;
}

my $debug = 0;
my $ifil = "./room.data";
my $scale = 0.1837; # in/ft

if not @*ARGS {
    say qq:to/HERE/;
    Usage:  {$*PROGRAM.basename} go [infile=A][scale=S] [debug]

    Creates a set of scaled room diagrams at {$scale}-inch per foot
    or at the user-selected decimal scale 'S'.

    The input data are in file '$ifil' or in the user-selected file 'A'.
    HERE
    exit;
}

for @*ARGS {
    when /^s \S+ '=' (\d? ['.' \d?]?) $/ {
        $scale = +$0
    }
    when /^i \S+ '=' (\S+) $/ {
        $ifil = ~$0
    }
    when /d/ { $debug = 1 }
    default {
        die "FATAL: Unknown arg '$_'"
    }
}

die "FATAL: Unable to read input file '$ifil'." if not $ifil.IO.r;
my @rooms = read-file $ifil;
my $ofil  = "room-diagrams";

sub read-file($f --> List) {
    my @arr;
    for $f.IO.lines -> $line is copy {
        $line = strip-comment $line;
        next if $line !~~ /\S/;
        my $n = count-substrs $line, ',';
        die "FATAL: Line '$line' needs exactly two apostrophes" if $n != 2;
        my @w = split ',', $line;;
        note "DEBUG: before normalize: '{@w.raku}'" if $debug;
        my $nw = @w.elems;
        for @w.kv -> $i, $w {
            @w[$i] = normalize-string $w;
        }
        note "       after normalize:  '{@w.raku}'" if $debug;
        my $r = Rdata.new: :title(@w[0]), :depth(@w[1]), :width(@w[2]);
        @arr.push: $r;
    }
    if $debug {
        note "DEBUG: early exit";exit;
    }
    @arr
}


