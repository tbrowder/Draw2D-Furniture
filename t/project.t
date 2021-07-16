use Test;

use Draw2D::Furniture;
use Draw2D::Furniture::Classes;

my ($p, $c, $f);
my $basename = "test";

# test all options

$p = Draw2D::Furniture::Classes::Project.new: :$basename;
$p.set-code: 'a', :title("Alpha");

$c = $p.codes2str: :keys;
is $c, "a";

$p.set-code: 'b', :title("Bravo");
$c = $p.codes2str: :keys;
is $c, "a, b";

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
