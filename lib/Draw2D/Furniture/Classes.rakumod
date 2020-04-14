unit module Draw2D::Furniture::Classes;

class Row is export {
    has $.max-height is rw = 0; # PS points
    has @.furniture is rw;
}

class Room is export {
    has $.number    is rw ;
    has $.title     is rw = "";
    has @.furniture is rw ;
}

class Furniture is export {
    has $.number    is rw;
    has $.title     is rw = "";
    # input dimensions are inches
    has $.width     is rw = 0;
    has $.length    is rw = 0;
    has $.diameter  is rw = 0;
    has $.diameter2 is rw = 0; # for ellipses
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
        die "FATAL: incomplete inputs" if !($.width || $.radius || $.diameter2);
        $.sf = 72 / (12 / $.scale);
        if $.radius {
            # apply scale
            $.w = $.radius * 2 * $.sf;
            $.h = $.w;
        }
        elsif $.diameter2 && $.diameter {
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
    # so what do we multiply model inches by to get it correct on paper?
    # scale = 48/72
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
        elsif $.diameter2 {
            # draw an ellipse 
        }
        $ps.add_to_page: $s;
    }
}
