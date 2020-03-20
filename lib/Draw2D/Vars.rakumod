unit module Draw2D::Vars;

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

    % various font defs
HERE
