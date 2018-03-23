basic_vsync     = 00220H
basic_ret_app1  = 00292H
basic_ret_app2  = 002A4H
basic_if_break  = 00F46H

screen:	        = $2000
PAUSE 	        = $0F35	;inBC=delay
KSCAN	        = $02bb	;outHL=Key, L=ROWbit, H=KEYbit
FINDCHR         = $07bd	;HL=key

        .include codegen/global.inc

;-------------------------------------------------------------------------------

        .org    $4009

        .exportmode NO$GMB
        .export

versn	.byte   $00
e_ppc	.word   $0000
d_file	.word   dfile
df_cc	.word   dfile+1 
vars	.word   var 
dest	.word   $0000 
e_line	.word   var+1 
ch_add	.word   last-1 
x_ptr	.word   $0000 
stkbot	.word   last 
stkend	.word   last 
breg	.byte   $00 
mem     .word   membot 
unuseb	.byte   $00 
df_sz	.byte   $02 
s_top	.word   $0000 
last_k	.word   $ffff 
db_st	.byte   $ff
margin	.byte   55 
nxtlin	.word   line10 
oldpc   .word   $0000
flagx   .byte   $00
strlen  .word   $0000 
t_addr  .word   $0c8d; $0c6b
seed    .word   $0000 
frames  .word   $ffff
coords  .byte   $00 
        .byte   $00 
pr_cc   .byte   188 
s_posn  .byte   33 
s_psn1  .byte   24 
cdflag  .byte   64 
PRTBUF  .fill   32,0
prbend  .byte   $76 
membot  .fill   32,0

;-------------------------------------------------------------------------------

        .include lowdata.bin.inc

;-------------------------------------------------------------------------------

line1:  .byte   0,1
        .word   line1end-$-2
        .byte   $ea

;
.module main
;
PS: ; program start

        ld      bc,$e007                ; go low
        ld      a,$b2
        out     (c),a

        xor     a
        ld      (soundEn),a

        call    cls
        ld	ix,GENERATE_VSYNC

        call    initwad

        ld      a,$20                   ; lowdat
        call    wadload
        ld      hl,$8000
        ld      de,LOWDATSTART
        ld      bc,$4000-LOWDATSTART
        ldir

        ld      hl,titletext1
        call    centreTextOut
        ld      hl,titletext2
        call    centreTextOut
        ld      hl,titletext3
        call    centreTextOut
        ld      hl,titletext4
        call    centreTextOut

        ld      hl,berlin
        call    INIT_STC

-:      call    waitkeytimeout          ; times out after approx 5 seconds
        jr      nc,_advance
        
        ld      hl,titletext5           ; prompt
        call    centreTextOut
        jr      {-}

_advance:
        ld      hl,slocalcraster
        ld      (slocalc),hl

        ld      a,$ff                   ; music on, show title picture
        ld      (soundEn),a

        ld      a,1                     ; prepare for first chapter
        ld      (chapnum),a

_gochap:
        call    loadchapter

        xor     a                       ; start at page 0
        call    trysetpage

_updatepage:
;        call    cls

        ld      hl,(page)

        xor     a                       ; disable jumps until they're rendered
        ld      (jmpA),a
        ld      (jmpB),a
        ld      (jmpC),a

        ld      b,SCREENLINES           ; render up to this many lines

_nextline:
        push    hl
        push    bc

        ld      b,(hl)                  ; line character count

        inc     hl                      ; line ptr
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a

        or      h                       ; line ptr is 0? if so we're done
        jr      nz,{+}

        pop     hl                      ; disgorge the stack and bail
        pop     hl
        jr      _mainloop

+:      call    clearosr
        xor     a                       ; char count 0 = newline
        cp      b
        jr      z,_emptyline

        ld      (x),a
        set     7,h                     ; pointer to text data

_line:
        push    bc
        ld      a,(hl)
        call    extcharout 
        pop     bc
        inc     hl
        djnz    _line

_emptyline:
        ld      a,(y)
        inc     a
        ld      (y),a

        call    scrollup

        pop     bc
        pop     hl
        inc     hl
        inc     hl
        inc     hl
        djnz    _nextline


_mainloop:
        call    gamestep

        ld      a,(right)
        cp      1
        jr      nz,{+}
        ld      a,(chapnum)
        inc     a
        ld      a,$e
        ld      (chapnum),a
        jp      _newchapter
+:

        ld      a,(sound)
        cp      1
        jr      nz,_tu

        ld      a,(soundEn)
        xor     $ff
        ld      (soundEn),a
        call    z,mute_stc

_tu:    ld      a,(up)
        cp      1
        jr      nz,_td

_tudi:  ld      a,(pagenum)
        dec     a
        call    trysetpage
        jp      nz,_updatepage

_td:    ld      a,(down)
        cp      1
        jr      z,_tddi
        ld      a,(select)
        cp      1
        jr      nz,_tja

_tddi:  ld      a,(pagenum)
        inc     a
        call    trysetpage
        jp      nz,_updatepage

_tja:   ld      a,(btnA)
        cp      1
        jr      nz,_tjb
        ld      a,(jmpA)
        and     a
        jr      z,_tjb

        ld      a,(jtab+0)
        jr      _newchapter

_tjb:   ld      a,(btnB)
        cp      1
        jr      nz,_tjc
        ld      a,(jmpB)
        and     a
        jr      z,_tjc

        ld      a,(jtab+1)
        jr      _newchapter

_tjc:   ld      a,(btnC)
        cp      1
        jr      nz,_mainloop
        ld      a,(jmpC)
        and     a
        jp      z,_mainloop

        ld      a,(jtab+2)

_newchapter:
        ld      (chapnum),a
        jp      _gochap





getpageptr:
        ; a <- page number
        ; hl -> offset into page data

        ld      hl,(chapter)            ; pointer to page info in chapter metadata chp_1, chp_K etc
        ld      d,0
        ld      e,a
        add     hl,de
        ret



beginpage:
        ld      l,(hl)                  ; get offset into page line structure
        ld      h,0
        ld      d,$80
        ld      e,l
        add     hl,hl
        add     hl,de                   ; * 3
        ld      (page),hl               ; points to line list structure
        ret


trysetpage:
        cp      $ff             ; page of -1 no allowed
        ret     z

        ld      (_tempage),a    ; self modify

        call    getpageptr      ; get pointer to start relevant page table entry
        ld      a,(hl)          ; end of chapter marked with ffff
        cp      $ff
        ret     z

_tempage=$+1
        ld      a,-1            ; self modified
        ld      (pagenum),a
        call    beginpage       ; store calculated values in memory
        or      $ff             ; clear z flag to indicate success
        ret


chapnum:
        .byte   0
chapter:
        .word   0
chappic:
        .byte   0
        
pagenum:
        .byte   0
page:
        .word   0

linenum:
        .byte   0

jtab = $
jmpA = $+3
jmpB = $+4
jmpC = $+5
        .byte   0,0,0
        .byte   0,0,0

;-------------------------------------------------------------------------------
;
.module ci
;
loadchapter:
        ld      a,(chappic)
        cp      $ff
        jr      z,{+}

        call    showpic

+:      ld      hl,chapterptrs
        ld      a,(chapnum)             ; index into the chapter pointer table
        add     a,a
        add     a,l
        ld      l,a
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a                     ; hl points to start of chapter info block
 
        ld      a,(hl)                  ; snaffle out the bmp index, if there is one
        ld      (chappic),a

        inc     hl                      ; copy out jump indicies
        ld      de,jtab
        ldi
        ldi
        ldi

        ld      (chapter),hl            ; finally make pointer to page start line offsets

        ld      a,(chapnum)
        jp      wadLoad


showpic:
        add     a,$16
        call    wadLoad

        ld      hl,$8032                ; image data pointer
        ld      b,192

-:      push    bc                      ; save loop count

        ld      de,(RASTER_STACK_POST)  ; copy a line of image into first off-screen scanline
        ld      bc,32
        ldir

        call    scrollupone

        pop     bc                      ; loop counter
        djnz    {-}

        jp      waitkey


;-------------------------------------------------------------------------------
;
.module co
;
-:      inc     hl

        call    extcharout

textout:
        ld      a,(hl)
        and     a
        jr      nz,{-}
        ret



centretextout:
        ld      a,(hl)                  ; set Y
        ld      (y),a

        ld      c,0
        ld      d,widths / 256

        inc     hl
        push    hl                      ; stash string pointer for rendering later
        jr      measurestring

-:      ld      e,a                     ; get char width and accumulate it
        ld      a,(de)
        add     a,c
        ld      c,a
        inc     hl

measurestring:
        ld      a,(hl)
        cp      0
        jr      nz,{-}

        dec     c
        srl     c
        ld      a,128
        sub     c
        ld      (x),a

        pop     hl
        jp      textout


extcharout:
        cp      $20
        jr      nz,_notspc

        ld      a,(x)
        add     a,SPC_WIDTH
        ld      (x),a
        ret

_notspc:
        cp      $09
        jr      nz,_nottab

        ld      a,(x)
        add     a,TAB_WIDTH
        ld      (x),a
        ret

_nottab:
        cp      $1a
        jr      nz,_notjmpa

        ld      (jmpA),a

_notjmpa:
        cp      $1c
        jr      nz,_notjmpb

        ld      (jmpB),a

_notjmpb:
        cp      $1e
        jr      nz,_notjmpc

        ld      (jmpC),a

_notjmpc:
        ; falls into charout

; character rendering is a little bit optimised
;
; a different rendering method is used depending on whether the character:
;  * is aligned on a byte boundary
;  * will fit entirely within a byte after shifting
;  * requires a 16 bit window for shifting
;
; byte shift mode
; x % 8 + w <= 8
; ex: x = 5 w = 2
;
; copy mode
; x % 8 = 0
; ex: x = 8 w = 4
;
; word shift mode
; x % 8 + w > 8
; ex: x = 7 w = 6

charout:
        push    hl
 
        ; get character width into c
        ;
        ld      l,a
        ld      h,widths / 256
        ld      c,(hl)

        ld      hl,w
        ld      (hl),c          ; stash width for later
        cp      128             ; if this is an italic character, employ some shonky kerning
        jr      c,{+}

        dec     c               ; kern
        dec     c
        ld      (hl),c
        inc     c
        inc     c

        ; calculate glyph data address
        ;
+:      cp      128
        jr      c,{+}
        sub     15
+:      sub     15
        ld      h,0             ; hl = a * 10 + font base
        ld      l,a
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,hl
        add     hl,de
        add     hl,hl
        ld      de,font
        add     hl,de

        ; calculate screen line offset
        ;
slocalc = $+1
        call    slocalcy

        ; calculate glyph pixel offset
        ;
        ld      a,(x)
        and     7
        ld      b,a             ; b <- screen pixel offset

        ; calculate screen byte offset
        ;
        ld      a,(x)
        and     $f8
        rrca
        rrca
        rrca
        add     a,e
        ld      e,a
        jr      nc,{+}
        inc     d
+:
        ; determine which glyph renderer to use

        ; if pixel offset is 0 then it's super easy
        ;
        ld      a,b
        and     a
        jr      z,bytealigned

        ; if pixel offset + char width < 8 then rotated bits will fit in a byte
        ;
        add     a,c             ; c = char width
        ld      c,b             ; c <- pixel offset / aka shift count
        cp      8
        jr      c,byteshift        

        ; otherwise we need a word to get lost in

;-------------------------------------------------------------------------------
;
.module ws
;
wordshift:
        ld      b,10
        jr      _stw

_advance:
        inc     hl
        ld      a,e
        add     a,31
        ld      e,a
        jr      nc,_stw

        inc     d

_stw:   push    hl
        push    bc
        ld      a,(hl)
        ld      b,c
        ld      l,0

_shift: srl     a
        rr      l
        djnz    _shift

        ld      b,a
        ld      a,(de)
        or      b
        ld      (de),a
        inc     de
        ld      a,(de)
        or      l
        ld      (de),a

        pop     bc
        pop     hl
        djnz    _advance

        jr      updatex

slocalcy:
        push    hl
        ld      a,(y)
        add     a,a
        add     a,linestarts & 255
        ld      l,a
        ld      h,linestarts / 256
        ld      a,(hl)
        inc     hl
        ld      d,(hl)
        ld      e,a
        pop     hl
        ret

slocalcraster:
        ld      de,(RASTER_STACK_POST)
        ret

;-------------------------------------------------------------------------------
;
.module bs
;
byteshift:
        ld      b,10
        jr      _stb

_advance:
        inc     hl
        ld      a,e
        add     a,32
        ld      e,a
        jr      nc,_stb

        inc     d

_stb:   push    bc
        ld      a,(hl)
        ld      b,c

_shift: rrca
        djnz    _shift

        ld      b,a
        ld      a,(de)
        or      b
        ld      (de),a

        pop     bc
        djnz    _advance

        jr      updatex

;-------------------------------------------------------------------------------
;
.module ba
;
bytealigned:
        ld      b,10
        jr      _stb

_advance:
        ld      a,e
        add     a,32
        ld      e,a
        jr      nc,_stb

        inc     d

_stb:   ld      c,(hl)
        ld      a,(de)
        or      c
        ld      (de),a
        inc     hl

        djnz    _advance


updatex:
        ld      a,(x)           ; update cursor x
        ld      c,a
        ld      a,(w)
        add     a,c
        inc     a
        ld      (x),a

        pop     hl
        ret


x:      .byte   0
y:      .byte   0
w:      .byte   0


;-------------------------------------------------------------------------------
;
.module wad
;
initwad:
        ld      de,wadfile      ; send filename
        call    $1ffa

        ld      bc,$8007        ; open read
        ld      a,$00
        out     (c),a
        jp      $1ff6           ; wait/get response


wadLoad:
        ld      h,0             ; a * 3 bytes / entry
        ld      l,a
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,de
        ld      de,wadptrs
        add     hl,de
        xor     a
        ld      (PRTBUF),a
        ld      (PRTBUF+3),a
        ld      de,PRTBUF+1
        ldi
        ldi
        ld      a,(hl)          ; length in 256 byte blocks
        or      $80             ; high byte of last address
        ld      (w),a

        ld      de,PRTBUF
        ld      l,4             ; transfer seek position dword
        ld      a,l
        call    $1ffc

        ld      bc,$8007        ; dword seek
        ld      a,$d0
        out     (c),a
        call    $1ff6           ; wait/get response

        ld      de,$8000        ; read 8k to $8000, nasty but oh well
-:      push    de

        ld      bc,$A007        ; file read, 256 bytes
        xor     a
        out     (c),a
        call    $1ff6           ; wait/get response

        pop     de              ; xfer
        push    de
        xor     a
        ld      l,a
        call    $1ffc

        pop     de
        inc     d
        ld      a,(w)           ; loaded enough?
        cp      d
        jr      nz,{-}

        ret

;-------------------------------------------------------------------------------
;
.module misc
;
scrollup:
        ld      b,12
-:      call    scrollupone
        djnz    {-}
        ret


scrollupone:
        push    hl
        push    de
        push    bc

        ld      hl,(RASTER_STACK)       ; cache the first on-screen scanline pointer
        push    hl

        call    WAIT_SCREEN             ; scroll the stack up one scanline
        ld      hl,RASTER_STACK+2
        ld      de,RASTER_STACK
        ld      bc,(192+12-1)*2
        ldir

        pop     hl                      ; recover saved scanline pointer
        ld      (RASTER_STACK_END-2),hl ; store it as last off-screen scanline pointer

        pop     bc
        pop     de
        pop     hl
        ret


clearosr:
        push    hl
        push    de
        push    bc
        ld      de,(RASTER_STACK_POST)
        ld      h,d
        ld      l,e
        ld      (hl),0
        inc     de
        ld      bc,32*12-1
        ldir
        pop     bc
        pop     de
        pop     hl
        ret

cls:
        push    af
        xor     a
        ld      (x),a
        ld      (y),a
        ld	hl,screen
	ld      de,screen+1
	ld      bc,32*(192+12)
	ld      (hl),a
	ldir
        pop     af
        ret


gamestep:
        call    WAIT_SCREEN
        jp      readinput



waitkey:
        call    gamestep
        ld      a,(select)
        cp      1
        ret     z
        ld      a,(down)
        cp      1
        jr      nz,waitkey
        ret



waitkeytimeout:
        xor     a
        jr      {+}

-:      call    gamestep
        ld      a,(select)
        cp      1
        ret     z                       ; zero set, carry clear
        ld      a,(down)
        cp      1
        ret     z                       ; zero set, carry clear
        ld      a,(_timeout)
+:      inc     a
        ld      (_timeout),a
        jr      nz,{-}
        ret                             ; ret with carry set

_timeout:
        .byte   0

;-------------------------------------------------------------------------------

PE: ; program end

        .include        StackWRX.asm


;-------------------------------------------------------------------------------

titletext1:
        .byte   5, "In Nihilum Reverteris",0
titletext2:
        .byte   8, "An Interactive Novel",0
titletext3:
        .byte   10, "By Yerzmyey",0
titletext4:
        .byte   12, "H-Prg 2018",0
titletext5:
        .byte   16, "Press New Line",0

font:
        .incbin textgamefont.bin
        .incbin textgamefont-i.bin

wadfile:
        .byte   $2e,$33,$37,$1b,$3c,$26,$29+$80     ; INR.WAD

wadptrs:
    .include "codegen/wad.asm"

;-------------------------------------------------------------------------------

        .include "input.asm"

;-------------------------------------------------------------------------------

        .include "stcplay.asm"

berlin:
        .incbin "stc/berlin.stc"

soundEn:
        .byte   $ff

;-------------------------------------------------------------------------------

scrbase:
        .word   screen
        .byte   076H                    ; N/L
line1end:

;-------------------------------------------------------------------------------

line10:
        .byte   0,10
        .word   line10end-$-2
        .byte   $F9,$D4,$C5,$0B         ; RAND USR VAL "
        .byte   $1D,$22,$21,$1D,$20	; 16514 
        .byte   $0B                     ; "
        .byte   076H                    ; N/L
line10end:

;-------------------------------------------------------------------------------

dfile:
        .byte   076H
        .byte   076H,076H,076H,076H,076H,076H,076H,076H
        .byte   076H,076H,076H,076H,076H,076H,076H,076H
        .byte   076H,076H,076H,076H,076H,076H,076H,076H

;-------------------------------------------------------------------------------

var:    .byte   080H
last:

        .end