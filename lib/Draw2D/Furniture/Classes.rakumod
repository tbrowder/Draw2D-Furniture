unit module Draw2D::Furniture::Classes;

class Project is export {
    # SET UPON CREATION WARN IF DIFFERENT
    has $.title    is rw; # normally set upon creation, may have spaces
    has $.date     is rw; # normally set upon creation
    has $.basename is rw; # normally set upon creation # cannot have spaces

    # following attribute values cannot have spaces
    has $.list-name is rw = "furniture-list";     # was $ofilL
    has $.draw-name is rw = "furniture-drawings"; # was $ofilD

    # following have defaults:
    has $.in-per-ft is rw = 0.25; # scale
    has $.units is rw     = 'in-per-ft';
    has $.scale is rw     = 0.25; # in-per-ft


    has @.author is rw;  # multi-valued (one per line)
    has @.address is rw; # multi-valued (one per line)
    has @.note  is rw;   # multi-valued (one per line)
    has @.email is rw;   # multi-valued (one per line)
    has @.phone is rw;   # multi-valued (one per line)
    has @.mobile is rw;  # multi-valued (one per line)

    method push($attr-key, $value) {
        given $attr-key {
            when $_ eq 'author' { self.author.push: $value }
            when $_ eq 'address' { self.author.push: $value }
            when $_ eq 'note' { self.note.push: $value }
            when $_ eq 'email' { self.email.push: $value }
            when $_ eq 'phone' { self.phone.push: $value }
            when $_ eq 'mobile' { self.phone.push: $value }
        }
    }

    # output file names:
    #   basename-[list-name|draw-name].[inp|ps|pdf]
    method inp {
        my $nam = self.title;
        $nam = join '-', $nam.words;
        $nam ~= '.input';
    }

    method ps(:$list, :$draw, :$base) {
        my $nam = self.basename.defined ?? self.basename !! '';
        $nam ~= '-' if $nam;
        $nam ~= $list ?? self.list-name !! self.draw-name;
        $nam ~= '.ps' if not $base;
    }

    method pdf(:$list, :$draw, :$base) {
        my $nam = self.basename.defined ?? self.basename !! '';
        $nam ~= '-' if $nam;
        $nam ~= $list ?? self.list-name !! self.draw-name;
        $nam ~= '.pdf' if not $base;
    }
}

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
    has $.height    is rw = 0;
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
            # apply scale
            $.w = $.diameter  * $.sf;
            $.h = $.diameter2 * $.sf;
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
    # given the ulx and uly corner of its
    # bounding box in real page coords
    # and orientation:
    # adjust the scale to 1/4" per foot, then 72 pts per page inch

    # a 1 foot desk = 12 inches
    # 12 inches scales to 0.25 inches on paper: 1/48
    # 1 inch = 72 points
    # so what do we multiply model inches by to get it correct on paper?
    # scale = 48/72
    method ps-draw($ps, :$ulx, :$uly) {
        # define the center of the bounding box
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
        if $.diameter2 {
            # draw an ellipse centered on the bounding box
            $s ~= qq:to/HERE/;
            gs np $cx $cy {$.w * 0.5} {$.h * 0.5} 0 360 ellipse clip st gr
            HERE
        }
        elsif $.width {
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
