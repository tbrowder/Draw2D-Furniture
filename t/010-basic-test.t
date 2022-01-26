use Test;

use Draw2D::Furniture::Classes;

plan 6;

lives-ok { <<raku -I../lib "../bin/draw2d">> }, "test binary";
lives-ok { <<raku -I../lib "../bin/draw2d-output">> }, "test binary";

my $r = Row.new;

my $R  = Room.new;
my $RD = RoomDrawing.new;
my $f  = Furniture.new;

isa-ok $r, Row;
isa-ok $R, Room;
isa-ok $RD, RoomDrawing;
isa-ok $f, Furniture;
