RAKU     := raku
LIBPATH  := lib

furn := furniture.inp

exe := ./bin/draw2d 


.PHONY: test bad good clean

default: simple

simple:
	$(RAKU) -I$(LIBPATH) $(exe) $(furn)

draw:
	$(RAKU) -I$(LIBPATH) $(exe) $(furn) draw

both:
	$(RAKU) -I$(LIBPATH) $(exe) $(furn) list draw

all:
	$(RAKU) -I$(LIBPATH) $(exe) $(furn) all

