# need to create a sub that can detect
# an unescaped, unbalanced parens 

my @lines = 
"blah \{ ( blah [",
"blah ( blah ) blah",
"blah ( blah ) blah )",
"blah ) blah",
;

say "Input lines with parenthese:";
say "  $_" for @lines;

say "Input lines with all parenthese escaped:";

for @lines -> $line is copy {
    $line ~~ s:g/'('/\\(/;
    $line ~~ s:g/')'/\\)/;
    say "  $line";
}


