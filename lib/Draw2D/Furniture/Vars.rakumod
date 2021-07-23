unit module Draw2D::Furniture::Vars;

#  procset 'MyFunctions':
constant $procset is export = q:to/HERE/;
    %% my procs
    % local definitions:
    /Times-Roman 8 selectfont
    2 setlinewidth % we'll clip the drawings so we just see the inside half
    /bd{bind def} bind def
    /a{add}bd
    /cl{currentlinewidth}bd
    /cpt{currentpoint}bd
    /cp{closepath}bd
    /dv{div}bd
    /d{def}bd
    /ex{exch}bd
    /gr{grestore}bd
    /gs{gsave}bd
    /lto{lineto}bd
    /mt{moveto}bd
    /m{mul}bd
    /n{neg}bd
    /np{newpath}bd
    /rl{rlineto}bd
    /rm{rmoveto}bd
    /rot{rotate}bd
    /sg{setgray}bd
    /sh{show}bd
    /sl{setlinewidth}bd
    /st{stroke}bd
    /s{sub}bd
    /tr{translate}bd
    /i2p{72 m}bd % convert inches to points
    /puttextdict 50 dict def
    /puttext { % Stack: string location_code
               % (position to place--relative to the current point [cp],
               %   an integer: 0-11);
               % note: must have defined a current and correct font
      puttextdict begin
      /code ex d
      /stname ex d
      gs
      cpt tr np
      0 0 mt stname false charpath flattenpath pathbbox
      /ury ex d
      /urx ex d
      /lly ex d
      /llx ex d
      /mx urx llx a .5 m d
      /my ury lly a .5 m d

      0 code eq {/ox 0 mx  s d /oy 0 my  s d} if %               center of text bbox positioned at the cp
      1 code eq {/ox 0 llx s d /oy 0 my  s d} if %  center of left edge of text bbox positioned at the cp
      2 code eq {/ox 0 llx s d /oy 0 lly s d} if %    lower left corner of text bbox positioned at the cp
      3 code eq {/ox 0 mx  s d /oy 0 lly s d} if % center of lower edge of text bbox positioned at the cp
      4 code eq {/ox 0 urx s d /oy 0 lly s d} if %   lower right corner of text bbox positioned at the cp
      5 code eq {/ox 0 urx s d /oy 0 my  s d} if % center of right edge of text bbox positioned at the cp
      6 code eq {/ox 0 urx s d /oy 0 ury s d} if %   upper right corner of text bbox positioned at the cp
      7 code eq {/ox 0 mx  s d /oy 0 ury s d} if % center of upper edge of text bbox positioned at the cp
      8 code eq {/ox 0 llx s d /oy 0 ury s d} if %    upper left corner of text bbox positioned at the cp
     % position relative to the baseline
      9 code eq {/ox 0 llx s d /oy 0       d} if % on base line (y of cp), left-justified on cp
     10 code eq {/ox 0 mx  s d /oy 0       d} if % on base line (y of cp), centered horizontally
     11 code eq {/ox 0 urx s d /oy 0       d} if % on base line (y of cp), right-justified on cp

      ox oy tr

      gs
      0 sg
      np 0 0 mt stname sh
      gr

      gr
      end % required to pop the dict
    }bd % puttext
    % circle
    /circledict 50 dict def
    /circle { % Stack: cx cy rad
      circledict begin
      /rad ex d
      /cy ex d
      /cx ex d
      gs
      np cx cy rad 0 360 arc clip st
      gr
      end % required to pop the dict
    }bd % circle
    % box
    /boxdict 50 dict def
    /box { % Stack: ulx uly width height
      boxdict begin
      /height ex d
      /width ex d
      /uly ex d
      /ulx ex d
      gs
      np ulx uly mt
      0 height neg rlineto
      width 0 rlineto
      0 height rlineto
      closepath clip st
      gr
      end % required to pop the dict
    }bd % box

    % ellipse thanks to the Adobe PostScipt Tutorial and Cookbook, pp. 139-141
    /ellipsedict 8 dict def
    ellipsedict /mtrx matrix put
    /ellipse { % Stack: cx cy xrad yrad startangle endangle
      ellipsedict begin
      /endangle ex d
      /startangle ex d
      /yrad ex d
      /xrad ex d
      /cy ex d
      /cx ex d
      /savematrix mtrx currentmatrix def
      cx cy translate
      xrad yrad scale
      0 0 1 startangle endangle arc
      savematrix setmatrix
      end % required to pop the dict
    }bd % ellipse

    % various font defs may be added here

    %%===== procs used for Grace's wedding and used in other projects afterward

/BreakIntoLines_dict 30 dict def
/BreakIntoLines { % stack (text) linelength linespace showflag
  % modified from PS Cookbook, p. 175
  % current point as x, y
  % if show flag is !0, lines are printed, otherwise max linelength is left on stack
  BreakIntoLines_dict begin
  /showflag exch def

  /linespace exch def
  /linelength exch def

  /textstring exch def
  /wordbreak ( ) def
  gsave
  /maxwidth 0 def
  currentpoint translate /sy 0 def
  showflag 0 ne
    { /proc {
        0 sy moveto show /sy sy linespace sub def
      } def }
    { /proc {
        0 sy moveto /sy sy linespace sub def
        curwidth maxwidth gt { /maxwidth curwidth def } if
      } def } ifelse

  /breakwidth wordbreak stringwidth pop def
  /curwidth 0 def
  /lastwordbreak 0 def

  /startchar 0 def
  /restoftext textstring def

  { restoftext wordbreak search
    { /nextword exch def pop
      /restoftext exch def
      /wordwidth nextword stringwidth pop def

      curwidth wordwidth add linelength gt
	{ textstring startchar
	  lastwordbreak startchar sub
	  getinterval proc
	  /startchar lastwordbreak def
	  /curwidth wordwidth breakwidth add def
        }
	{ /curwidth curwidth wordwidth add
		breakwidth add def
	}
        ifelse

	/lastwordbreak lastwordbreak
	nextword length add 1 add def
     }
     {pop exit}
     ifelse
  } loop
  /lastchar textstring length def
  textstring startchar lastchar startchar sub
  getinterval proc
  grestore
  maxwidth
  end
} bind def % BreakIntoLines

/getbboxdict 30 dict def
/getbbox { % stack: string
  % Returns bounding box of string on stack as llx lly urx ury.  must have
  % current font.
  getbboxdict begin
  /str exch def
  0 0 moveto
  /strlen str length def
  % llx and urx come from first and last characters
  % first
  /tstr 3 string def
  str 0 1 getinterval tstr cvs gbb
  pop pop pop /llx exch def
  % last
  str strlen 1 sub 1 getinterval tstr cvs gbb
  pop /urx exch def
  str strlen 1 sub 1 getinterval tstr cvs stringwidth pop
  /wx exch def /urx urx wx sub def % want just the extra bit
  /lly 0 def
  /ury 0 def
  /width 0 def
  str {
    cvc
    /c exch def
    0 0 moveto c gbb
    /uy exch def pop /ly exch def pop
    lly ly lt { /lly ly def } if
    ury uy gt { /ury uy def } if
    c stringwidth pop /wx exch def
    /width width wx add def
  } forall
  /urx urx width add def
  % leave params on stack
  llx lly urx ury
  end
} bind def % getbbox

/getbbox_spec_dict 30 dict def
/getbbox_spec { % stack: string currfontscale
  % Returns bounding box of string on stack as llx lly urx ury.  must have
  % current font. Special handling for '_{nn}', '^{nn}', and '{nn}'. For now
  % first and last characters must not be special.

  % Symbol font: degree \260  minus: \055
  % normal fonts: em dash: \320 en dash: \261

  getbbox_spec_dict begin
  gs
  /currentscale exch def
  /str exch def
  % currentscale
  setscript
  /strlen str length def
  /prevchar ( ) def
  % llx and urx come from first and last characters
  % first
  0 0 moveto
  /tstr 3 string def
  str 0 1 getinterval tstr cvs gbb
  pop pop pop /llx exch def
  % last
  0 0 moveto
  str strlen 1 sub 1 getinterval tstr cvs gbb
  pop /urx exch def
  /lly 0 def
  /ury 0 def
  /width 0 def
  /inspec 0 def
  /spechar 0 def
  /subscript 0 def % sub
  /script 0 def % sub or super
  /skip 0 def
  str {
    cvc /c exch def
    % c special?
    c (_) eq { /subscript 1 def /script 1 def /skip 1 def } if
    c (^) eq {                  /script 1 def /skip 1 def } if
    c ({) eq { script 1 ne { /spechar 1 def   /skip 1 def } if } if
    c (}) eq { /inspec 0 def /script 0 def /subscript 0 def
               /spechar 0 def                 /skip 1 def } if
    gsave
    skip 0 eq {
      spechar 1 eq {
        /Symbol currentscale selectfont
      } if
      script 0 eq { 0 0 moveto}
        {
        currentfont currentscale sscale mul selectfont
        subscript 1 eq { 0 lbase moveto }{ 0 ubase moveto } ifelse
      } ifelse

      c gbb
      /uy exch def pop /ly exch def pop
      lly ly lt { /lly ly def } if
      ury uy gt { /ury uy def } if
      c stringwidth pop /wx exch def
      /width width wx add def
    }
    { /skip 0 def } ifelse
    grestore

  } forall
  gr
  llx lly urx ury
  end
} bind def % getbbox_spec

/printtext_spec_dict 30 dict def
/printtext_spec { % stack: string  currfontscale
  % Prints text with special characters embedded.  Special handling for
  % '_{nn}', '^{nn}', and '{nn}'. For now first and last characters must not
  % be special.

  % Symbol font: degree \260  minus: \055
  % normal fonts: em dash: \320 en dash: \261
  printtext_spec_dict begin

  /currentscale exch def
  /str exch def
  %currentscale
    setscript
  currentpoint /cy exch def /cx exch def
  /inspec 0 def
  /spechar 0 def
  /subscript 0 def % sub
  /script 0 def % sub or super
  /skip 0 def
  /tstr 3 string def
  str {
    cvc  /c exch def
    cx cy moveto
    % c special?
    c (_) eq { /subscript 1 def /script 1 def    /skip 1 def } if
    c (^) eq {                  /script 1 def    /skip 1 def } if
    c ({) eq { script 1 ne { /spechar 1 def } if /skip 1 def } if
    c (}) eq { /inspec 0 def /script 0 def /subscript 0 def
               /spechar 0 def                    /skip 1 def } if

    gsave
    skip 0 eq {
      spechar 1 eq {
        /Symbol currentscale selectfont
      } if
      script 1 eq {
        currentfont currentscale sscale mul selectfont
        subscript 1 eq { 0 lbase rmoveto }{ 0 ubase rmoveto } ifelse
      } if

      c show
      currentpoint pop /cx exch def
    }
    { /skip 0 def } ifelse

    grestore
  } forall
  end
} bind def % printtext_spec

/wraptitle_dict 30 dict def
/wraptitle { % 7 args on stack: (fig num) space (title) totalwidth sx sy linespace
  % must have current font. sx and sy are midpoint on baseline of title start.
  wraptitle_dict begin
  /linespace exch def
  /sy exch def
  /sx exch def
  /totalwidth exch def
  /title exch def
  /space exch def
  /fig exch def

  gsave sx sy translate fig stringwidth pop /fwidth exch def
  /twidth totalwidth fwidth sub space sub def
  % print fig num
%  totalwidth -.5 mul 0 moveto fig show
%  totalwidth  .5 mul twidth sub 0 translate

  % wordwrap title fig show
  0 0 moveto title twidth linespace 0 BreakIntoLines % get max linewidth

  /twidth exch def
  /totalwidth fwidth space add twidth add def
  totalwidth -.5 mul 0 moveto fig show
  totalwidth  .5 mul twidth sub 0 translate
  0 0 moveto title twidth linespace 1 BreakIntoLines

  grestore
  end
} bind def % wrap title

%%% add fonts here =====================================================
%%% add fonts here =====================================================
%%% add fonts here =====================================================
HERE
