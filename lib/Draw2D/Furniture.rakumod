unit module Draw2D::Furniture;

use PostScript::File:from<Perl5>;
use Text::Utils :strip-comment, :normalize-string;

# default values settable in the input data file
# or in the drives program
our $in-per-ft is export = 0.25;

my $ofilL = 'furniture-list';
my $ofilD = 'furniture-drawings';

# forward decls
class Row {...};
class Room {...};
class Furniture {...};

#==============================================================
sub write-drawings($fbase, # file name base, no suffix
                   @rooms,
                   @ofils,
                   :$debug,
                   :$ofilD, # basename
                  ) is export {

    my $psf = $fbase ~ '.ps';
    my $pdf = $fbase ~ '.pdf';

    # start a doc, add options here
    #   enable clipping
    my $ps = PostScript::File.new: :paper<Letter>,
               :clipping(1), :clip_command<stroke>,
               :landscape(0), :file($psf) :file_ext("");

    # setup any prolog such as my
    # procs: box, circle, puttext, clip, fonts
    $ps.add_procset: "MyFunctions", q:to/HERE/;
    %% my procs
    % local definitions:
    /Times-Roman 8 selectfont
    2 setlinewidth % we'll clip the drawings so we just see the inside half
    /bd{bind def} bind def
    /a{add}bd
    /cl{currentlinewidth}bd
    /cpt{currentpoint}bd
    /cp{closepath}bd
    /dv{div}bd
    /d{def}bd
    /ex{exch}bd
    /gr{grestore}bd
    /gs{gsave}bd
    /lto{lineto}bd
    /mt{moveto}bd
    /m{mul}bd
    /n{neg}bd
    /np{newpath}bd
    /rl{rlineto}bd
    /rm{rmoveto}bd
    /rot{rotate}bd
    /sg{setgray}bd
    /sh{show}bd
    /sl{setlinewidth}bd
    /st{stroke}bd
    /s{sub}bd
    /tr{translate}bd
    /i2p{72 m}bd % convert inches to points
    /puttextdict 50 dict def
    /puttext { % Stack: string location_code
               % (position to place--relative to the current point [cp],
               %   an integer: 0-11);
               % note: must have defined a current and correct font
      puttextdict begin
      /code ex d
      /stname ex d
      gs
      cpt tr np
      0 0 mt stname false charpath flattenpath pathbbox
      /ury ex d
      /urx ex d
      /lly ex d
      /llx ex d
      /mx urx llx a .5 m d
      /my ury lly a .5 m d

      0 code eq {/ox 0 mx  s d /oy 0 my  s d} if %               center of text bbox positioned at the cp
      1 code eq {/ox 0 llx s d /oy 0 my  s d} if %  center of left edge of text bbox positioned at the cp
      2 code eq {/ox 0 llx s d /oy 0 lly s d} if %    lower left corner of text bbox positioned at the cp
      3 code eq {/ox 0 mx  s d /oy 0 lly s d} if % center of lower edge of text bbox positioned at the cp
      4 code eq {/ox 0 urx s d /oy 0 lly s d} if %   lower right corner of text bbox positioned at the cp
      5 code eq {/ox 0 urx s d /oy 0 my  s d} if % center of right edge of text bbox positioned at the cp
      6 code eq {/ox 0 urx s d /oy 0 ury s d} if %   upper right corner of text bbox positioned at the cp
      7 code eq {/ox 0 mx  s d /oy 0 ury s d} if % center of upper edge of text bbox positioned at the cp
      8 code eq {/ox 0 llx s d /oy 0 ury s d} if %    upper left corner of text bbox positioned at the cp
      9 code eq {/ox 0 llx s d /oy 0       d} if % on base line (y of cp), left-justified on cp
     10 code eq {/ox 0 mx  s d /oy 0       d} if % on base line (y of cp), centered horizontally
     11 code eq {/ox 0 urx s d /oy 0       d} if % on base line (y of cp), right-justified on cp
      % use an easier to remember code instead of 9, 10, 11
    /blj 9 def /bc 10 def /brj 11 def
    blj code eq {/ox 0 llx s d /oy 0       d} if % on base line (y of cp), left-justified on
     bc code eq {/ox 0 mx  s d /oy 0       d} if % on base line (y of cp), centered horizontally
    brj code eq {/ox 0 urx s d /oy 0       d} if % on base line (y of cp), right-justified on cp

      ox oy tr

      gs
      0 sg
      np 0 0 mt stname sh
      gr

      gr
      end % required to pop the dict
    }bd % puttext
    % circle
    /circledict 50 dict def
    /circle { % Stack: cx cy rad
      circledict begin
      /rad ex d
      /cy ex d
      /cx ex d
      gs
      np cx cy rad 0 360 arc clip st
      gr
      end % required to pop the dict
    }bd % circle
    % box
    /boxdict 50 dict def
    /box { % Stack: ulx uly width height
      boxdict begin
      /height ex d
      /width ex d
      /uly ex d
      /ulx ex d
      gs
      np ulx uly mt
      0 height neg rlineto
      width 0 rlineto
      0 height rlineto
      closepath clip st
      gr
      end % required to pop the dict
    }bd % box

    % various font defs
    HERE

    # page constants
    # page margins
    my $marg = 0.4; # inches
    my $space   =  0.2 * 72; # vert and horiz space between figures
    my $xleft   =  $marg * 72;
    my $xright  =  (8.5 - $marg) * 72;
    my $ytop    =  (11 - $marg) * 72;
    my $ybottom =  $marg * 72;

    # page variables
    my ($x, $y);

    # start a page
    sub reset-page-vars {
        # resets to upper left of the page
        $x = $xleft;
        $y = $ytop;
    }
    # start a row
    sub reset-row-var {
        # resets to left of the page
        $x = $xleft;
    }
    sub check-bottom(Row $r, $y --> Bool) {
        # given a row instance and its y start
        # point, can it fit on # the current row?
        my $ybot = $y - $r.max-height;
        return $ybot >= $ybottom;
    }

    # collect furniture by page rows
    my @rows;
    make-rows @rows, @rooms, $xright - $xleft, $space;
    my $nrows = +@rows;
    die "FATAL: no rows collected!" if !$nrows;
    note "DEBUG: num rows: {$nrows}" if $debug;

    # step through all the furniture and number each as in the index
    # keep track of:
    #   last baseline
    reset-page-vars;
    my $i = 0;
    for @rows -> $r {
        reset-row-var;
        ++$i;
        if $debug {
            note "DEBUG: row $i max-height: {$r.max-height}";
            note "              furn items: {$r.furniture.elems}";
            note " start x/y: $x $y";
        }
        if !check-bottom($r, $y) {
            # need a new page
            reset-page-vars;
            $ps.newpage;
        }
        for $r.furniture -> $f {
            my $num = "{$f.number}";
            my $dim = "{$f.dims}";

            # draw it at the current ulx, uly
            $f.ps-draw: $ps, :ulx($x), :uly($y);
            # increment x
            $x += $f.w + $space
        }

        $y -= $r.max-height + $space;
    }

    $ps.output;

    # produce the pdf
    die "FATAL: File $psf not found" if !$psf.IO.f;
    my $cmd  = "ps2pdf";
    my $args = "$psf $pdf";
    run $cmd, $args.words;

    die "FATAL: File $pdf not found" if !$pdf.IO.f;
    @ofils.append: $pdf;
    unlink $psf unless 1 or $debug;

} # end sub write-diags

sub write-list($fbase, # file name base, no suffix
               @rooms,
               @ofils,
               :$debug
               ) is export {

    # write the raw text file
    my $nitems = 0;
    my $txt = $fbase ~ '.txt';
    my $fh = open $txt, :w;
    for @rooms -> $r {
        if $r.number == 8 {
            # kludge to get  rom name on second page
            $fh.say: "";
        }
        $fh.say: "  Room {$r.number}: {$r.title}";
        for $r.furniture -> $f {
            ++$nitems; # cumulative number
            my $num = "{$f.number}";
            $fh.say: "      $num {$f.title} [{$f.dims}]";
        }
    }
    $fh.say: "\nTotal number items: $nitems";
    $fh.close;

    my $ps  = $fbase ~ '.ps';
    my $pdf = $fbase ~ '.pdf';

    my ($cmd, $args);
    $cmd  = "a2ps";
    $args = "--portrait --columns=1 -o $ps $txt";
    # note a2ps always writes to stderr even with no problems
    # turn stderr on if problems are noted in the output
    run $cmd, $args.words, :err;

    # produce the pdf
    die "FATAL: File $ps not found" if !$ps.IO.f;
    $cmd  = "ps2pdf";
    $args = "$ps $pdf";
    run $cmd, $args.words;

    die "FATAL: File $pdf not found" if !$pdf.IO.f;
    @ofils.append: $pdf;
    unlink $txt unless $debug;
    unlink $ps unless $debug;

} # end sub write-list

sub read-data-file($ifil, @rooms, :$debug) is export {
    my $curr-room = 0;
    my $rnum = 0;
    my $lnum = 0;
    my $fnum = 0;
    LINE: for $ifil.IO.lines -> $line is copy {
        $line = strip-comment $line;
        next LINE if $line !~~ /\S/;
        next LINE if $line ~~ /^'='+$/;
        say "DEBUG line: '$line'" if 0 && $debug;

        if $line ~~ /^ \s* 'room:' (.*) $/ {
            # a new room
            ++$rnum;
            $curr-room = Room.new: :number($rnum), :title(normalize-string(~$0));
            @rooms.append: $curr-room;

            # reset furniture numbering
            $fnum = 0;

            next LINE;
        }
        if $line ~~ /^ \s* 'title:' (.*) $/ {
            next LINE;
        }
        if $line ~~ /^ \s* 'date:' (.*) $/ {
            next LINE;
        }
        if $line ~~ /^ \s* 'author:' (.*) $/ {
            next LINE;
        }
        if $line ~~ /^ \s* 'address:' (.*) $/ {
            next LINE;
        }
        if $line ~~ /^ \s* 'scale:' (.*) $/ {
            die "WARNING: user scale NYI";
            next LINE;
        }

        # it must be a piece of furniture
        ++$fnum;
        # its display number will be: {$rnum}.{$fnum}
        my $furn = Furniture.new: :scale($in-per-ft), :number("{$rnum}.{$fnum}");
        my ($wid, $len, $dia, $rad);
        if $line ~~ /^(.*) [<|w> (\d+) \s+ 'x' \s+ (\d+)] \s* $/ {
            $furn.title = normalize-string(~$0);
            $wid  = +$1;
            $len  = +$2; # horizontal on the portrait page, it will be
                         # forced to be the longest dimen
            if $len < $wid {
                ($wid, $len) = ($len, $wid);
            }
            $furn.width  = $wid;
            $furn.length = $len;
            $furn.dims   = "$wid\" x $len\"";

            my $ww = in2ft $wid;
            my $ll = in2ft $len;
            $furn.dims2  = "{$ww}x{$ll}";
        }
        elsif $line ~~ /^(.*) [<|w> (\d+) \s+ 'd'] \s* $/ {
            $furn.title    = normalize-string(~$0);
            $furn.diameter = +$1;
            $furn.dims     = "{$furn.diameter}\" diameter";
            $furn.radius   = 0.5 * $furn.diameter;
            my $ww = in2ft $furn.diameter;
            $furn.dims2  = "{$ww}";
        }
        elsif $line ~~ /^(.*) [<|w> (\d+) \s+ 'r'] \s* $/ {
            $furn.title = normalize-string(~$0);
            $furn.radius = +$1;
            $furn.dims = "{$furn.radius}\" radius";
            my $ww = in2ft 2 * $furn.radius;
            $furn.dims2  = "{$ww}";
        }
        else {
            say "FATAL on line $lnum: '$line'";
            die "  Unknown format";
        }
        # INIT FURNITURE - CRITICAL
        $furn.init; # CRITICAL!!

        # handle the furniture
        $curr-room.furniture.append: $furn;
    }

} # end sub read-data-file

class Row {
    has $.max-height is rw = 0; # PS points
    has @.furniture is rw;
}

class Room {
    has $.number    is rw ;
    has $.title     is rw = "";
    has @.furniture is rw ;
}

class Furniture {
    has $.number    is rw;
    has $.title     is rw = "";
    # input dimensions are inches
    has $.width     is rw = 0;
    has $.length    is rw = 0;
    has $.diameter  is rw = 0;
    has $.radius    is rw = 0;
    has $.dims      is rw = ''; # for printing
    has $.dims2     is rw = ''; # for printing
    # input scale is in page inches per real foot
    has $.scale; # must be input when created
    # internal bbox values in properly-scaled PS points
    has $.w is rw;
    has $.h is rw;
    has $.sf is rw; # scale factor

    method init() {
        # must have required inputs
        die "FATAL: incomplete inputs" if !($.width || $.radius);
        $.sf = 72 / (12 / $.scale);
        if $.radius {
            # apply scale
            $.w = $.radius * 2 * $.sf;
            $.h = $.w;
        }
        else {
            # apply scale
            $.h = $.width * $.sf;
            $.w = $.length * $.sf;
        }
    }

    # A method to draw itself in raw PS
    # using a $ps instance of a Perl
    # PostScript::File object
    # given the llx and lly corner of its
    # bounding box in real page coords
    # and orientation:
    # adjust the scale to 1/4" per foot, then 72 pts per page inch

    # a 1 foot desk = 12 inches
    # 12 inches scales to 0.25 inches on paper: 1/48
    # 1 inch = 72 points
    # 0.25 inches = 16 points
    # so what do we multiply model inches by to get it correct on paper?
    # scale = 48/72
    #my $scale = 48/72; # <== 48 / 72 <== 12 / 0.25 / 72 # where 0.25 = $in-per-ft
    #my $scale = 12 / $in-per-ft / 72; # where 0.25 = $in-per-ft
    method ps-draw($ps, :$ulx, :$uly) {
        my $cx = $ulx + 0.5 * $.w;
        my $cy = $uly - 0.5 * $.h;
        my $d = 2;
        # put number $d pt above center
        # put dimen rep $d pt below center
        my $s = qq:to/HERE/;
        /Times-Bold 9 selectfont
        $cx $cy $d add mt ({$.number}) 3 puttext
        /Times-Roman 7 selectfont
        $cx $cy $d sub mt ({$.dims2}) 7 puttext
        HERE
        if $.width {
            $s ~= qq:to/HERE/;
            $ulx $uly {$.w} {$.h} box
            HERE
        }
        elsif $.radius {
            # note that an original furniture piece entry may
            # have specified a diameter but a radius was also
            # calculated and entered.

            # draw a circle centered on the bounding box
            $s ~= qq:to/HERE/;
            $cx $cy {$.w * 0.5} circle
            HERE
        }
        $ps.add_to_page: $s;
    }
}

sub make-rows(@rows,   # should be empty
              @rooms,  # all rooms with their furniture
              $maxwid, # distance between left/right page margins
              $space) {

    @rows   = [];
    my $row = Row.new;
    @rows.append: $row;
    # row var
    my $x = 0; # begin at left margin

    sub reset-row-var {
        # resets to left of the page
        $x = 0;
    }
    sub check-right(Furniture $f, $x --> Bool) {
        # given a furniture instance and its x start
        # point, can it fit on # the current row?
        my $xspace = $x + $f.w;
        return $xspace <= $maxwid;
    }

    reset-row-var;
    for @rooms -> $r {
        for $r.furniture -> $f {
            $x += $space if $row.furniture.elems;
            if !check-right($f, $x) {
                # need a new row
                $row = Row.new;
                @rows.append: $row;
                reset-row-var;
            }

            # update row data
            $x += $f.w;
            $row.furniture.append: $f;
            $row.max-height = $f.h if $f.h > $row.max-height;
        }
    }
} # end sub make-rows

sub in2ft($In) {
    # given inches, convert to a string representation like
    #   7'2
    my $ft = $In div 12;
    my $in = $In mod 12;
    return "{$ft}'{$in}";
}
