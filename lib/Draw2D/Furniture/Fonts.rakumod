unit module Draw2D::Furniture::Fonts;

constant %known-fonts is export = set <
    Courier
    Courier-Bold
    Courier-Oblique
    Courier-BoldOblique
    Times-Roman
    Times-Bold
    Times-Italic
    Times-BoldItalic
    Helvetica
    Helvetica-Bold
    Helvetica-Oblique
    Helvetica-BoldOblique
    Symbol
>;

sub show-fonts is export {
    say "Known fonts:";
    say "    $_" for %known-fonts.keys.sort
}

