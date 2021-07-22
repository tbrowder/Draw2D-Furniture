use lib <../lib>;

my @ids = <
    1 1.10 1.2 1.20
    4 4.10 4.3 4.31
>;

# following due to @mykhal and @MasterDuke on $raku
my @a =  @ids.sort(*.Version);
say @a;

sub sort-by-id {
    my ($a1, $a2) = $^a.split: '.';
    my ($b1, $b2) = $^b.split: '.';
    $a2 = 0 if not $a2.defined;
    $b2 = 0 if not $b2.defined;
    $a1 != $b1 ?? $a1 <=> $b1 !! $a2 <=> $b2
}
