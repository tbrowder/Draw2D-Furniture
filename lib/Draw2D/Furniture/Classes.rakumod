unit module Draw2D::Furniture::Classes;

class Project {...}
class Furniture {...}

role Collections {

    has %.ids;   # unique furniture id numbers
    has %.codes; # all known codes to sort furniture lists by
                 #   code => list name to add for output 
                 #   not case sensitive
                 #   e.g.: a  => Apartment
                 #         gb => Gulf Breeze
                 #         go => Goodwill
                 #         s  => Sell
                 #         t  => Throw-away

    method id(Furniture:D: --> Str) {
        # outputs the id as a string
        # should only be one key (the unique ID)
        my $n = self.ids.elems;
        if $n > 1 {
            die "FATAL: Unexpected: furniture object with multiple IDs: $n"
        }
        my $s = "";
        if self.ids.elems {
            for self.ids.keys {
                $s = $_;
                last;
            }
        }
        $s 
    }

    method id-exists($id, :$debug --> Bool) {
        # true if id exists in caller's hash
        #%(self.ids{$id}):exists ?? True !! False
        %.ids{$id}:exists ?? True !! False
    }

    method code-exists($code, :$debug --> Bool) {
        # true if a single code exists in caller's hash
        %(self.codes{$code}):exists
    }
    
    method codes2str(:$keys, :$list, :$debug --> Str)  {
        # my $codes = $f.codes2str: :keys; # output "a bb .."
        # outputs the %.codes as a list or a project header

        my $s;
        if $keys {
            $s = self.codes.elems ?? self.codes.keys.lc.sort.join(", ") !! "?";
        }
        elsif $list {
            $s = "";
            for self.keys.lc.sort -> $k {
                my $v = self.codes{$k};
                $s ~= "\n" if $s;
                $s ~= $v;
            }
        }
        $s
    }

    method set-id($id,           # a unique number for the Project and child
                  :$debug
                  --> Str
                 ) {
        # used by the Project object to keep all ids used by furniture children
        # used by the Furniture object to set its id if valid (checked with the parent project)
        my $err = "";

        if self ~~ Furniture {
            # must be the child asking if its id is unique
            # cannnot have but one ids element
            if self.ids.elems {
                $err = "FATAL: Attempting to get a new ID when one exists";
            }
            elsif self.id-exists($id) {
                $err = "FATAL: Attempting to get a new ID when one exists";
            }
            else {
                self.ids{$id} = 1;
            }
        }
        else {
            # the Project
            if self.id-exists($id) {
                $err = "FATAL: Attempting to get a new ID when one exists";
            }
            else {
                self.ids{$id} = 1;
            }
        }
        $err
    }

    method set-code($code! is copy,  # a space-separated string of one or more codes (multiple codes should only be used by a child
                    :$title,         # for use by the Project object)
                                     # if this is used, the $code entry must be a single value
                    :project(:$p),   # for use by the Furniture child object to check validity
                    :$debug 
                    --> Str
                   ) {
        # used by the Project object to keep all codes used by furniture children
        # used by the Furniture object to keep all used by furniture children
     
        # adds $code to the collection
        $code .= lc;
        my @c = $code.words;
        my $n = @c.elems;
        if $title.defined {
            # should only be one code and should be only used by the project, i.e., $p should NOT be defined
            my $err = "";
            if $p.defined {
                $err ~= "the 'title' attr cannot be used by a Project child\n";
            }
            if $n != 1 {
                $err ~= "the 'title' attr cannot be used with multiple codes\n";
            }

            return "ERROR: $err" if $err;

            # okay to add to collection
            if self.codes{$code}:exists {
                my $v = self.codes{$code};
                return "ERROR: code '$code' already exists with title '$v'";
            }
            self.set-code($code, :$title);
            return Q|| # empty string
        }

        # a child must have permission from the parent to enter codes only
        return "ERROR: codes alone may not be entered by a Project" if not $p.defined;
 
        my $err = "";
        for @c -> $c {
            # the project must know about it
            if not $p.code-exists($c) {
                $err ~= "$c\n";
                next;
            }
            self.codes{$code} = 1;
        }
        return "ERROR: the following codes are not known in this project [$err]" if $err;
          
        Q|| # empty string
    }
}

class Project does Collections is export {
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


    has @.author  is rw; # multi-valued (one per line)
    has @.address is rw; # multi-valued (one per line)
    has @.note    is rw; # multi-valued (one per line)
    has @.email   is rw; # multi-valued (one per line)
    has @.phone   is rw; # multi-valued (one per line)
    has @.mobile  is rw; # multi-valued (one per line)

    method push($attr-key, $value) {
        given $attr-key {
            when $_ eq 'author'  { self.author.push:  $value }
            when $_ eq 'address' { self.address.push: $value }
            when $_ eq 'note'    { self.note.push:    $value }
            when $_ eq 'email'   { self.email.push:   $value }
            when $_ eq 'phone'   { self.phone.push:   $value }
            when $_ eq 'mobile'  { self.mobile.push:  $value }
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

class Furniture does Collections is export {
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

    # new attrs in api 2
    has $.desc  is rw;

    method init() {
        # must have required inputs
        die "FATAL: incomplete inputs" if !($.width || $.radius || $.diameter2);
        die "FATAL: incomplete inputs" if !($.id || $.codes || $.desc);
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

    =begin comment
    method set-id($id, :project(:$p), :$debug --> Str) {
        #   my $res  = $furn.set-id: $id, :project($p);
    }

    method set-code($codes, :project(:$p), :$debug --> Str) {
        # codes as input "a ab" (space-separated list)
        #   my $res2 = $furn.set-codes: $codes, project($p);
    }
    =end comment


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
