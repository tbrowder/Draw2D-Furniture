unit module Draw2D::Furniture;

use PostScript::File:from<Perl5>;
use Text::Utils :strip-comment, :normalize-string;

use Draw2D::Furniture::Vars;
use Draw2D::Furniture::Classes;

# default values settable in the input data file
# or in the driver program
our $in-per-ft is export = 0.25;

# default values settable in the input data file
my $basename = ''; # if not entered, the project title will be used to create it
# the default file extensions:
my $ofilL    = 'furniture-list';
my $ofilD    = 'furniture-drawings';
# the project title:
my $ftitle   = '';

# other data
my $author   = '';
my $date     = '';
my $address  = '';
my $address2 = '';
my $address3 = '';

#==============================================================
#| Data from the input data file are used to create scaled
#| drawings of the furniture items.
sub write-drawings(@rooms,
                   @ofils,
                   :$debug,
                   :$squeeze,
                  ) is export {

    my $fbase = $ofilD; # file name base, no suffix

    my $psf = $fbase ~ '.ps';
    my $pdf = $fbase ~ '.pdf';

    # start a doc, add options here
    #   enable clipping
    my $ps = PostScript::File.new:
               :paper<Letter>,
               :clipping(1),
               :clip_command<stroke>,
               :landscape(0),
               :file($psf),
               :file_ext("");

    die "FATAL: no PS object" if not $ps;

    # for debugging count furniture items
    my $nfurn = 0;

    if $debug {
        my ($llx, $lly, $urx, $ury) = $ps.get_bounding_box;
        note "DEBUG drawing page bbox: $llx, $lly    $urx, $ury";
    }

    # setup any prolog such as my
    # procs: box, circle, puttext, clip, fonts
    $ps.add_procset: "MyFunctions", $procset;

    # page constants
    # page margins
    my $marg    =  0.4; # inches
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
    my $nrows = @rows.elems;
    die "FATAL: no rows collected!" if !$nrows;
    note "DEBUG: num furniture rows: {$nrows}" if 1 or $debug;

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
            ++$nfurn;
            my $num = "{$f.number}";
            my $dim = "{$f.dims}";

            # draw it at the current ulx, uly
            $f.ps-draw: $ps, :ulx($x), :uly($y);
            # increment x
            $x += $f.w + $space
        }

        $y -= $r.max-height + $space;
    }
    # close and ouput the file
    $ps.output;

    # produce the pdf
    die "FATAL: File $psf not found" if !$psf.IO.f;
    my $cmd  = "ps2pdf";
    my $args = "$psf $pdf";
    run $cmd, $args.words;

    die "FATAL: File $pdf not found" if !$pdf.IO.f;
    @ofils.push: $pdf;
    unlink $psf unless  $debug;

    note "DEBUG: saw $nfurn furniture objects" if 1 or $debug;
} # end sub write-drawings

#| A function to convert a text file into PostScript and that PS file
#| to PDF.
sub text-to-pdf($txtfil,
                @ofils,
                :$debug
               ) is export {

    my $fbase = $ofilL; # file name base, no suffix
    my $psf   = $fbase ~ '.ps';
    my $pdf   = $fbase ~ '.pdf';

    # write the ps file
    # start a doc, add options here
    #   enable clipping but no border
    my $pw = 8.5 * 72;
    my $ph = 11 * 72;
    my $b  = 0; #70; # border
    my $ps = PostScript::File.new:
               :width($pw),
               :height($ph),
               :bottom($b),
               :top($b),
               :left($b),
               :right($b),
               :clipping(1),
               :clip_command(''), # or 'stroke' to show the page boundaries
               :landscape(0),
               :file($psf),
               :file_ext("");

    if $debug {
        my ($llx, $lly, $urx, $ury) = $ps.get_bounding_box;
        note "DEBUG listing page bbox: $llx, $lly    $urx, $ury";
    }

    # setup any prolog such as my
    # procs: box, circle, puttext, clip, fonts
    $ps.add_procset: "MyFunctions", $procset;

    # page constants
    # page margins
    my $marg    =  1.0; # inches
    my $xleft   =  $marg * 72;
    my $xright  =  (8.5 - $marg) * 72;
    my $ytop    =  (11 - $marg) * 72;
    my $ybottom =  $marg * 72 + 20; # allow 25 points for a page number

    # font variables
    my $font   = 'Times-Roman';
    my $fsize  = 12;
    my $lspace = $fsize * 1.3; # baseline to baseline distance
    my $ytopbaseline = $ytop - $lspace;

    $ps.add_to_page: "/$font $fsize selectfont\n";

    # page variables
    my ($x, $y);

    my $npages = 0;
    # start a page
    sub reset-page-vars {
        # resets to upper left of the page
        $x = $xleft;
        $y = $ytopbaseline;
        ++$npages;
    }
    # start a row
    sub reset-row-var {
        # resets to left of the page
        $x = $xleft;
    }
    sub check-bottom($yy --> Bool) {
        # given a text row and its y start
        # point, can it fit on the current page?
        my $ybot = $yy - $lspace;
        my $res = $ybot >= $ybottom;
        note "DEBUG check-bottom: y = $yy; ybot = $ybot; ybottom = $ybottom; res = $res" if $debug;
        return $res;
    }

    # step through all rows of text
    # keep track of:
    #   last baseline
    reset-page-vars;
    $ps.add_to_page: "/$font $fsize selectfont\n";
    for $txtfil.IO.lines -> $line {
        my $ff = $line ~~ /:i '<ff>' / ?? 1 !! 0;
        note "DEBUG: ff = $ff" if $debug;
        # some analysis here:
        #   if $line contains '<ff>' make a new page
        # otherwise, we need to translate leading space
        #   chars to an x indent space
        reset-row-var;
        my $res = check-bottom($y);
        if $ff || !$res {
            # need a new page
            reset-page-vars;
            $ps.newpage;
            $ps.add_to_page: "/$font $fsize selectfont\n";
        }
        next if $ff;

        # write the line or skip a line space for a blank line
        if $line !~~ /\S/ {
            ; # no entry but vspace
        }
        elsif $line ~~ /^ (\s+) (.*) $/ {
            my $spaces = ~$0;
            my $text   = ~$1;
            my $xx = $spaces.chars * $fsize;
            $ps.add_to_page: "{$x + $xx} $y mt ($text) 9 puttext\n";
        }
        else {
            $ps.add_to_page: "$x $y mt ($line) 9 puttext\n";
        }
        $y -= $lspace;
        note "DEBUG: y = $y" if $debug;
    }

    note "DEBUG: num pages: $npages" if $debug;
    # go back and add page numbers:
    #   Page x of n

    for 1..$npages -> $page {
        my $s = "Page $page of $npages";
        $ps.add_to_page: $page, qq:to/HERE/;
        /Times-Roman 10 selectfont $xright $ybottom 25 sub mt ($s) 11 puttext
        HERE
    }

    # close and output the file
    $ps.output;

    # produce the pdf
    die "FATAL: File $psf not found" if !$psf.IO.f;
    my $cmd  = "ps2pdf";
    my $args = "$psf $pdf";
    run $cmd, $args.words;

    die "FATAL: File $pdf not found" if !$pdf.IO.f;
    @ofils.push: $pdf;
    unlink $txtfil unless $debug;
    unlink $psf unless $debug;

} # end sub text-to-pdf

#| Given a list of Room objects (with their Furniture object
#| children), create a text file of all items including a unique
#| reference number for each.
#|
#| This sub then calls another sub to convert the text file to
#| PostScript and that PS file to PDF.
sub write-list(@rooms,
               @ofils,
               :$debug
              ) is export {

    my $fbase = $ofilL; # file name base, no suffix

    # write the raw text file
    my $nitems = 0;
    my $txtfil = $fbase ~ '.txt';
    my $fh = open $txtfil, :w;

    # title, etc.
    if $ftitle {
        $fh.say: "Title: $ftitle";
    }
    if $author {
        $fh.say: "Author: $author";
    }
    if $date {
        $fh.say: "Date: $date";
    }
    if $address {
        $fh.say: "Address:  $address";
    }
    if $address2 {
        $fh.say: "Address2: $address2";
    }
    if $address3 {
        $fh.say: "Address3: $address3";
    }
    $fh.say: "";

    for @rooms -> $r {
        $fh.say: "  Room {$r.number}: {$r.title}";
        for $r.furniture -> $f {
            my $s = $f.title;
            if $s ~~ /:i '<ff>' / {
                $fh.say: "      <ff>";
                next;
            }
            ++$nitems; # cumulative number
            my $num = "{$f.number}";
            $fh.say: "      $num {$f.title} [{$f.dims}]";
        }
    }
    $fh.say: "\nTotal number items: $nitems";
    $fh.close;

    # we now have a text file to convert to ps and then pdf
    text-to-pdf $txtfil, @ofils, :$debug;

} # end sub write-list

#| Given a specially formatted text file, read the file and convert
#| the data into a list of Room objects and their Furniture object
#| children.
sub read-data-file($ifil, @rooms, :$debug) is export {
    my $curr-room = 0;
    my $rnum = 0;
    my $lnum = 0;
    my $fnum = 0;

    my $lineno = 0;
    LINE: for $ifil.IO.lines -> $line is copy {
        ++$lineno;
        note "DEBUG line $lineno" if $debug;
        note "DEBUG line: '$line'" if $debug;
        $line = strip-comment $line;
        next LINE if $line !~~ /\S/;
        next LINE if $line ~~ /^ \s* '='+ \s* $/;
        say "DEBUG2 line: '$line'" if $debug;

        if $line ~~ /^ \s* 'room:' \s* (.*) \s* $/ {
            # a new room
            ++$rnum;
            my $title = normalize-string ~$0;
            $curr-room = Room.new: :number($rnum), :$title;
            @rooms.push: $curr-room;

            # reset furniture numbering
            $fnum = 0;

            next LINE;
        }

        if $line ~~ /^ \s* 'title:' \s* (.*) \s* $/ {
            $ftitle = normalize-string ~$0;
            next LINE;
        }
        if $line ~~ /^ \s* 'date:' \s* (.*) $/ {
            $date = normalize-string ~$0;
            next LINE;
        }
        if $line ~~ /^ \s* 'author:' (.*) $/ {
            $author = normalize-string ~$0;
            next LINE;
        }
        if $line ~~ /^ \s* 'address:' (.*) $/ {
            $address = normalize-string ~$0;
            next LINE;
        }
        if $line ~~ /^ \s* 'address2:' (.*) $/ {
            $address2 = normalize-string ~$0;
            next LINE;
        }
        if $line ~~ /^ \s* 'address3:' (.*) $/ {
            $address3 = normalize-string ~$0;
            next LINE;
        }
        if $line ~~ /^ \s* 'scale:' \s* (\S*) \s* $/ {
            $in-per-ft = ~$0;
            next LINE;
        }
        if $line ~~ /^ \s* 'list-file:' \s* (\S*) \s* $/ {
            $ofilL = ~$0;
            next LINE;
        }
        if $line ~~ /^ \s* 'drawings-file:' \s* (\S*) $/ {
            $ofilD = ~$0;
            next LINE;
        }

        # it must be a piece of furniture (or a form feed!)
        if $line ~~ /^:i \s* '<ff>' \s* $/ {
            # a form feed
            my $furn = Furniture.new: :title('<ff>');
            # handle the furniture
            $curr-room.furniture.push: $furn;
            next LINE;
        }

        # it really must be a piece of furniture!
        ++$fnum;

        # its display number will be: {$rnum}.{$fnum}

        # TODO create a grammar for a furniture line
        #
        #   create a furniture object for each line:
        #
        #     furn-parse $line, :furn-actions($furn);
        #
        #   It should replace all this code:
        my $furn = Furniture.new: :scale($in-per-ft), :number("{$rnum}.{$fnum}");
        my ($wid, $len, $dia, $rad);

        #   AND it should replace all this code:
        if $line ~~ /^(.*) [<|w> (\d+) \s+ 'x' \s+ (\d+)] \s* $/ {
            # a rectangular object
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
            # a circular object
            $furn.title    = normalize-string(~$0);
            $furn.diameter = +$1;
            $furn.dims     = "{$furn.diameter}\" diameter";
            $furn.radius   = 0.5 * $furn.diameter;
            my $ww = in2ft $furn.diameter;
            $furn.dims2  = "{$ww}";
        }
        elsif $line ~~ /^(.*) [<|w> (\d+) \s+ 'r'] \s* $/ {
            # a circular object
            $furn.title = normalize-string(~$0);
            $furn.radius = +$1;
            $furn.dims = "{$furn.radius}\" radius";
            my $ww = in2ft 2 * $furn.radius;
            $furn.dims2  = "{$ww}";
        }
        elsif $line ~~ /^(.*) [<|w> (\d+) \s+ 'e' \s+ (\d+)] \s* $/ {
            # an elliptical object
            $furn.title = normalize-string(~$0);
            $wid  = +$1;
            $len  = +$2; # horizontal on the portrait page, it will be
                         # forced to be the longest dimen
            if $len < $wid {
                ($wid, $len) = ($len, $wid);
            }
            $furn.width     = $wid;
            $furn.length    = $len;
            $furn.dims      = "$wid\" x $len\"";
            $furn.diameter  = $wid;
            $furn.diameter2 = $len;

            my $ww = in2ft $wid;
            my $ll = in2ft $len;
            $furn.dims2  = "{$ww}x{$ll}";
        }
        else {
            say "FATAL on line $lnum: '$line'";
            die "  Unknown format";
        }

        #   AND it should replace all this this code:
        # INIT FURNITURE - CRITICAL
        $furn.init; # CRITICAL!!



        #   BUT this code remains:
        # handle the furniture
        $curr-room.furniture.push: $furn;
    }

} # end sub read-data-file

#| Given an empty list of rows, a list of Room objects with their
#| Furniture object children, and the maximum width of the page to be
#| written upon, create a list of Row objects containing Furniture
#| objects to be written as scaled drawings on the output PDF file.
sub make-rows(@rows,   # should be empty
              @rooms,  # all rooms with their furniture
              $maxwid, # distance between left/right page margins
              $space,
              :$debug) {

    @rows   = [];
    my $row = Row.new;
    @rows.push: $row;
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
            my $title = $f.title;
            note "DEBUG: title: |$title|" if $debug;
            next if $title ~~ /:i '<ff>'/;
            $x += $space if $row.furniture.elems;
            if !check-right($f, $x) {
                # need a new row
                $row = Row.new;
                @rows.push: $row;
                reset-row-var;
            }

            # update row data
            $x += $f.w;
            $row.furniture.push: $f;
            $row.max-height = $f.h if $f.h > $row.max-height;
        }
    }
} # end sub make-rows

#| A utility function to convert input inches into a string
#| representation (e.g., <<7'2>>) with the feet followed by a single
#| quote followed by the inches with an implied double quote following
#| it.
sub in2ft($In) {
    # given inches, convert to a
    my $ft = $In div 12;
    my $in = $In mod 12;
    return "{$ft}'{$in}";
}
