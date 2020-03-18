[![Build Status](https://travis-ci.com/tbrowder/Draw2D-Furniture-Raku.svg?branch=master)](https://travis-ci.com/tbrowder/Draw2D-Furniture-Raku)

# Draw2D::Furniture

Provides custom, scaled furniture outlines for home and office planning

## Additional dependencies

In addition to the automatically installed Raku modules, the user
needs to manually install or otherwise ensure the following are
available:

1. Perl module `PostScript::File`
2. program `ps2pdf`
3. program `a2ps`

## Process

+ Prepare a formatted text input file describing rooms and
furniture items in them.

+ Run the executable `draw2d-output` with the input file
to produce two pdf files, each of one or more pages:

    1. `furniture-list.pdf` - A list of the rooms and furniture with each furniture item's
       unique reference number, description, and its dimensions

    2. `furniture-drawings.pdf` - A series of scaled drawings of each
       furniture item suitible for cutting out and placing on a
       blueprint to plan furniture arrangements

Note the output file names can be specified in the input data file.

See the example input file in the test directory (`t/data/furniture-input.txt`).


## Contributing

Interested users are encouraged to contribute improvements and
corrections to this module, and pull requests, bug reports, and
suggestions are always welcome.

## LICENSE and COPYRIGHT

Artistic 2.0. See [LICENSE](./LICENSE).

Copyright (c) 2020 Thomas M. Browder, Jr. <<tom.browder@gmail.com>>
