unit module Draw2D::Furniture;

use PostScript::File:from<Perl5>;
use Text::Utils :strip-comment, :normalize-string, :wrap-paragraph;

use Draw2D::Furniture::Vars;
use Draw2D::Furniture::Classes;

constant $SPACE  = Q| |; # space for text
constant $BSLASH = '\\'; # backslash for text

sub create-master-file(Project $p) is export {
    note "Tom, fix sub create-master-file";
}

#==============================================================
#| Data from the input data file are used to create scaled
#| drawings of the furniture items.
sub write-drawings(@rooms,
                   @ofils,
                   Project :project(:$p)!,
                   :$debug,
                   :$squeeze,
                  ) is export {

    my $psf = $p.filename: "draw", :suffix("ps");
    my $pdf = $psf;
    $pdf ~~ s/'.ps'$/.pdf/;

    # start a PostScript doc, add options here
    #   enable clipping
    my $ps = PostScript::File.new:
               :paper<Letter>,
               :clipping(1),
               :clip_command<stroke>,
               :landscape(0),
               :file($psf), # the PS output file
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
    # close and output the file
    $ps.output;

    # produce the pdf
    ps-to-pdf @ofils, :$psf, :$pdf, :$debug;

    note "DEBUG: saw $nfurn furniture objects" if 1 or $debug;
} # end sub write-drawings

#| A function to convert an ASCII text file into PostScript.
sub text-to-ps($txtfil, # the ASCII input text file
               $psfile, # the PS output file name
               Project :project(:$p)!,
               :$debug
              ) is export {

    # write the ps file,
    # start a doc, add options here:
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
               :clipping(1), # 1 - clipping, but no border
               :clip_command(''), # or 'stroke' to show the page boundaries
               :landscape(0),
               :file($psfile),
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

    # read the text input file and convert each line into a PostScript
    # command in the output file

    # TODO provide for wrapping long lines somehow
    #   save the indention size
    #   fix max line length based on dist to right margin
    #   wrap the text to proper width (check Text::Utils)
    #   use a PS proc to write

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
    $ps.output; # writes $psfile

} # end sub text-to-ps

#| Given a list of Room objects (with their Furniture object
#| children), create a text file of all items including a unique
#| reference number for each.
#|
#| This sub then calls another sub to convert the text file to
#| PostScript.
sub write-lists(@rooms,
                @ofils,
                Project :project(:$p)!,
                :$debug
               ) is export {

    # TODO here we determine ALL the list-type PS outputs
    #      we want

    write-list-rooms @rooms, :@ofils, :$p, :$debug;
    write-list-ids @rooms, :@ofils, :$p, :$debug;
    write-list-codes @rooms, :@ofils, :$p, :$debug;

} # sub write-lists

#| Given a specially formatted text file, read the file and convert
#| the data into a list of Room objects and their Furniture object
#| children.
# TODO allow either square brackets or curly braces or <> or ""
my token codes { <[A..Za..z\h]>+  }
my token key { \w+ ['-'? \w+ ]? ':' }
my token sign { <[+-]> }
my token decimal  { \d+ }
my regex number { :r
    <sign>?
    [
      | <decimal>
      | <decimal> '.' <decimal>
    ]
}

sub read-data-file($ifil,
                   Project :project(:$p)!,
                   :$ids!, # if true, throws on no id on input for a child
                   :$list-codes,
                   :$debug
                   --> List
                  ) is export {
    my @headers;
    my @rooms;

    my $curr-room = 0;
    my $rnum = 0;
    my $fnum = 0;

    my $i = 0;
    my @lines;

    # fold (concatenate) lines with backslashes before processing
    my @flines;

    for $ifil.IO.lines -> $line is copy {
        ++$i;
        # lines with an ending slash are combined with following lines
        # until the first unslashed one
        # note embedded slashes are IGNORED in the combining
        note "== line $i" if $debug;
        $line = strip-comment $line;
        $line = ' ' if not $line; # IMPORTANT FOR THE REST OF THIS LOOP

        my $has-ending-slash = 0;
        if $line ~~ /$BSLASH \h* $/ {
            ++$has-ending-slash;
            note "backslash on end of line '$line'" if $debug;
            $line ~~ s/$BSLASH \h* $//;
            note "  after removal: '$line'" if $debug;
            # stash in @flines
            @flines.push: $line;
            next ;
        }

        # combine the line with any parent lines
        if @flines.elems {
            my $p = join $SPACE, @flines;
            $line = $p ~ $SPACE ~ $line;
            @flines = [];
        }

        @lines.push($line) if $line;
    }

    my $lineno = 0;
    LINE: for @lines -> $line is copy {
        ++$lineno;
        note "DEBUG line $lineno" if $debug;
        note "DEBUG line: '$line'" if $debug;
        next LINE if $line !~~ /\S/;
        next LINE if $line ~~ /^ \s* '='+ \s* $/;
        say "DEBUG2 line: '$line'" if $debug;

        if $line ~~ /^ \h* room ':' \h* (.*) \h* $/ {
            # a new room
            ++$rnum;
            my $title = normalize-string ~$0;
            $curr-room = Room.new: :number($rnum), :$title;
            @rooms.push: $curr-room;

            # reset furniture numbering
            $fnum = 0;

            next LINE;
        }

        #=== BEGIN HEADER INFO COLLECTION ===#
        #    ERROR IF ALREADY READING ROOM INFO
        # these three attributes were set at creation, warn if changed
        if $line ~~ /^ \s* title ':' \s* (.*) \s* $/ {
            my $txt = normalize-string ~$0;
            note "DEBUG: txt: '$txt'" if $debug;
            die "FATAL: header info '$txt' not allowed after room info has begun" if $curr-room;
            if $p.title and $p.title ne $txt {
                note qq:to/HERE/
                WARNING: title $txt has changed since project was created
                HERE
            }
            $p.title = $txt;
            next LINE;
        }
        if $line ~~ /^ \s* date ':' \s* (.*) $/ {
            my $txt = normalize-string ~$0;
            die "FATAL: header info '$txt' not allowed after room info has begun" if $curr-room;
            if $p.date and $p.date ne $txt {
                note qq:to/HERE/
                WARNING: date $txt has changed since project was created
                HERE
            }
            $p.date = $txt;
            next LINE;
        }
        if $line ~~ /^ \s* basename ':' \s* (.*) $/ {
            die "FATAL: header info '{~$0}' not allowed after room info has begun" if $curr-room;
            my $txt = normalize-string ~$0;
            if (not $p.basename.defined) or ($p.basename ne $txt) {
                note qq:to/HERE/
                WARNING: basename $txt has changed since project was created
                HERE
            }
            $p.basename = $txt;
            next LINE;
        }

        # handle multi-line items
        #   author
        #   address
        #   phone
        #   email
        #   mobile
        #   note
        #   code
        if $line ~~ /^ \h*
            (
              || author
              || address\d*
              || phone
              || mobile
              || email
              || note
              || code
            )
            ':'
            (.*)
            $/ {

            die "FATAL: header info '{~$0}' not allowed after room info has begun" if $curr-room;
            my $key = ~$0;
            my $txt = normalize-string ~$1;

            # special handling for codes
            note "DEBUG: handling input code '$key' with text '$txt'" if $debug;
            if $key eq "code" {
                # the code key is the first word of the value
                my @w = $txt.words;
                my $c = @w.shift.lc;
                my $title = @w.join: " ";
                note "DEBUG: handling Project code '$c' with text '$title'" if $debug;
                $p.set-code($c, :$title);
            }
            else {
                $p.push($key, $txt);
            }
            next LINE;
        }

        if $line ~~ /^ \s* scale ':' \s* (\S*) \s* $/ {
            die "FATAL: header info '{~$0}' not allowed after room info has begun" if $curr-room;
            #$p.in-per-ft = +$0;
            $p.scale = +$0;
            next LINE;
        }
        if $line ~~ /^ \s* 'list-file:' \s* (\S*) \s* $/ {
            die "FATAL: header info '{~$0}' not allowed after room info has begun" if $curr-room;
            $p.list-name = ~$0;
            next LINE;
        }
        if $line ~~ /^ \s* 'drawings-file:' \s* (\S*) $/ {
            die "FATAL: header info '{~$0}' not allowed after room info has begun" if $curr-room;
            $p.draw-name = ~$0;
            next LINE;
        }
        #=== END OF HEADER INFO LINES ===#

        if 0 and $debug {
            note $p.codes2str: :keys;
            note $p.codes2str: :list;
            die "DEBUG: debug early exit";
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


        #== FURNITURE LINES ========================
        # its display number will be: {$rnum}.{$fnum}

        # TODO create a grammar for a furniture line
        #
        #   create a furniture object for each line:
        #
        #     furn-parse $line, :furn-actions($furn);
        #
        #   It should replace all this code:
        my $furn = Furniture.new: :scale($p.scale), # in-per-ft),
                      :number("{$rnum}.{$fnum}");
        my ($wid, $len, $dia, $rad, $hgt);

        #   AND it should replace all this code:

        # ELLIPSE W/ MAJOR x MINOR AXES
        if $line ~~ / # first collect dimensional and object type at the end of the string
                         [
                            || \h+ (<number>) \h+ 'e' \h+ (<number>) \h+ 'x' \h+ (<number>)
                            || \h+ (<number>) \h+ 'e' \h+ (<number>)
                         ]
                         \h*
                       $/ {
            # 1. an elliptical object
            my $s = "elliptical object";
            note "DEBUG: line $lineno item '$s'" if $debug;

            # save the starting position of the match to save the leading part of the
            # line for later parsing
            my $idx = $/.from;
            my $leading = $line.substr(0, $idx);

            # collect the data in the current match

            #$furn.title = normalize-string(~$0);
            $wid  = +$0;
            $len  = +$1; # horizontal on the portrait page, it will be
                         # forced to be the longest dimen
            $hgt  = $2.defined ?? +$2 !! '';
            $furn.height   = $hgt;

            if $len < $wid {
                ($wid, $len) = ($len, $wid);
            }
            $furn.width     = $wid;
            $furn.length    = $len;
            $furn.dims      = "$wid\" x $len\"";
            $furn.dims   = $hgt ?? "$wid\" x $len\" x $hgt\""
                                !! "$wid\" x $len\"";

            $furn.diameter  = $wid;
            $furn.diameter2 = $len;

            my $ww = in2ft $wid;
            my $ll = in2ft $len;
            #$furn.dims2  = "{$ww}x{$ll}";

            # now parse the leading part of the line
            my ($id, $codes, $desc) = parse-leading $leading, $rnum, $fnum, :$ids, :$debug;
            note "  captures => |$id| |$codes| |$desc| |$wid| |$len| |h: $hgt|" if $debug;

            # handle the id
            if $id and not $p.id-exists($id) {
                # it's unique
                $p.set-id: $id;
                $furn.set-id: $id;
            }
            else { die "FATAL: furniture object with non-unique id: '$id'"; }

            # handle the codes
            if $codes {
                note "DEBUG: handling codes:  |$id| |$codes| |$desc| |$wid| |$len| |h: $hgt|" if $debug;
            for $codes.words -> $c  {
                note "checking furn code '$c' for validity|" if 1 or $debug;
                if $p.code-exists($c) {
                    # it's valid
                    $furn.set-code: $c;
                }
                else { die "FATAL: furniture object id '$id' with non-valid code: '$c'"; }
            }
            }

            $furn.desc  = $desc;
        }
        # CIRCLE W/ DIAMETER
        elsif $line ~~ / # first collect dimensional and object type at the end of the string
                         [
                            || \h+ (<number>) \h+ 'd' \h+ 'x' \h+ (<number>)
                            || \h+ (<number>) \h+ 'd'
                         ]
                         \h*
                       $/ {
            # 2. a circular object with diam
            my $s = "circular object with diam";
            note "DEBUG: line $lineno item '$s'" if $debug;

            # save the starting position of the match to save the leading part of the
            # line for later parsing
            my $idx = $/.from;
            my $leading = $line.substr(0, $idx);

            # collect the data in the current match
            #$furn.title    = normalize-string(~$0);
            $furn.diameter = +$0;
            $hgt  = $1.defined ?? +$1 !! '';
            $furn.height   = $hgt;


            $furn.dims     = $hgt ?? "{$furn.diameter}\" diameter x {$furn.height}\" height"
                                  !! "{$furn.diameter}\" diameter";


            $furn.radius   = 0.5 * $furn.diameter;
            my $ww = in2ft $furn.diameter;
            #$furn.dims2  = "{$ww}";

            # now parse the leading part of the line
            my ($id, $codes, $desc) = parse-leading $leading, $rnum, $fnum, :$ids, :$debug;
            note "  captures => |$id| |$codes| |$desc| |{$furn.diameter}| |h: $hgt|" if $debug;

            # handle the id
            if $id and not $p.id-exists($id) {
                # it's unique
                $p.set-id: $id;
                $furn.set-id: $id;
            }
            else { die "FATAL: furniture object with non-unique id: $id"; }

            # handle the codes
            if $codes {
                note "DEBUG: handling codes:  |$id| |$codes| |$desc| |$wid| |$len| |h: $hgt|" if $debug;
            for $codes.words -> $c  {
                if $p.code-exists($c) {
                    # it's valid
                    $furn.set-code: $c;
                }
                else { die "FATAL: furniture object id '$id' with non-valid code: '$c'"; }
            }
            }

            $furn.desc  = $desc;
        }
        # CIRCLE W/ RADIUS
        elsif $line ~~ / # first collect dimensional and object type at the end of the string
                         [
                            || \h+ (<number>) \h+ 'r' \h+ 'x' \h+ (<number>)
                            || \h+ (<number>) \h+ 'r'
                         ]
                         \h*
                       $/ {
            # 3. a circular object with radius
            my $s = "circular object with radius";
            note "DEBUG: line $lineno item '$s'" if $debug;

            # save the starting position of the match to save the leading part of the
            # line for later parsing
            my $idx = $/.from;
            my $leading = $line.substr(0, $idx);

            # collect the data in the current match

            #$furn.title = normalize-string(~$0);
            $furn.radius = +$0;
            $hgt  = $1.defined ?? +$1 !! '';
            $furn.height   = $hgt;

            $furn.dims     = $hgt ?? "{$furn.radius}\" radius x {$furn.height}\" height"
                                  !! "{$furn.radius}\" radius";
            my $ww = in2ft 2 * $furn.radius;
            #$furn.dims2  = "{$ww}";

            # now parse the leading part of the line
            my ($id, $codes, $desc) = parse-leading $leading, $rnum, $fnum, :$ids, :$debug;
            note "  captures => |$id| |$codes| |$desc| |{$furn.radius}| |h: $hgt|" if $debug;

            # handle the id
            if $id and not $p.id-exists($id) {
                # it's unique
                $p.set-id: $id;
                $furn.set-id: $id;
            }
            else { die "FATAL: furniture object with non-unique id: $id"; }

            # handle the codes
            if $codes {
                note "DEBUG: handling codes:  |$id| |$codes| |$desc| " if $debug;
            for $codes.words -> $c  {
                note "DEBUG: handling code for furn  '$c'" if $debug;
                if $p.code-exists($c) {
                    # it's valid
                    note "DEBUG: code for furn: $c is known by Project" if $debug;
                    $furn.set-code: $c;
                }
                else { die "FATAL: furniture object id '$id' with non-valid code: '$c'"; }
            }
            }

            $furn.desc  = $desc;
        }
        # RECTANGLE
        elsif $line ~~ / # first collect dimensional and object type at the end of the string
                      [
                         || \h+ (<number>) \h+ 'x' \h+ (<number>) \h+ 'x' \h+ (<number>)
                         || \h+ (<number>) \h+ 'x' \h+ (<number>)
                      ]
                      \h*
                    $/ {
            # 4. a rectangular object
            my $s = "rectangular object";
            note "DEBUG: line $lineno item '$s'" if $debug;

            # save the starting position of the match to save the leading part of the
            # line for later parsing
            my $idx = $/.from;
            my $leading = $line.substr(0, $idx);

            # collect the data in the current match
            $wid  = +$0;
            $len  = +$1; # horizontal on the portrait page, it will be
                         # forced to be the longest dimen
            $hgt  = $2.defined ?? +$2 !! '';

            if $len < $wid {
                ($wid, $len) = ($len, $wid);
            }

            $furn.width  = $wid;
            $furn.length = $len;
            $furn.height = $hgt;
            $furn.dims   = $hgt ?? "$wid\" x $len\" x $hgt\""
                                !! "$wid\" x $len\"";
            my $ww = in2ft $wid;
            my $ll = in2ft $len;
            #$furn.dims2  = "{$ww}x{$ll}";

            # now parse the leading part of the line
            my ($id, $codes, $desc) = parse-leading $leading, $rnum, $fnum, :$ids, :$debug;
            note "  captures => |$id| |$codes| |$desc| |$wid| |$len| |h: $hgt|" if $debug;

            # handle the id
            if $id and not $p.id-exists($id) {
                # it's unique
                $p.set-id: $id;
                $furn.set-id: $id;
            }
            else { die "FATAL: furniture object with non-unique id: $id"; }

            # handle the codes
            if $codes {
                note "DEBUG: handling codes:  |$id| |$codes| |$desc| |$wid| |$len| |h: $hgt|" if $debug;
            for $codes.words -> $c  {
                if $p.code-exists($c) {
                    # it's valid
                    $furn.set-code: $c;
                }
                else { die "FATAL: furniture object id '$id' with non-valid code: '$c'"; }
            }
            }

            $furn.desc  = $desc;
        }
        else {
            # we should still handle the first part
            note "WARNING: line $lineno, no dimens found: '$line'";
            # assume it's an undefined rectangle
            my $s = "rectangular object";
            note "DEBUG: line $lineno item '$s'" if $debug;

            $furn.width  = 0;
            $furn.length = 0;
            $furn.height = 0;
            $furn.dims   = "?";
            #$furn.dims2  = "?";

            # now parse the leading part of the line
            my $leading = $line;
            my ($id, $codes, $desc) = parse-leading $leading, $rnum, $fnum, :$ids, :$debug;
            note "  captures => |$id| |$codes| |$desc| |$wid| |$len| |h: $hgt|" if $debug;

            # handle the id
            if $id and not $p.id-exists($id) {
                # it's unique
                $p.set-id: $id;
                $furn.set-id: $id;
            }
            else { die "FATAL: furniture object with non-unique id: $id"; }

            # handle the codes
            if $codes {
                note "DEBUG: handling codes:  |$id| |$codes| |$desc| |$wid| |$len| |h: $hgt|" if $debug;
            for $codes.words -> $c  {
                if $p.code-exists($c) {
                    # it's valid
                    $furn.set-code: $c;
                }
                else { die "FATAL: furniture object id '$id' with non-valid code: '$c'"; }
            }
            }

            $furn.desc  = $desc;
        }

        #   AND it should replace all this this code:
        # INIT FURNITURE - CRITICAL
        $furn.init; # CRITICAL!!


        #   BUT this code remains:
        # handle the furniture
        $curr-room.furniture.push: $furn;
    }

    @rooms

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

    # TODO wrap long lines with wrap-paragraph
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
    # given inches, convert to a string repr
    my ($ft, $in);
    if $In ~~ Int {
        $ft = $In div 12;
        $in = $In mod 12;
    }
    elsif $In ~~ Num|Rat {
        $ft = $In / 12;
        $in = $In % 12;
    }

    return "{$ft}'{$in}";
}

#| A utility sub to convert a valid PostScript file to
#| pdf using the system progeam 'ps2pdf'.
sub ps-to-pdf(@ofils,
              :psfile(:$psf)!,
              :pdfile(:$pdf) is copy,
              :$debug
             ) {
    if not $pdf {
        $pdf = $psf;
        $pdf ~~ s/'.ps'$/.pdf/;
    }
    
    # produce the pdf
    # some additional error checking
    if $debug {
        note "DEBUG file names: psf '$psf' pdf '$pdf'";
        note "DEBUG early exit"; exit;
    }

    die "FATAL: Input file '$psf' not found" if !$psf.IO.f;
    my $cmd  = "ps2pdf";
    my $args = "$psf $pdf";
    run $cmd, $args.words;
    die "FATAL: Output file $pdf not found" if !$pdf.IO.f;
    @ofils.push: $pdf;
    $debug ??  @ofils.push($psf) !! unlink($psf);
}

sub parse-leading($s, $rnum, $fnum, :$ids!, :$debug --> List) {
    # now parse the leading part of the line
    #   my ($id, $codes, $desc) = parse-leading $leading, :$debug;
    #
    # example leading input lines:
    #   <number>? <codes>? name rest of description
    my $id    = "";
    my $codes = "";
    my $desc  = $s;

    my $num = "$rnum.$fnum";
    my $no-id = 0;

    my @w = $s.words;
    $id = @w.shift;
    $desc = join $SPACE, @w;
    if $ids and $id !~~ /<number>/ {
        die "FATAL: This furniture line (number $num) has no leading ID number";
    }
    elsif $id !~~ /<number>/ {
        ++$no-id;
    }

    if $desc ~~ /^
                \h*
                [
                  || '[' (<codes>) ']' \h+ (\N*)
                  || (\N*)
                ]
                \h*
                $/ {
        if $0.defined and $1.defined {
            $codes = ~$0;
            $desc  = ~$1;

        }
        elsif $0.defined {
            $desc  = ~$0;
        }
        else {
            note "WARNING: This furniture line (number $num) has unknown format";
        }
    }
    else {
        note "WARNING: no parse for line: |$s|";
    }

    if $no-id {
        # add first word back
        $desc = $id ~ " $desc";
        note "WARNING: Furniture line number $num has no leading ID number.";
    }

    note "DEBUG: parsing leading: id/codes |$id| |$codes|" if $debug;

    $codes = normalize-string $codes;

    die "FATAL: code has [] '$codes'" if $codes ~~ /'['|']'/;

    $id, $codes, $desc
} # sub parse-leading

sub write-list-headers($fh, 
                       :project(:$p), 
                       :$debug
                      ) is export {

    # TODO handle better output file info

    #== headers for ALL files
    # title, etc.
    if $p.title { $fh.say: "Title: {$p.title}"; }
    if $p.author { $fh.say: "Author: {$p.author}"; }
    if $p.date { $fh.say: "Date: {$p.date}"; }
    # multiply-valued keys
    if $p.address { $fh.say("Address: $_") for $p.address; }
    if $p.phone { $fh.say("Phone: $_") for $p.phone; }
    # show codes with title
    my $cs = $p.codes2str(:list, :sepchar("\t"));
    if $cs {
        $fh.print: qq:to/HERE/;
        Code \t Title
        ==== \t =====;
        $cs
        HERE
    }
    #== end headers for ALL files
} # sub write-list-headers

sub write-list-rooms(@rooms, :@ofils, :project(:$p), :$debug) {
    # writes a list in room, furniture order
    # the master list

    my $nitems = 0;
    # create the raw ASCII text file
    my $txtfil = $p.filename: "text", :list-subtype("");
    my $fh = open $txtfil, :w;

    write-list-headers $fh, :$p, :$debug;

    #===========
    # this is the standard list output by room, furniture
    # write-list-rooms
    for @rooms -> $r {
        $fh.say: "  Room {$r.number}: {$r.title}";
        for $r.furniture -> $f {
            my $t = $f.title;
            if $t ~~ /:i '<ff>' / {
                $fh.say: "      <ff>";
                next;
            }
            ++$nitems; # cumulative number

            my $num   = "{$f.number}";
            my $id    = $f.id;
            my $codes = $f.codes2str: :keys; # output "a bb .."
            $fh.say: "      $num [$id] [$codes] {$f.desc} [{$f.dims}]";
        }
    }
    $fh.say: "\nTotal number items: $nitems";
    $fh.close;
    @ofils.push: $txtfil;

    # we now have a text file to convert to ps
    my $psfile = $p.filename: "list", :list-subtype(""), :suffix("ps");
    text-to-ps $txtfil, $psfile, :$p, :$debug;
    ps-to-pdf @ofils, :$psfile;

} # sub write-list-rooms

sub write-list-ids(@rooms, :@ofils, :project(:$p), :$debug) {
    # writes a list in id order
    # for all IDs

    my $nitems = 0;
    # create the raw ASCII text file
    my $txtfil = $p.filename: "text", :list-subtype("id");
    my $fh = open $txtfil, :w;

    write-list-headers $fh, :$p, :$debug;

    $fh.close;
    @ofils.push: $txtfil;

    #write-list-headers $fh, :$p, :$debug;

} # sub write-list-ids

sub write-list-codes(@rooms, :@ofils, :project(:$p), :$debug) {
    # writes a separate list for each code
    # in room, furniture order

    my $nitems = 0;
    # create the raw ASCII text file
    my $txtfil = $p.filename: "text", :list-subtype("code");
    my $fh = open $txtfil, :w;

    write-list-headers $fh, :$p, :$debug;

    $fh.close;
    @ofils.push: $txtfil;

    #write-list-headers $fh, :$p, :$debug;

} # sub write-list-codes
