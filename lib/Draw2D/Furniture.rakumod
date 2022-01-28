unit module Draw2D::Furniture;

use PostScript::File:from<Perl5>;
use Text::Utils :strip-comment, :normalize-string, :wrap-paragraph, :count-substrs;

use Draw2D::Furniture::Classes;
use Draw2D::Furniture::Procset-Misc;
#use Draw2D::Furniture::Procset-Fonts;

constant $SPACE  = Q| |; # space for text
constant $BSLASH = '\\'; # backslash for text

sub create-master-file(Project $p) is export {
    note "Tom, fix sub create-master-file";
}

#==============================================================
#| Data from a separate room-dimensions input data file are used
#| to create scaled drawings of the rooms.
sub read-room-data($ifil, :$scale!, :$debug --> List) {
    my RoomDrawing @rooms;
    for $ifil.IO.lines -> $line is copy {
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
        my $r = RoomDrawing.new: :title(@w[0]), :width(@w[1]), :length(@w[2]), :$scale;
        my $ww = in2ft $r.width;
        my $ll = in2ft $r.length;
        $r.dims2  = "{$ww}x{$ll}";

        @rooms.push: $r;
    }
    if $debug {
        note "DEBUG: early exit";exit;
    }
    @rooms
} # sub read-room-data

#==============================================================
#| Data from a separate room-dimensions input data file are used
#| to create scaled drawings of the rooms.
sub draw-rooms($ifil,
               $ofil,
               :$scale!,
               :@ofils!,
               :$debug = 0,
               :$squeeze,
              ) is export {

    # vars to handle:
    my $site = "site TBA";

    my @rooms = read-room-data $ifil, :$scale;

    # create the output file names
    my $pdf = $ofil; # $p.filename: "draw", :$scale, :suffix("ps");

    my $psf = $pdf;
    $psf ~~ s/'.pdf'$/.ps/;

    # start a PostScript doc, add options here
    #   enable clipping
    #   portrait mode
    my $ps = PostScript::File.new:
    :paper<Letter>,
    :clipping(1),
    :clip_command<stroke>,
    :landscape(0),
    :file($psf), # the PS output file
    :file_ext("");
    die "FATAL: no PS object" if not $ps;

    # for debugging count room items
    my $nrooms = 0;

    if $debug == 1 {
        my ($llx, $lly, $urx, $ury) = $ps.get_bounding_box;
        note "DEBUG: drawing page bbox: $llx, $lly    $urx, $ury";
    }

    # setup any prolog such as my
    # procs: box, circle, puttext, clip, fonts
    note "DEBUG: adding procset 'MyMisc'" if $debug;
    $ps.add_procset: "MyMisc", $procset-misc;

    =begin comment
    # TODO add new fonts in their own "procset"
    note "DEBUG: adding procset 'MyFonts'" if $debug;
    $ps.add_procset: "MyFonts", $procset-fonts;
    =end comment

    # page constants
    # page margins
    my $top-marg   =  0.4; # inches
    # use top margin for title, page, scale info

    my $marg       =  0.4; # inches
    my $space      =  0.2 * 72; # vert and horiz space between figures
    my $xleft      =  $marg * 72;
    my $xright     =  (8.5 - $marg) * 72;
    my $xwidth     =  $xright - $xleft;
    my $xcenter    =  $xleft + 0.5 * $xwidth;
    my $ytop       =  2 + (11 - $marg - $top-marg * 2) * 72;
    my $ybottom    =  $marg * 72;

    # page variables
    my (Real $x, Real $y, UInt $npages) = 0, 0, 0;

    my @rows;

    note "DEBUG: entering sub make-room-rows..." if $debug;
    make-room-rows @rows, @rooms, $xright - $xleft, $space, :$scale;
    my $nrows = @rows.elems;
    die "FATAL: no rows collected!" if !$nrows;
    note "DEBUG: num room rows: {$nrows}" if 0 or $debug;

    # step through all the rooms
    # keep track of:
    #   last baseline
    reset-page-vars $x, $y, :$npages, :$xleft, :$ytop;

    # TODO fix border around top page title block
    #      note: use clipping to keep border stroke within the desired area
    #      e.g., gs np x y mt ...define rectangle... clip st gr
    # TODO add 3 point whitespace for drawing area inside its thin black border
    # TODO add new monospaced fonts to ps procs

    # page header to be used for each page
    my $Scale = sprintf "%0.4f", $scale; # for display only
    $Scale ~~ s:g/0$//;
    my $yhdrbaseline = $ytop + 35;
    my $yhdrbot      = $yhdrbaseline - 15;
    my $pheader = qq:to/HERE/;
    gsave
    /Times-Bold 14 selectfont
    {$xleft+10} {$ytop+35} mt (Site: $site) 9 puttext % left-justified on the baseline
    /Times-Roman 12 selectfont
    $xcenter $yhdrbaseline mt (Scale: $Scale in/ft) 9 puttext % left-justified on the baseline
    % enclose the title box:
    % draw a bottom title border
    $xleft $yhdrbot mt $xright $yhdrbot lineto st
    grestore
    HERE

    $ps.add_to_page: $npages, $pheader;

    my $i = 0;
    for @rows -> Row $row {
        reset-row-var $x, :$xleft;

        ++$i;
        if $debug == 1 {
            note "DEBUG: row $i max-height: {$row.max-height}";
            note "              room items: {$row.rooms.elems}";
            note " start x/y: $x $y";
        }
        if !check-bottom($row, $y, $ybottom) {
            # need a new page
            reset-page-vars $x, $y, :$npages, :$xleft, :$ytop;
            $ps.newpage;
            # then the page header
            $ps.add_to_page: $npages, $pheader;
        }
        for $row.rooms -> RoomDrawing $room {
            ++$nrooms;
            # draw it at the current ulx, uly
            $room.ps-draw: $ps, :ulx($x), :uly($y);
            # increment x
            $x += $room.w + $space
        }

        $y -= $row.max-height + $space;
    }

    note "DEBUG: num pages: $npages" if $debug == 1;
    # go back and add page numbers:
    #   Page x of n
    for 1..$npages -> $page {
        my $s = "Page $page of $npages";
        $ps.add_to_page: $page, qq:to/HERE/;
        gsave
        /Times-Roman 12 selectfont $xright 10 sub $ytop 35 add mt ($s) 11 puttext % right-justified
        grestore
        HERE
    }

    # close and output the file
    $ps.output;

    # produce the pdf
    ps-to-pdf @ofils, :$psf, :$pdf, :$debug;

    note "DEBUG: saw $nrooms room objects" if 0 or $debug;
    #=end comment

} # sub draw-rooms

#==============================================================
#| Data from the input data file are used to create scaled
#| drawings of the furniture items.
sub write-drawings(@rooms,
                   @ofils,
                   Project :project(:$p)!,
                   :$code,   # for header info
                   :$debug = 0,
                   :$squeeze,
                  ) is export {

    # create one furniture drawings set for each scale and site
    # begin scale loop
    for $p.scales.kv -> $scale, $site {
        note "DEBUG: ready to draw, scale: $scale; site $site";

        # note the default scale is used if not specifically entered (0.25)
        my $psf = $p.filename: "draw", :$scale, :suffix("ps");

        my $pdf = $psf;
        $pdf ~~ s/'.ps'$/.pdf/;

        # start a PostScript doc, add options here
        #   enable clipping
        #   portrait mode
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

        if $debug == 1 {
            my ($llx, $lly, $urx, $ury) = $ps.get_bounding_box;
            note "DEBUG: drawing page bbox: $llx, $lly    $urx, $ury";
        }

        # setup any prolog such as my
        # procs: box, circle, puttext, clip, fonts
        note "DEBUG: adding procset 'MyMisc'" if $debug;
        $ps.add_procset: "MyMisc", $procset-misc;

        =begin comment
        # TODO add new fonts in their own "procset"
        note "DEBUG: adding procset 'MyFonts'" if $debug;
        $ps.add_procset: "MyFonts", $procset-fonts;
        =end comment

        # page constants
        # page margins
        my $top-marg   =  0.4; # inches
        # use top marg for title, page, scale info

        my $marg       =  0.4; # inches
        my $space      =  0.2 * 72; # vert and horiz space between figures
        my $xleft      =  $marg * 72;
        my $xright     =  (8.5 - $marg) * 72;
        my $xwidth     =  $xright - $xleft;
        my $xcenter    =  $xleft + 0.5 * $xwidth;
        my $ytop       =  2 + (11 - $marg - $top-marg * 2) * 72;
        my $ybottom    =  $marg * 72;

        # page variables
        my (Real $x, Real $y, UInt $npages) = 0, 0, 0;

        # collect furniture by page rows
        my @rows;
        note "DEBUG: entering sub make-rows..." if $debug;
        make-rows @rows, @rooms, $xright - $xleft, $space, :$scale;
        my $nrows = @rows.elems;
        die "FATAL: no rows collected!" if !$nrows;
        note "DEBUG: num furniture rows: {$nrows}" if 0 or $debug;

        # step through all the furniture and number each as in the index
        # keep track of:
        #   last baseline
        reset-page-vars $x, $y, :$npages, :$xleft, :$ytop;

        # TODO fix border around top page title block
        #      note: use clipping to keep border stroke within the desired area
        #      e.g., gs np x y mt ...define rectangle... clip st gr
        # TODO add 3 point whitespace for drawing area inside its thin black border
        # TODO add new monospaced fonts to ps procs

        # page header to be used for each page
        my $Scale = sprintf "%0.4f", $scale; # for display only
        $Scale ~~ s:g/0$//;
        my $yhdrbaseline = $ytop + 35;
        my $yhdrbot      = $yhdrbaseline - 15;
        my $pheader = qq:to/HERE/;
        gsave
        /Times-Bold 14 selectfont
        {$xleft+10} {$ytop+35} mt (Site: $site) 9 puttext % left-justified on the baseline
        /Times-Roman 12 selectfont
        $xcenter $yhdrbaseline mt (Scale: $Scale in/ft) 9 puttext % left-justified on the baseline
        % enclose the title box:
        % draw a bottom title border
        $xleft $yhdrbot mt $xright $yhdrbot lineto st
        grestore
        HERE

        $ps.add_to_page: $npages, $pheader;
        my $i = 0;
        for @rows -> Row $row {
            reset-row-var $x, :$xleft;

            ++$i;
            if $debug == 1 {
                note "DEBUG: row $i max-height: {$row.max-height}";
                note "              furn items: {$row.furniture.elems}";
                note " start x/y: $x $y";
            }
            if !check-bottom($row, $y, $ybottom) {
                # need a new page
                reset-page-vars $x, $y, :$npages, :$xleft, :$ytop;
                $ps.newpage;
                # then the page header
                $ps.add_to_page: $npages, $pheader;
            }
            for $row.furniture -> Furniture $f {
                ++$nfurn;
                # draw it at the current ulx, uly
                $f.ps-draw: $ps, :ulx($x), :uly($y);
                # increment x
                $x += $f.w + $space
            }

            $y -= $row.max-height + $space;
        }

        note "DEBUG: num pages: $npages" if $debug == 1;
        # go back and add page numbers:
        #   Page x of n
        for 1..$npages -> $page {
            my $s = "Page $page of $npages";
            $ps.add_to_page: $page, qq:to/HERE/;
            gsave
            /Times-Roman 12 selectfont $xright 10 sub $ytop 35 add mt ($s) 11 puttext % right-justified
            grestore
            HERE
        }

        # close and output the file
        $ps.output;

        # produce the pdf
        ps-to-pdf @ofils, :$psf, :$pdf, :$debug;

        note "DEBUG: saw $nfurn furniture objects" if 0 or $debug;
    } # end of scales loop

} # end sub write-drawings

#| A function to convert an ASCII text file into PostScript.
sub text-to-ps($txtfil, # the ASCII input text file
               $psfile, # the PS output file name
               Project :project(:$p)!,
               :$font = 'Courier-Bold', # default
               :$debug = 0,
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

    if $debug == 1 {
        my ($llx, $lly, $urx, $ury) = $ps.get_bounding_box;
        note "DEBUG listing page bbox: $llx, $lly    $urx, $ury";
    }

    # setup any prolog such as my
    # procs: box, circle, puttext, clip, fonts
    $ps.add_procset: "MyMisc", $procset-misc;
    # TODO add other fonts as a procset in Fonts.rakumod

    # page constants
    # page margins
    my $marg    =  1.0; # inches
    my $xleft   =  $marg * 72;
    my $xright  =  (8.5 - 0.5 * $marg) * 72;
    my $xcenter =  $xleft + ($xright - $xleft) * 0.5;
    my $ytop    =  (11 - $marg) * 72;
    my $ybottom =  $marg * 72 + 20; # allow 25 points for a page number
    my $max-line-len = (8.5 - 1.5) * 72;
    # font variables
    #my $font   = 'Times-Roman';
    #my $font    = 'Courier-Bold';
    my $fsize   = 9;
    my $lspace  = $fsize * 1.2; # baseline to baseline distance

    =begin comment
    # from Adobe's AFM doc
    # monowidth chars only!
    $string-width = (($afm-width * $nchars) * $fsize) / 1000;
    $string-width * 1000 = ($AFM-width * $nchars) * $fsize;
    ($string-width * 1000) / $fsize = $AFM-width * $nchars;
    $nchars = (($string-width * 1000) / $fsize)/$AFM-width;
    =end comment

    my $string-width = $max-line-len;
    my $afm-width = 600; # Courier family ONLY
    my $nchars = (($string-width * 1000) / $fsize) / $afm-width;

    my $ytopbaseline = $ytop - $lspace;
    my $max-line-chars = $nchars.Int;

    $ps.add_to_page: "/$font $fsize selectfont\n";

    # page variables
    my (Real $x, Real $y, UInt $npages) = 0, 0, 0;

    # step through all rows of text
    # keep track of:
    #   last baseline
    reset-page-vars $x, $y, :$npages, :$xleft, :ytop($ytopbaseline);
    $ps.add_to_page: "/$font $fsize selectfont\n";

    # read the text input file and convert each line into a PostScript
    # command in the output file

    # provide for wrapping long lines
    #   save the indention size
    #   fix max line length based on dist to right margin
    #   wrap the text to proper width (check Text::Utils)
    #   use a PS proc to write?

    LINE: for $txtfil.IO.lines -> $tline is copy {
        my $ff = $tline ~~ /:i '<ff>' / ?? 1 !! 0;
        note "DEBUG: ff = $ff" if $debug == 1;

        # some analysis here:
        #   if $tline contains '<ff>' make a new page
        # otherwise, we need to translate leading space
        #   chars to an x indent space
        reset-row-var $x, :$xleft;
        my $res = check-bottom($y, $lspace, $ybottom);
        if $ff || !$res {
            # need a new page
            reset-page-vars $x, $y, :$npages, :$xleft, :ytop($ytopbaseline);
            $ps.newpage;
            $ps.add_to_page: "/$font $fsize selectfont\n";
        }
        next LINE if $ff;

        # wrapped lines, may bejust one if no wrapping
        my @wlines;

        my $line-len = $tline.chars * $fsize;
        if $line-len > $max-line-len {
            # wrap the lines with the initial spaces as indent
            my $para-indent = 0;
            if $tline ~~ /^ (\s+) (.*) $/ {
                my $spaces = ~$0;
                $para-indent = $spaces.chars;
            }
            # do the wrap
            # this fails in PostScript with unbalanced quote delimiters
            # fix by escaping after the fold by traversing the folded lines
            my @flines = wrap-paragraph $tline,
            :max-line-length($max-line-chars),
            :$para-indent,
            :line-indent(4);
            for @flines -> $fline is copy {
                $fline ~~ s:g/'('/\\(/;
                $fline ~~ s:g/')'/\\)/;
                @wlines.push: $fline;
            }

            if $debug and $debug == 4 {
                note "DEBUG: wrapped para: ======";
                .say for @wlines;
                note "DEBUG: end wrapped para: ======";
                #note "DEBUG: early exit"; exit
            }
        }
        else {
            # what about unbalanced parens in shorter lines?
            # this also fails in PostScript with unbalanced quote delimiters
            # fix by escaping all parens on the line
            $tline ~~ s:g/'('/\\(/;
            $tline ~~ s:g/')'/\\)/;
            @wlines.push: $tline;
        }

        # handle the processed line or lines
        LINES: for @wlines -> $wline is copy {
            reset-row-var $x, :$xleft;
            my $res = check-bottom($y, $lspace, $ybottom);
            if !$res {
                # need a new page
                reset-page-vars $x, $y, :$npages, :$xleft, :ytop($ytopbaseline);
                $ps.newpage;
                $ps.add_to_page: "/$font $fsize selectfont\n";
            }

            # write the line or skip a line space for a blank line
            if $wline !~~ /\S/ {
                ; # no entry but vspace
                $y -= $lspace;
            }
            elsif $wline ~~ /^ \h* 'doc-title:' (.*) $/ {
                # this should be the first line of text
                my $text = normalize-string ~$0;

                =begin comment
                # fix unbalenced parens problem
                $text ~~ s:g/'('/\\(/;
                $text ~~ s:g/')'/\\)/;
                =end comment

                # use Times bold, 12 point
                $ps.add_to_page: qq:to/HERE/;
                gsave
                /Times-Bold 12 selectfont
                $xcenter $y mt ($text) 10 puttext
                grestore\n
                HERE
                $y -= 12 * 1.2;
            }
            elsif $wline ~~ /^ (\s+) (.*) $/ {
                my $spaces = ~$0;
                my $text   = ~$1;

                =begin comment
                # fix unbalenced parens problem
                $text ~~ s:g/'('/\\(/;
                $text ~~ s:g/')'/\\)/;
                =end comment

                my $xx = $spaces.chars * $fsize;
                $ps.add_to_page: "{$x + $xx} $y mt ($text) 9 puttext\n";
                $y -= $lspace;
            }
            else {
                $ps.add_to_page: "$x $y mt ($wline) 9 puttext\n";
                $y -= $lspace;
            }
            #$y -= $lspace;
            note "DEBUG: y = $y" if $debug == 1;
        }
    }

    note "DEBUG: num pages: $npages" if $debug == 1;
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
                :$list,
                :$ids,
                :$codes,
                :$no-type,
                :$debug = 0,
               ) is export {

    # TODO use Times-Roman for PS text files (lists)

    # here we determine ALL the list-type PS outputs we want
    write-list-rooms(@rooms, :@ofils, :$p, :$debug) if $list;
    write-list-ids(@rooms, :@ofils, :$p, :$debug) if $ids;
    write-list-codes(@rooms, :@ofils, :$p, :$debug) if $codes;

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

sub read-project-data-file($ifil,
                   Project :project(:$p)!,
                   :$no-type,
                   :$debug = 0,
                   --> List
                  ) is export {
    #my Room @rooms;
    my @rooms;
    my RoomDrawing @room-drawings;

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
        note "== line $i" if $debug == 1;
        $line = strip-comment $line;
        $line = ' ' if not $line; # IMPORTANT FOR THE REST OF THIS LOOP

        my $has-ending-slash   = 0;
        my $has-mid-line-slash = 0;
        if $line ~~ /$BSLASH \h* \S+ / {
            ++$has-mid-line-slash;
        }
        if $has-mid-line-slash {
            note "WARNING: line has mid-line backslash: '$line'";
            note "  it MUST be removed";
        }

        if $line ~~ /$BSLASH \h* $/ {
            ++$has-ending-slash;
            note "backslash on end of line '$line'" if $debug == 1;
            $line ~~ s/$BSLASH \h* $//;
            note "  after removal: '$line'" if $debug == 1;
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
        note "DEBUG line $lineno" if $debug == 1;
        note "DEBUG line: '$line'" if $debug == 1;
        next LINE if $line !~~ /\S/;
        next LINE if $line ~~ /^ \s* '='+ \s* $/;
        say "DEBUG2 line: '$line'" if $debug == 1;

        =begin comment
        # TODO handle width x length measurements on room: line
        #   use same double-parsing technique as for furniture lines
        # RECTANGLE
        if $line ~~ / # first collect dimensional and object type at the end of the string
                      [
                         || \h+ (<number>) \h* 'x' \h* (<number>) \h* 'x' \h* (<number>)
                         || \h+ (<number>) \h* 'x' \h* (<number>)
                      ]
                      \h*
                    $/ {
        }
        =end comment

        if $line ~~ /^ \h* room ':' \h* (.*) \h* $/ {
            # a new room
            ++$rnum;

            my $room-dimens;
            my $width;
            my $length;
            my $data = ~$0;
            # collect dimensional and object type at the end of the string
            if $data ~~ / \h* (<number>) \h* 'x' \h* (<number>) \h* $/ {
                $width  = +$0;
                $length = +$1;
                $room-dimens = "$width x $length";
                note "DEBUG: room $rnum has dimens: '$room-dimens'":
            }

            # TODO strip out any room dimen info
            #my $title = normalize-string ~$0;
            my $title = normalize-string $data;

            $curr-room = Room.new: :number($rnum), :$title;
            @rooms.push: $curr-room;

            with $room-dimens {
                my $rd = RoomDrawing.new: :$title, :$width, :$length;
                @room-drawings.push: $rd;
            }

            # reset furniture numbering
            $fnum = 0;

            next LINE;
        }

        #=== BEGIN HEADER INFO COLLECTION ===#
        #    ERROR IF ALREADY READING ROOM INFO
        # these three attributes were set at creation, warn if changed
        if $line ~~ /^ \s* title ':' \s* (.*) \s* $/ {
            my $txt = normalize-string ~$0;
            note "DEBUG: txt: '$txt'" if $debug == 1;
            die "FATAL: header info '$txt' not allowed after room info has begun" if $curr-room;
            if $p.title and $p.title ne $txt {
                note qq:to/HERE/
                WARNING: title $txt has changed since project was created
                HERE
            }
            $p.title = $txt;
            next LINE;
        }
        if $line ~~ /^ \h* 'no-type' ':' \h* (\d) \h* $/ {
            $p.no-type = +$0;
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
            note "DEBUG: handling input code '$key' with text '$txt'" if $debug == 1;
            if $key eq "code" {
                # the code key is the first word of the value
                my @w = $txt.words;
                my $c = @w.shift.lc;
                my $title = @w.join: " ";
                note "DEBUG: handling Project code '$c' with text '$title'" if $debug == 1;
                $p.set-code($c, :$title);
            }
            else {
                $p.push($key, $txt);
            }
            next LINE;
        }

        if $line ~~ /^ \h* scale ':' \h* (\S*) \h*  [\h+ (\N+)]?  $/ {
            die "FATAL: header info '{~$0}' not allowed after room info has begun" if $curr-room;
            my $scale = +$0;
            my $site  = ~$1 // "Site unknown";
            $p.insert-scale: :$scale, :$site;
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
        # save room data with the furn object
        $furn.room       = $curr-room.number;
        $furn.room-title = $curr-room.title;

        my ($wid, $len, $dia, $rad, $hgt);

        #   AND it should replace all this code:

        # ELLIPSE W/ MAJOR x MINOR AXES
        if $line ~~ / # first collect dimensional and object type at the end of the string
                         [
                            || \h+ (<number>) \h* 'e' \h* (<number>) \h* 'x' \h* (<number>)
                            || \h+ (<number>) \h* 'e' \h* (<number>)
                         ]
                         \h*
                       $/ {
            # 1. an elliptical object
            my $s = "elliptical object";
            note "DEBUG: line $lineno item '$s'" if $debug == 1;

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
            $furn.dims2  = "{$ww}x{$ll}";

            # now parse the leading part of the line
            my ($id, $codes, $type, $desc) = parse-leading $leading, $rnum, $fnum, :$no-type, :$debug;
            note "  captures => |$id| |$codes| |$type| |$desc| |$wid| |$len| |h: $hgt|" if $debug == 1;

            $furn.type = $type;
            # handle the id
            if $id and not $p.id-exists($id) {
                # it's unique
                $p.set-id: $id;
                $furn.set-id: $id;
            }
            else { die "FATAL: furniture object with non-unique id: '$id'"; }

            # handle the codes
            if $codes {
                note "DEBUG: handling codes:  |$id| |$codes| |$desc| |$wid| |$len| |h: $hgt|" if $debug == 1;
            for $codes.words -> $c  {
                note "checking furn code '$c' for validity|" if $debug;
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
                            || \h+ (<number>) \h* 'd' \h* 'x' \h* (<number>)
                            || \h+ (<number>) \h* 'd'
                         ]
                         \h*
                       $/ {
            # 2. a circular object with diam
            my $s = "circular object with diam";
            note "DEBUG: line $lineno item '$s'" if $debug == 1;

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
            $furn.dims2  = "{$ww}";

            # now parse the leading part of the line
            my ($id, $codes, $type, $desc) = parse-leading $leading, $rnum, $fnum, :$no-type, :$debug;
            note "  captures => |$id| |$codes| |$type| |$desc| |{$furn.diameter}| |h: $hgt|" if $debug == 1;

            $furn.type = $type;
            # handle the id
            if $id and not $p.id-exists($id) {
                # it's unique
                $p.set-id: $id;
                $furn.set-id: $id;
            }
            else { die "FATAL: furniture object with non-unique id: $id"; }

            # handle the codes
            if $codes {
                note "DEBUG: handling codes:  |$id| |$codes| |$desc| |$wid| |$len| |h: $hgt|" if $debug == 1;
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
                            || \h* (<number>) \h* 'r' \h* 'x' \h* (<number>)
                            || \h* (<number>) \h* 'r'
                         ]
                         \h*
                       $/ {
            # 3. a circular object with radius
            my $s = "circular object with radius";
            note "DEBUG: line $lineno item '$s'" if $debug == 1;

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
            $furn.dims2  = "{$ww}";

            # now parse the leading part of the line
            my ($id, $codes, $type, $desc) = parse-leading $leading, $rnum, $fnum, :$no-type, :$debug;
            note "  captures => |$id| |$codes| |$type| |$desc| |{$furn.radius}| |h: $hgt|" if $debug == 1;

            $furn.type = $type;
            # handle the id
            if $id and not $p.id-exists($id) {
                # it's unique
                $p.set-id: $id;
                $furn.set-id: $id;
            }
            else { die "FATAL: furniture object with non-unique id: $id"; }

            # handle the codes
            if $codes {
                note "DEBUG: handling codes:  |$id| |$codes| |$desc| " if $debug == 1;
            for $codes.words -> $c  {
                note "DEBUG: handling code for furn  '$c'" if $debug == 1;
                if $p.code-exists($c) {
                    # it's valid
                    note "DEBUG: code for furn: $c is known by Project" if $debug == 1;
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
                         || \h+ (<number>) \h* 'x' \h* (<number>) \h* 'x' \h* (<number>)
                         || \h+ (<number>) \h* 'x' \h* (<number>)
                      ]
                      \h*
                    $/ {
            # 4. a rectangular object
            my $s = "rectangular object";
            note "DEBUG: line $lineno item '$s'" if $debug == 1;

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
            $furn.dims2  = "{$ww}x{$ll}";

            # now parse the leading part of the line
            my ($id, $codes, $type, $desc) = parse-leading $leading, $rnum, $fnum, :$no-type, :$debug;
            note "  captures => |$id| |$codes| |$type| |$desc| |$wid| |$len| |h: $hgt|" if $debug == 1;

            $furn.type = $type;
            # handle the id
            if $id and not $p.id-exists($id) {
                # it's unique
                $p.set-id: $id;
                $furn.set-id: $id;
            }
            else { die "FATAL: furniture object with non-unique id: $id"; }

            # handle the codes
            if $codes {
                note "DEBUG: handling codes:  |$id| |$codes| |$desc| |$wid| |$len| |h: $hgt|" if $debug == 1;
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
            note "DEBUG: line $lineno item '$s'" if $debug == 1;

            $furn.width  = 0;
            $furn.length = 0;
            $furn.height = 0;
            $furn.dims   = "?";
            $furn.dims2  = "?";

            # now parse the leading part of the line
            my $leading = $line;
            my ($id, $codes, $type, $desc) = parse-leading $leading, $rnum, $fnum, :$no-type, :$debug;
            note "  captures => |$id| |$codes| |$type| |$desc| |$wid| |$len| |h: $hgt|" if $debug == 1;

            $furn.type = $type;
            # handle the id
            if $id and not $p.id-exists($id) {
                # it's unique
                $p.set-id: $id;
                $furn.set-id: $id;
            }
            else { die "FATAL: furniture object with non-unique id: $id"; }

            # handle the codes
            if $codes {
                note "DEBUG: handling codes:  |$id| |$codes| |$desc| |$wid| |$len| |h: $hgt|" if $debug == 1;
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

} # end sub read-project-data-file

#| Given an empty list of rows, a list of RoomDrawing objects,
#| and the maximum width of the page to be
#| written upon, create a list of Row objects containing RoomDrawing
#| objects to be written as scaled drawings on the output PDF file.
sub make-room-rows(@rows,   # should be empty
                   @rooms,  # all rooms with their measurements
                   $maxwid, # distance between left/right page margins
                   $space,
                   :$scale!, # for init
                   :$debug = 0) {

    @rows   = [];
    my $row = Row.new;
    @rows.push: $row;
    # row var
    my $x = 0; # begin at left margin

    sub reset-row-var {
        # resets to left of the page
        $x = 0;
    }

    multi sub check-right(RoomDrawing $room, $x --> Bool) {
        # given a RoomDrawing instance and its x start
        # point, can it fit on the current row?
        my $xspace = $x + $room.w;
        return $xspace <= $maxwid;
    }

    reset-row-var;

    for @rooms -> RoomDrawing $room {
        if $scale {
            $room.init: :$scale;
        }
        my $title = $room.title;
        note "DEBUG: title: |$title|" if $debug == 1;
        next if $title ~~ /:i '<ff>'/;
        $x += $space if $row.rooms.elems;
        if !check-right($room, $x) {
            # need a new row
            $row = Row.new;
            @rows.push: $row;
            reset-row-var;
        }

        # update row data
        $x += $room.w;
        $row.rooms.push: $room;
        $row.max-height = $room.l if $room.l > $row.max-height;
    }

} # sub make-room-rows

#| Given an empty list of rows, a list of Room objects with their
#| Furniture object children, and the maximum width of the page to be
#| written upon, create a list of Row objects containing Furniture
#| objects to be written as scaled drawings on the output PDF file.
sub make-rows(@rows,   # should be empty
              @rooms,  # all rooms with their furniture
              $maxwid, # distance between left/right page margins
              $space,
              :$scale!, # for init
              :$debug = 0) {

    @rows   = [];
    my $row = Row.new;
    @rows.push: $row;
    # row var
    my $x = 0; # begin at left margin

    sub reset-row-var {
        # resets to left of the page
        $x = 0;
    }

    multi sub check-right(Furniture $f, $x --> Bool) {
        # given a furniture instance and its x start
        # point, can it fit on # the current row?
        my $xspace = $x + $f.w;
        return $xspace <= $maxwid;
    }

    reset-row-var;

    for @rooms -> $r {
        for $r.furniture -> $f {
            if $scale {
                $f.init: :$scale;
            }
            my $title = $f.title;
            note "DEBUG: title: |$title|" if $debug == 1;
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
    #elsif $In ~~ Num|Rat {
    else {
        $ft = $In.Int div 12;
        $in = $In.Int mod 12;
        $in += $In - $In.Int;
        $in = ($in % 12).ceiling;
    }

    return "{$ft}'{$in}";
}

#| A utility sub to convert a valid PostScript file to
#| pdf using the system progeam 'ps2pdf'.
sub ps-to-pdf(@ofils,
              :psfile(:$psf)!,
              :pdfile(:$pdf) is copy,
              :$debug is copy = 0,
             ) {
    if not $pdf {
        $pdf = $psf;
        $pdf ~~ s/'.ps'$/.pdf/;
    }

    # produce the pdf
    # some additional error checking
    if $debug and $debug == 1 {
        note "DEBUG file names: psf '$psf' pdf '$pdf'";
        note "DEBUG early exit"; exit;
    }

    die "FATAL: Input file '$psf' not found" if !$psf.IO.f;
    my $cmd  = "ps2pdf";
    my $args = "$psf $pdf";
    note "DEBUG: running command; 'psf2pdf {$args}'" if 1;
    try run $cmd, $args.words;
    if $! {
        note "WARNING: ps2pdf failed: '{$!.Str}'";
    }
    die "FATAL: Output file $pdf not found" if !$pdf.IO.f;
    @ofils.push: $pdf;

    note "DEBUG set to 3 in ps-to-pdf";
    $debug = 3;
    ($debug and $debug == 3) ??  @ofils.push($psf) !! unlink($psf);
} # sub ps-to-pdf

sub parse-leading($s, $rnum, $fnum, :$no-type!, :$debug = 0, --> List) {
    # now parse the leading part of the line
    #   my ($id, $codes, $desc) = parse-leading $leading, :$debug;
    #
    # example leading input lines:
    #   <number>? <codes>? type, name rest of description
    my $id    = "";
    my $codes = "";
    my $type  = "";
    my $desc  = $s;

    my $num = "$rnum.$fnum";
    my $no-id = 0;

    my @w = $s.words;
    $id = @w.shift;
    $desc = join $SPACE, @w;
    if $id !~~ /<number>/ {
        die "FATAL: This furniture line (number $num) has no leading ID number";
    }
    elsif $id !~~ /<number>/ {
        note "DEBUG: id in parse leading: $id";
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
    # get the "type" unless unwanted
    if not $no-type {
        my @w  = $desc.words;
        $type  = @w.shift;
        $type .= uc;
        $type ~~ s:g/','//;
        $desc  = @w.join: " ";
    }


    note "DEBUG: parsing leading: id/codes/type |$id| |$codes| |$type|" if $debug == 1;

    $codes = normalize-string $codes;

    die "FATAL: code has [] '$codes'" if $codes ~~ /'[' | ']'/;

    $id, $codes, $type, $desc
} # sub parse-leading

sub write-list-headers($fh,
                       :project(:$p),
                       :$debug = 0,
                      ) is export {

    #== headers for ALL text files
    # title, etc.
    if $p.title { $fh.say: "Title: {$p.title}"; }
    $fh.say: "Input file: {$p.input-file}";

    if $p.author { $fh.say: "Author: {$p.author}"; }
    if $p.date { $fh.say: "Project Start Date: {$p.date}"; }
    my $dt = DateTime.now;
    my $ds = sprintf "%04d-%02d-%02dT%02d:%02d:%02d", $dt.year, $dt.month, $dt.day, $dt.hour, $dt.minute, $dt.second;
    $fh.say: "Current Time: $ds";

    # multiply-valued keys
    if $p.address { $fh.say("Address: $_") for $p.address; }
    if $p.phone { $fh.say("Phone: $_") for $p.phone; }
    # show codes with title
    my $cs = $p.codes2str(:list, :sepchar(" "));
    # TODO make this better looking
    if $cs {
        $fh.print: qq:to/HERE/;
        Code : Title
        ==== + =====;
        HERE
        my @clines = $cs.lines;
        for @clines -> $cline {
            my @w = $cline.words;
            my $w = @w.shift;
            $w = sprintf "%-4.4s", $w;
            my $s = @w.join: " ";
            $fh.say: "$w : $s";
        }
    }
    $fh.say();
    #== end headers for ALL files
} # sub write-list-headers

sub write-list-rooms(@rooms, :@ofils, :project(:$p), :$debug = 0) {
    # the MASTER list
    # writes a list in room, furniture order

    # create the raw ASCII text file
    my $txtfil = $p.filename: "text", :list-subtype("");
    my $fh = open $txtfil, :w;

    my $doc-title = "Furniture List by Room";
    write-list-doc-title $fh, :$doc-title, :$debug;

    write-list-headers $fh, :$p, :$debug;

    # this is the standard list output by room, furniture
    my $nitems = 0;
    ROOM: for @rooms -> $r {
        my $ritems = 0;
        $fh.say: "Room {$r.number}: {$r.title}";
        for $r.furniture -> Furniture $f {
            my $t = $f.title;
            if $t ~~ /:i '<ff>'/ {
                # NOTE: this is the ONLY list where we show the
                #       <ff> to trigger a text-to-PS response
                $fh.say: "      <ff>";
                next ROOM;
            }
            ++$nitems; # cumulative number
            ++$ritems;
            my $num   = $f.number;
            my $id    = $f.id;
            my $codes = $f.codes2str: :keys; # output "a bb .."
            my $type  = $f.type; # may be empty string
            $fh.print: "    $id [$codes]";
            $fh.print: " {$f.type} -" if $f.type;
            $fh.say:   " {$f.desc} [{$f.dims}]";
        }
        $fh.say: "  Total items in room: $ritems";
        $fh.say();
    }
    $fh.say: "\nTotal number items: $nitems";
    $fh.close;
    @ofils.push: $txtfil;
    # we now have a text file to convert to ps

    # for dev don't produce PS or PDF
    return if $debug == 2;

    my $psfile = $p.filename: "list", :list-subtype(""), :suffix("ps");
    text-to-ps $txtfil, $psfile, :$p, :$debug;
    ps-to-pdf @ofils, :$psfile, :$debug;

} # sub write-list-rooms

sub write-list-codes(@rooms, :@ofils, :project(:$p), :$debug = 0) {
    # writes a separate list for each code
    # in room, furniture order

    my $codes = $p.codes2str: :keys, :no-commas;
    note "DEBUG: codes: '$codes'" if $debug == 1;
    if 0 and $debug {
        note "DEBUG: early exit";
        exit;
    }

    my @codes = $codes.lc.words;
    CODE: for @codes -> $c {
        # create the raw ASCII text file but ONLY if there are items with that code
        my $txtfil = $p.filename: "text", :list-subtype("code"), :code($c);
        my $fh = open $txtfil, :w;

        my $s = $p.code-name: $c;
        my $doc-title = qq:to/HERE/;
        Furniture List by Room for Code {$c.uc}
        $s
        HERE

        write-list-doc-title $fh, :$doc-title, :$debug;

        write-list-headers $fh, :$p, :$debug;

        my $nitems = 0;
        ROOM: for @rooms -> $r {
            $fh.say: "Room {$r.number}: {$r.title}";
            my $has-coded-furn = 0;

            for $r.furniture -> $f {
                my $t = $f.title;
                if $t ~~ /:i '<ff>'/ {
                    # the MASTER list is the only one to retain the ff for PS
                    #$fh.say: "      <ff>";
                    next ROOM;
                }

                my $has-code = $f.code-exists($c) ?? 1 !! 0;
                next if not $has-code;

                ++$nitems; # cumulative number
                ++$has-coded-furn;

                my $num   = $f.number;
                my $id    = $f.id;
                my $codes = $f.codes2str: :keys; # output "a bb .."
                my $type  = $f.type; # may be empty string
                $fh.print: "    $id [$codes]";
                $fh.print: " {$f.type} -" if $f.type;
                $fh.say:   " {$f.desc} [{$f.dims}] (Room: {$f.room})";

            }
            if not $has-coded-furn {
                $fh.say: "      (no furniture with code '$c')";
            }
        }
        $fh.say: "\nTotal number items: $nitems";
        $fh.close;

        if not $nitems {
            unlink $txtfil;
            next CODE;
        }

        @ofils.push: $txtfil;
        # we now have a text file to convert to ps

        # for dev don't produce PS or PDF
        return if $debug > 1;

        my $psfile = $p.filename: "list", :list-subtype("code"), :suffix("ps"), :code($c);
        text-to-ps $txtfil, $psfile, :$p, :$debug;
        ps-to-pdf @ofils, :$psfile, :$debug;
    }

} # sub write-list-codes

sub write-list-ids(@rooms, :@ofils, :project(:$p), :$debug = 0) {
    # writes a list in id order
    # for all IDs

    # get the complete list with room assignments

    my $nitems = 0;
    my %ids; # id => $furn
    for @rooms -> $r {
        for @($r.furniture) -> $f {
            my $id = $f.id;
            %ids{$id} = $f;
        }
    }

    # create the raw ASCII text file
    my $txtfil = $p.filename: "text", :list-subtype("id");
    my $fh = open $txtfil, :w;

    my $doc-title = "Furniture List by Furniture ID Number";
    write-list-doc-title $fh, :$doc-title, :$debug;

    write-list-headers $fh, :$p, :$debug;

    for %ids.keys.sort(*.Version) -> $id {
        my $f = %ids{$id};
        my $t = $f.title;
        if $t ~~ /:i '<ff>'/ {
            # the MASTER list is the only one to retain the ff for PS
            #$fh.say: "      <ff>";
            next;
        }

        ++$nitems; # cumulative number

        my $num   = $f.number;
        my $codes = $f.codes2str: :keys; # output "a bb .."
        my $type  = $f.type; # may be empty string
        $fh.print: "$id [$codes]";
        $fh.print: " {$f.type} -" if $f.type;
        $fh.say:   " {$f.desc} [{$f.dims}] (Room: {$f.room})";
    }

    $fh.close;
    @ofils.push: $txtfil;
    # we now have a text file to convert to ps

    # for dev don't produce PS or PDF
    return if 3 > $debug > 1;

    my $psfile = $p.filename: "list", :list-subtype("id"), :suffix("ps");
    text-to-ps $txtfil, $psfile, :$p, :$debug;
    ps-to-pdf @ofils, :$psfile, :$debug;

} # sub write-list-ids

sub write-list-doc-title($fh, :$doc-title, :$debug = 0) {
    my @lines = $doc-title.lines;
    for $doc-title.lines -> $line {
        $fh.say: "doc-title: $doc-title";
    }
} # sub write-list-doc-title

multi sub check-bottom(Row $r, Real $y, Real $ybottom, :$debug = 0 --> Bool) {
    note "DEBUG: in Row check-bottom: y = $y, ybottom = $ybottom" if 0 or $debug;

    # used in write-drawings
    # given a row instance and its y start
    # point, can it fit on # the current row?
    my $ybot = $y - $r.max-height;
    $ybot >= $ybottom ?? True !! False
} # sub check-bottom

multi sub check-bottom(Real:D $y, Real:D $lspace, Real:D $ybottom, :$debug = 0 --> Bool) {
    note "DEBUG: in text check-bottom: y = $y, lspace = $lspace, ybottom = $ybottom" if 0 or $debug;

    # used in text-to-ps
    # given a text row and its y start
    # point, can it fit on the current page?
    my $ybot = $y - $lspace;
    my $res = $ybot >= $ybottom ?? True !! False;
    note "DEBUG check-bottom: y = $y; ybot = $ybot; ybottom = $ybottom; res = $res" if $debug == 1;
    $res
} # sub check-bottom

sub reset-page-vars(Real $x is rw, Real $y is rw, UInt :$npages! is rw, Real :$xleft!, Real :$ytop!) {
    # resets page vars to upper left of the page
    $x = $xleft;
    $y = $ytop;
    ++$npages;
} # sub reset-page-vars

sub reset-row-var(Real $x is rw, Real :$xleft!) {
    # start a row
    # resets to left of the page
    $x = $xleft;
} # sub reset-row-var
