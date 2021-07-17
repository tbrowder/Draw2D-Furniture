use Test;

use Draw2D::Furniture;
use Draw2D::Furniture::Classes;

my ($p, $c, $f);
my $basename = "test";

# test all options

$p = Draw2D::Furniture::Classes::Project.new: :$basename;
$p.set-code: 'a', :title("Alpha");

$c = $p.codes2str: :keys;
is $c, "a", "set code and title, keys with commas";

$p.set-code: 'b', :title("Bravo");
$c = $p.codes2str: :keys;
is $c, "a, b", "set code and title, keys with commas";

$p.set-code: 'C', :title("Charlie");
$c = $p.codes2str: :keys;
is $c, "a, b, c", "set code and title, keys with commas";

$c = $p.codes2str: :keys, :no-comma;
is $c, "a b c", "code keys, no comma";

$c = $p.codes2str: :list;
is $c, "a => Alpha\nb => Bravo\nc => Charlie\n", "code list, default fat comma";

$c = $p.codes2str: :list, :sepchar("\t");
is $c, "a \t Alpha\nb \t Bravo\nc \t Charlie\n", "code list, tsbs";

my @type = <list draw text>;
my @suffix = <ps pdf inp dot none>;
for @type -> $type {
    for @suffix -> $suffix {
        lives-ok {
            $f = $p.filename: $type, :$suffix;
        }, "type: $type; suffix: $suffix; filename: {$f = $p.filename: $type, :$suffix}";
    }
}

done-testing;
