[![Build Status](https://travis-ci.com/tbrowder/Draw2D-Furniture-Raku.svg?branch=master)](https://travis-ci.com/tbrowder/Draw2D-Furniture-Raku)

# Draw2D::Furniture

Provides custom, scaled furniture outlines for home and office planning

## Additional dependencies

In addition to the automatically installed Raku modules, the user
needs to manually install or otherwise ensure the following are
available:

1. Perl module `PostScript::File`
2. program `ps2pdf`

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

Note the default output file names can be specified in the input data file.

See the example input file in the test directory (`t/data/furniture-input.txt`).

Run the `Makefile` in your clone of this repository to create output
files from the example input file:


``` Raku
$ make doc
PERL6LIB=lib raku -Ilib bin/draw2d-output t/data/furniture-input.txt
Normal end.
See output files:
  furniture-list.pdf
  furniture-drawings.pdf
```

You can run `make doc2` to run the program with the debug flags on if
you wish.

In either case, run `make clean` to remove the created files.

## Contributing

Interested users are encouraged to contribute improvements and
corrections to this module.  Pull requests (PRs), bug reports, and
suggestions are always welcome.

## LICENSE and COPYRIGHT

Artistic 2.0. See [LICENSE](./LICENSE).

Copyright (c) 2020 Thomas M. Browder, Jr. <<tom.browder@gmail.com>>
