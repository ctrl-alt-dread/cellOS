format binary as 'bin'
org 0x7C00
jmp short boot_entry
nop
; pad out to 62 bytes this is a one shot wonder fix
times 62-($-$$) db 0
boot_entry:
    jmp 0x0000:init_cs
init_cs:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    mov [driveno], dl
    ; try the gspot first
    mov ah, 0x41
    mov bx, 0x55AA
    mov dl, [driveno]
    int 0x13
    jc oldschool
    cmp bx, 0xAA55
    jne oldschool
    mov si, dap
    mov dl, [driveno]
    mov ah, 0x42
    int 0x13
    jnc nice
    mov ah, 0x0E
    mov al, 'X'
    int 0x10
    jmp oldschool
; linear sector 1 (0-based) through sector 17 = fuck me
oldschool:
    ; needed a fix so i made sure espanol = 0
    xor ax, ax
    mov es, ax
    mov ah, 0x02
    mov al, 17 ; read 17 sectors
    mov ch, 0 ; shaft 0
    mov cl, 2 ; start at sector 2 (sector 1e bootloader)
    mov dh, 0 ; give-head 0
    mov bx, kmain
    mov dl, [driveno]
    int 0x13
    jc ohshit
    ; sectors 18-35 = fuck me
    mov ah, 0x02
    mov al, 18
    mov ch, 0
    mov cl, 1 ; shaft 1
    mov dh, 1 ; give-head 1
    mov bx, kmain + (17 * 512)
    mov dl, [driveno]
    int 0x13
    jc ohshit
    ; fuck me
    mov ah, 0x02
    mov al, 18
    mov ch, 1 ; shaft 1
    mov cl, 1
    mov dh, 0
    mov bx, kmain + (35 * 512)
    mov dl, [driveno]
    int 0x13
    jc ohshit
    ; sectors 54-63 = fuck me
    mov ah, 0x02
    mov al, 10
    mov ch, 1
    mov cl, 1
    mov dh, 1
    mov bx, kmain + (53 * 512)
    mov dl, [driveno]
    int 0x13
    jc ohshit
nice:
    xor ax, ax
    mov ds, ax
    mov es, ax
    jmp kmain
ohshit1: mov al, '1'
    jmp printerr
ohshit2: mov al, '2'
    jmp printerr
ohshit3: mov al, '3'
    jmp printerr
ohshit4: mov al, '4'
    jmp printerr
ohshit: mov al, '?'
printerr:
    mov bl, al
    mov ah, 0x0E
    mov al, 'E'
    int 0x10
    mov al, bl
    int 0x10
    jmp $
driveno: db 0
         db 0 ; padding bc alignment ok?
dap:
    db 0x10
    db 0
    dw 63
    dw kmain
    dw 0x0000
    dq 1
times 510-($-$$) db 0
dw 0xAA55
kmain:
    ; here we goooo
    mov ax, 0x0003
    int 0x10
    ; hide the cursor bc it looks nicer
    mov ah, 0x01
    mov cx, 0x0607
    int 0x10
    ; record boot ticks for uptime (cool)
    mov ax, [0x046C]
    mov word [boottick], ax
    mov ax, [0x046E]
    mov word [boottick+2], ax
    ; 16 slots, 66 bytes each
    mov di, kittyfiles
    mov cx, 16
    xor al, al
.zloop:
    mov [di], al
    add di, 66
    loop .zloop
    ; slot 0
    mov di, kittyfiles
    mov byte [di], 1                  ; used flag
    inc di
    mov si, fortexname
.copyname:
    lodsb
    mov [di], al
    inc di
    or al, al
    jnz .copyname

    ; size field (offset +16)
    mov di, kittyfiles
    add di, 16
    mov ax, fortexlen
    mov [di], ax

    ; copy content into kittydata slot 0 (0x1000)
    mov ax, kittydata
    mov es, ax
    xor di, di
    mov si, fortexdata
    mov cx, fortexlen
    rep movsb
    xor ax, ax
    mov es, ax

    call topbar
    mov ah, 0x02
    mov bh, 0
    mov dh, 2
    mov dl, 0
    int 0x10
    call banner
shell:
    ; grab tick count so we know when to put the fucking thing up
    mov ax, [0x046C]
    mov word [idletick], ax
    mov ax, [0x046E]
    mov word [idletick+2], ax
    call prompt
    mov di, cmdbuf
    call readline
    mov si, cmdbuf
    ; see what they typed
    mov di, c_ls
    call cmpstart
    jc .ls
    mov di, c_new
    call cmpstart
    jc .new
    mov di, c_edit
    call cmpstart
    jc .edit
        mov di, c_cat
        call cmpstart
        jc .cat
    mov di, c_del
    call cmpstart
    jc .del
    mov di, c_help
    call cmpstart
    jc .help
    mov di, c_clear ; i like to eat ass by the way
    call cmpstart
    jc .clear
    mov di, c_rename
    call cmpstart
    jc .rename
    mov di, c_snake
    call cmpstart
    jc .snake
    mov di, c_saver
    call cmpstart
    jc .saver
    ; nothing matched. if the line's empty just loop, otherwise fuck you
    mov si, cmdbuf
    cmp byte [si], 0
    je shell
    mov si, msg_huh
    call errprint
    jmp shell
.ls:
    call lskitty
    jmp shell
.new:
    call mkitty
    jmp shell
.edit:
    call editkitty
    jmp shell
.cat:
    call catkitty
    jmp shell
.del:
    call rmkitty
    jmp shell
.help:
    mov si, msg_help
    call infoprint
    jmp shell
.clear:
    mov ax, 0x0003
    int 0x10
    call topbar
    mov ah, 0x02
    mov bh, 0
    mov dh, 2
    mov dl, 0
    int 0x10
    jmp shell
.rename:
    call mvkitty
                jmp shell
.snake:
    call snek
    jmp resetscreen
.saver:
    call heartbounce
    jmp shell
resetscreen:
    ; after snake we gotta put everything back
    mov ax, 0x0003
    int 0x10
    call topbar
    mov ah, 0x02
    mov bh, 0
    mov dh, 2
    mov dl, 0
    int 0x10
    jmp shell
cls:
    ; peak
    push es
    push ax
    push cx
    push di
    mov ax, 0xB800
    mov es, ax
    xor di, di
    mov ax, 0x0720
    mov cx, 2000
    rep stosw
    mov ah, 0x02
    mov bh, 0
    xor dx, dx
    int 0x10
    pop di
    pop cx
    pop ax
    pop es
    ret
; reads a line but also watches for the user going afk
; if they idle too long we start the heart thingy
readline:
    push di
    mov cx, 0
.lp:
    mov ah, 0x01
    int 0x16
    jz .idle
    mov ah, 0x00
    int 0x16
    cmp al, 13
    je .done
    cmp al, 8
    je .bksp
    cmp cx, 63
    jae .lp
    cmp al, 32
    jb .lp
    mov [di], al
    inc di
    inc cx
    mov ah, 0x0E
    mov bh, 0
    mov bl, 15
    int 0x10
    ; scratch balls = reset the afk timer
    push ax
    mov ax, [0x046C]
    mov word [idletick], ax
    mov ax, [0x046E]
    mov word [idletick+2], ax
    pop ax
    jmp .lp
.idle:
    ; refresh topbar ~every sec so uptime ticks
    mov ax, [0x046C]
    sub ax, word [boottick]
    and ax, 0x0F
    jnz .noup
    push cx
    push di
    mov ah, 0x03
    mov bh, 0
    int 0x10
    push dx
    call topbar
    pop dx
    mov ah, 0x02
    mov bh, 0
    int 0x10
    pop di
    pop cx
.noup:
    ; 546 ticks is likeeee 30 sec, i dont care enough to change it
    mov ax, [0x046C]
    sub ax, word [idletick]
    cmp ax, 546
    jb .lp
    push cx
    push di
    call heartbounce
    pop di
    pop cx
    ; redraw what they had already typed
    call crlf
    call prompt
                push cx
                push di
                sub di, cx
                mov si, di
                push cx
.redraw:
    or cx, cx
    jz .rddone
    lodsb
    mov ah, 0x0E
    mov bh, 0
    mov bl, 15
    int 0x10
    dec cx
    jmp .redraw
.rddone:
    pop cx
    pop di
    pop cx
    mov ax, [0x046C]
    mov word [idletick], ax
    jmp .lp
.bksp:
    ; nothing to delete fuck off
    cmp cx, 0
    je .lp
    dec di
    dec cx
    mov ah, 0x0E
    mov bh, 0
    mov bl, 15
    mov al, 8
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 8
    int 0x10
    jmp .lp
.done:
    mov byte [di], 0
    call crlf
    pop di
    ret
; bounce the screensaver thing
heartbounce:
    push ax
    push bx
    push cx
    push dx
    push es
    push di
    ; blanker than an albino baboons asshole
    mov ax, 0xB800
    mov es, ax
    xor di, di
    mov ax, 0x0020
    mov cx, 2000
    rep stosw
    mov word [hx], 40
    mov word [hy], 12
    mov byte [hdx], 1
    mov byte [hdy], 1
    mov byte [hcol], 0x0C
.go:
    mov ax, 0xB800
    mov es, ax
    ; </3
    mov ax, [hy]
    mov bx, 80
    mul bx
    add ax, [hx]
    shl ax, 1
    mov di, ax
    mov ax, 0x0020
    mov [es:di], ax
    mov [es:di+2], ax
    ; step
    mov al, [hdx]
    cbw
    add [hx], ax
    mov al, [hdy]
    cbw
    add [hy], ax
    ; bounce cheeks. its horrid but i refuse to fw it
    cmp word [hx], 0
    jg .c1
    mov word [hx], 0
    neg byte [hdx]
    call nextcolor
.c1:
    cmp word [hx], 78
    jl .c2
    mov word [hx], 78
    neg byte [hdx]
    call nextcolor
.c2:
    cmp word [hy], 0
    jg .c3
    mov word [hy], 0
    neg byte [hdy]
    call nextcolor
.c3:
    cmp word [hy], 24
    jl .draw
    mov word [hy], 24
    neg byte [hdy]
    call nextcolor
.draw:
    mov ax, [hy]
    mov bx, 80
    mul bx
    add ax, [hx]
    shl ax, 1
    mov di, ax
    mov ah, [hcol]
    mov al, '<'
    mov [es:di], ax
    mov al, '3'
    mov [es:di+2], ax
    mov ax, [0x046C]
    add ax, 1
    mov bx, ax
.wait:
    mov ah, 0x01
    int 0x16
    jnz .bye
    mov ax, [0x046C]
    cmp ax, bx
    jb .wait
    jmp .go
.bye:
    ; eat the key so it doesnt show up in the dhell
    mov ah, 0x00
    int 0x16
    mov ax, 0x0003
    int 0x10
    call topbar
    mov ah, 0x02
    mov bh, 0
    mov dh, 2
    mov dl, 0
    int 0x10
    pop di
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    ret
nextcolor:
    ; cycle thru the rainbow palette every bounce
    push bx
    xor bh, bh
    mov bl, [colidx]
    inc bl
    cmp bl, 6
    jb .k
    xor bl, bl
.k:
    mov [colidx], bl
    mov bl, [colors + bx]
    mov [hcol], bl
    pop bx
    ret
; 20x15 starting at col 30 - row 5
snek:
    mov ax, 0x0003
    int 0x10
    mov word [snlen], 3
    mov byte [sndir], 0
    mov byte [snalive], 1
    mov word [snscore], 0
    ; drop at 8,7 heading right or else the snake would randomly spawn up your asscheeks
    mov di, snbody
    mov byte [di+0], 10
    mov byte [di+1], 7
    mov byte [di+2], 9
    mov byte [di+3], 7
    mov byte [di+4], 8
    mov byte [di+5], 7
    call dropapple
    call snekborder
.loop:
    cmp byte [snalive], 0
    je .ded
    call snekrender
    call snekwait
    call snekmove
    jmp .loop
.ded:
    ; womp womp
    mov ah, 0x02
    mov bh, 0
    mov dh, 22
    mov dl, 30
    int 0x10
    mov bl, 0x0C
    mov si, msg_rip
    call colprint
    mov ah, 0x00
    int 0x16
    ret
; rng is just the tick counter masked down - ik its horrid but fuck off
dropapple:
    push ax
    push bx
    push cx
    push si
.retry:
    mov ax, [0x046C]
    and ax, 0x001F
    cmp ax, 20
    jb .xok
    sub ax, 12
.xok:
    mov [applex], al
        ; y coord, shift the tick so its different from x
        mov ax, [0x046C]
        shr ax, 3
        and ax, 0x000F
        cmp ax, 15
        jb .yok
        sub ax, 7
.yok:
    mov [appley], al
    ; dont spawn on top of the snake, that would suck
    mov cx, [snlen]
    mov si, snbody
.chk:
    mov al, [si]
    cmp al, [applex]
    jne .nxt
    mov al, [si+1]
    cmp al, [appley]
    je .retry
.nxt:
    add si, 2
    loop .chk
    pop si
    pop cx
    pop bx
    pop ax
    ret
snekborder:
    push es
    push ax
    push bx
    push cx
    push di
    mov ax, 0xB800
    mov es, ax
    ; top row of the box
    mov di, (4*80 + 29) * 2
    mov ah, 0x0B
    mov al, '+'
    mov [es:di], ax
    add di, 2
    mov al, '-'
    mov cx, 20
.top:
    mov [es:di], ax
    add di, 2
    loop .top
    mov al, '+'
    mov [es:di], ax
    ; your a bottom
    mov di, (20*80 + 29) * 2
    mov al, '+'
    mov [es:di], ax
    add di, 2
    mov al, '-'
    mov cx, 20
.bot:
    mov [es:di], ax
    add di, 2
    loop .bot
    mov al, '+'
    mov [es:di], ax
    ; verts on both sides
    mov cx, 15
    mov bx, 5
.sides:
    push cx
    push bx
    mov ax, bx
    mov cx, 80
    mul cx
    add ax, 29
    shl ax, 1
    mov di, ax
    mov ax, 0x0B7C
    mov [es:di], ax
    add di, 42
    mov [es:di], ax
    pop bx
    pop cx
    inc bx
    loop .sides
    ; slap the title above the box harder then bonnie blues cheeks
    mov di, (2*80 + 30) * 2
    mov si, snektitle
    mov ah, 0x0E
.title:
    lodsb
    or al, al
    jz .done
    mov [es:di], al
    inc di
    mov [es:di], ah
    inc di
    jmp .title
.done:
    pop di
    pop cx
    pop bx
    pop ax
    pop es
    ret
snekrender:
    push es
    push ax
    push bx
    push cx
    push si
    push di
    mov ax, 0xB800
    mov es, ax
    ; clear the shit
    mov cx, 15
    mov bx, 5
.clr:
    push cx
    push bx
    mov ax, bx
    mov cx, 80
    mul cx
    add ax, 30
    shl ax, 1
    mov di, ax
    mov ax, 0x0020
    mov cx, 20
    rep stosw
    pop bx
    pop cx
    inc bx
    loop .clr
    ; paint every segment
    mov cx, [snlen]
    mov si, snbody
.body:
    push cx
    mov al, [si+1]
    xor ah, ah
    add ax, 5
    mov bx, 80
    mul bx
    mov bl, [si]
    xor bh, bh
    add ax, bx
    add ax, 30
    shl ax, 1
    mov di, ax
    mov ax, 0x0A30
    mov [es:di], ax
    add si, 2
    pop cx
    loop .body
    ; and the tasty o
    mov al, [appley]
    xor ah, ah
    add ax, 5
    mov bx, 80
    mul bx
    mov bl, [applex]
    xor bh, bh
    add ax, bx
    add ax, 30
    shl ax, 1
    mov di, ax
    mov ax, 0x0C4F
    mov [es:di], ax
    ; score line below the box
    mov ah, 0x02
    mov bh, 0
    mov dh, 21
    mov dl, 30
    int 0x10
    mov bl, 0x0E
    mov si, msg_score
    call colprint
    mov ax, [snscore]
    call numprint
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    pop es
    ret
; the divmod10 thing, push digits then pop back out of the oviduct
numprint:
    push ax
    push bx
    push cx
    push dx
    mov cx, 0
    mov bx, 10
.div:
    xor dx, dx
    div bx
    push dx
    inc cx
    or ax, ax
    jnz .div
.pop:
    pop dx
    add dl, '0'
    mov ah, 0x0E
    mov al, dl
    mov bh, 0
    mov bl, 0x0E
    int 0x10
    loop .pop
    pop dx
    pop cx
    pop bx
    pop ax
    ret
; the game tick basicaly
snekwait:
    mov ax, [0x046C]
    add ax, 3
    mov bx, ax
.w:
    mov ah, 0x01
    int 0x16
    jz .nope
    mov ah, 0x00
    int 0x16
    cmp ah, 0x48
    je .up
    cmp ah, 0x50
    je .down
    cmp ah, 0x4B
    je .left
    cmp ah, 0x4D
    je .right
    cmp al, 27
    je .esc
    jmp .nope
.up:
    ; cant reverse into yourself you fucking cheat
    cmp byte [sndir], 1
    je .nope
    mov byte [sndir], 3
    jmp .nope
.down:
    cmp byte [sndir], 3
    je .nope
    mov byte [sndir], 1
    jmp .nope
.left:
    cmp byte [sndir], 0
    je .nope
    mov byte [sndir], 2
    jmp .nope
.right:
    cmp byte [sndir], 2
    je .nope
    mov byte [sndir], 0
    jmp .nope
.esc:
    mov byte [snalive], 0
    ret
.nope:
    mov ax, [0x046C]
    cmp ax, bx
    jb .w
    ret
snekmove:
    mov si, snbody
    mov al, [si]
    mov ah, [si+1]
    ; figure out where the fuck the direction of new head goes
    cmp byte [sndir], 0
    jne .n1
    inc al
    jmp .chk
.n1:
    cmp byte [sndir], 1
    jne .n2
    inc ah
    jmp .chk
.n2:
    cmp byte [sndir], 2
    jne .n3
    dec al
    jmp .chk
.n3:
    dec ah
.chk:
    ; 1-800-gam-over if you smack wall
    cmp al, 20
    jae .rip
    cmp ah, 15
    jae .rip
    mov [newx], al
    mov [newy], ah
    ; every segment except tail because
    mov cx, [snlen]
    dec cx
    mov si, snbody
.self:
    or cx, cx
    jz .noself
    mov al, [si]
    cmp al, [newx]
    jne .snxt
    mov al, [si+1]
    cmp al, [newy]
    je .rip
.snxt:
    add si, 2
    dec cx
    jmp .self
.noself:
    ; nom nom?
    mov al, [newx]
    cmp al, [applex]
    jne .nofood
    mov al, [newy]
    cmp al, [appley]
    jne .nofood
                    ; yes! grow and score
                    inc word [snlen]
                    add word [snscore], 10
    ; shift the whole body down by 2 bytes to make room for new head
    mov cx, [snlen]
    dec cx
    shl cx, 1
    mov si, snbody
    add si, cx
    dec si
    mov di, si
    inc di
    inc di
    std
    rep movsb
    cld
    mov al, [newx]
    mov [snbody], al
    mov al, [newy]
    mov [snbody+1], al
    call dropapple
    ret
.nofood:
    ; same shift trick but without growing
    mov cx, [snlen]
    dec cx
    shl cx, 1
    mov si, snbody
    add si, cx
    dec si
    mov di, si
    inc di
    inc di
    std
    rep movsb
    cld
    mov al, [newx]
    mov [snbody], al
    mov al, [newy]
    mov [snbody+1], al
    ret
.rip:
    mov byte [snalive], 0
    ret
; thr little strip at the top of the screen w the os name because i decided it was cool
topbar:
    push es
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    mov ax, 0xB800
    mov es, ax
    xor di, di
    mov ah, 0x5F
    mov al, ' '
    mov cx, 80
.fill:
    mov [es:di], ax
    add di, 2
    loop .fill
    ; left: UP mm:ss
    mov di, 2
    mov ah, 0x5F
    mov al, 'U'
    mov [es:di], ax
    add di, 2
    mov al, 'P'
    mov [es:di], ax
    add di, 2
    mov al, ' '
    mov [es:di], ax
    add di, 2
    mov ax, [0x046C]
    sub ax, word [boottick]
    mov bx, 18
    xor dx, dx
    div bx
    mov bx, 60
    xor dx, dx
    div bx
    cmp ax, 99
    jbe .minok
    mov ax, 99
.minok:
    push dx
    call print2digits
    mov al, ':'
    mov ah, 0x5F
    mov [es:di], ax
    add di, 2
    pop ax
    call print2digits
    ; center
    mov di, (33)*2
    mov si, toptext
    mov ah, 0x5F
.lp:
    lodsb
    or al, al
    jz .txtok
    mov [es:di], al
    inc di
    mov [es:di], ah
    inc di
    jmp .lp
.txtok:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop es
    ret
; ax = 0-99, write 2 digits to es:di with attr 5F, advance di
print2digits:
    push ax
    push bx
    push dx
    xor dx, dx
    mov bx, 10
    div bx
    add al, '0'
    mov ah, 0x5F
    mov [es:di], ax
    add di, 2
    mov al, dl
    add al, '0'
    mov ah, 0x5F
    mov [es:di], ax
    add di, 2
    pop dx
    pop bx
    pop ax
    ret
banner:
    ; each line a diff color... why?, i can
    mov bl, 0x0C
    mov si, bn1
    call colprint
    call crlf
    mov bl, 0x0E
    mov si, bn2
    call colprint
    call crlf
    mov bl, 0x0A
    mov si, bn3
    call colprint
    call crlf
        mov bl, 0x0B
        mov si, bn4
        call colprint
        call crlf
    mov bl, 0x0D
    mov si, bn5
    call colprint
    call crlf
    call crlf
    mov bl, 0x0E
    mov si, bnhint
    call colprint
    call crlf
    call crlf
    ret
; bl = color, si = string. dead fuggin simple
colprint:
    push ax
    push bx
    push cx
    push dx
.lp:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    mov bh, 0
    int 0x10
    jmp .lp
.done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret
prompt:
    push bx
    mov bl, 0x0D
    mov si, promptstr
    call colprint
    pop bx
    ret
okprint:
    ; greeeeeeeeeen
    push bx
    mov bl, 0x0A
    call colprint
    pop bx
    ret
errprint:
    ; red :c
    push bx
    mov bl, 0x0C
    call colprint
    pop bx
    ret
infoprint:
    ; cyan...ish
    push bx
    mov bl, 0x0B
    call colprint
    pop bx
    ret
; rename is a pain in the ass i mostly gave up
; TODO: its held together w fucking duct tape dont even use this command atp
mvkitty:
    call getname
    cmp byte [namebuf], 0
    je .noname
    ; stash the old name somewhere safe
    mov si, namebuf
    mov di, oldname
    mov cx, 16
.cpold:
    lodsb
    stosb
    or al, al
    jz .oldok
    loop .cpold
.oldok:
    ; skip past the first arg in cmdbuf :[
    mov si, cmdbuf
    add si, 7
.skipold:
    cmp byte [si], ' '
    je .gotsp
    cmp byte [si], 0
    je .noname
    inc si
    jmp .skipold
.gotsp:
.skipsp2:
    cmp byte [si], ' '
    jne .parsenew
    inc si
    jmp .skipsp2
.parsenew:
    mov di, namebuf
    call copyname
    cmp byte [namebuf], 0
    je .noname
    ; put old name back into namebuf so findkitty finds the right one
    mov si, oldname
    mov di, namebuf
    mov cx, 16
.tmpcpy:
    lodsb
    stosb
    or al, al
    jz .tmpdn
    loop .tmpcpy
.tmpdn:
    call findkitty
    jnc .nope
    push bx
    mov ax, 66
    mul bx
    mov di, kittyfiles
    add di, ax
    inc di
    ; parse the new name AGAIN fml
    mov si, cmdbuf
    add si, 7
.skipold2:
    cmp byte [si], ' '
    je .gotsp2
    cmp byte [si], 0
    je .errpop
    inc si
    jmp .skipold2
.gotsp2:
.skipsp22:
    cmp byte [si], ' '
    jne .docpnew
    inc si
    jmp .skipsp22
.docpnew:
    push di
    push si
    ; now check the new name isnt already taken with this shit god would dispise
    mov di, newname
    call copyname
    mov si, newname
    mov di, namebuf
    mov cx, 16
.cpnewtmp:
    lodsb
    stosb
    or al, al
    jz .cpnewdn
    loop .cpnewtmp
.cpnewdn:
    call findkitty
    jc .existspop
    pop si
    pop di
    ; wipe old name field then write new one in
    push di
    push si
    mov cx, 15
    xor al, al
.clrname:
    mov [di], al
    inc di
    loop .clrname
    pop si
    pop di
    call copyname
    pop bx
    mov si, msg_renamed
    call okprint
    ret
.errpop:
    pop bx
    mov si, msg_noname
    call errprint
    ret
.existspop:
    pop si
    pop di
    pop bx
    mov si, msg_exists
    call errprint
    ret
.noname:
    mov si, msg_noname
    call errprint
    ret
.nope:
    mov si, msg_nope
    call errprint
    ret
crlf:
    push ax
    push bx
    push cx
    push dx
    push di
    mov ah, 0x0E
    mov bh, 0
    mov bl, 15
    mov al, 13
    int 0x10
    mov al, 10
    int 0x10
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
; check if si starts with di carry like a firefighter if yes
cmpstart:
    push si
    push di
.lp:
    mov al, [di]
    cmp al, 0
    je .yep
    mov ah, [si]
    cmp ah, al
    jne .nah
    inc si
    inc di
    jmp .lp
.yep:
    pop di
    add sp, 2 ; HACK: dont pop si we want it advanced past the match
    stc
    ret
.nah:
    pop di
    pop si
    clc
    ret
copyname:
    mov cx, 15
.lp:
    lodsb
    cmp al, 0
    je .done
    cmp al, ' '
    je .done
    mov [di], al
    inc di
    loop .lp
.done:
    mov byte [di], 0
    ret
; strcmp basically. 0 in ax if equal
samename:
    push si
    push di
.lp:
    mov al, [si]
    mov ah, [di]
    cmp al, ah
    jne .no
    cmp al, 0
    je .yes
    inc si
    inc di
    jmp .lp
.yes:
    pop di
    pop si
    xor ax, ax
    ret
.no:
    pop di
    pop si
    or ax, 1
    ret
; carry set = found, bx = index
findkitty:
    xor bx, bx
.lp:
    cmp bx, 16
    jae .nope
    push bx
    mov ax, 66
    mul bx
    mov di, kittyfiles
    add di, ax
    cmp byte [di], 0
    je .nxt
    inc di
    mov si, namebuf
    call samename
    jne .nxt
    pop bx
    stc
    ret
.nxt:
    pop bx
    inc bx
    jmp .lp
.nope:
    clc
    ret
findfreekitty:
    ; look for the first empty slot
    xor bx, bx
.lp:
    cmp bx, 16
    jae .nope
    mov ax, 66
    mul bx
    mov di, kittyfiles
    add di, ax
    cmp byte [di], 0
    je .yep
    inc bx
    jmp .lp
.yep:
    stc
    ret
.nope:
    clc
    ret
lskitty:
    xor bx, bx
.lp:
    cmp bx, 16
    jae .done
    push bx
    mov ax, 66
    mul bx
    mov di, kittyfiles
    add di, ax
    cmp byte [di], 0
    je .skip
    inc di
    mov si, di
    push bx
    mov bl, 0x0B
    call colprint
    pop bx
    call crlf
.skip:
    pop bx
    inc bx
    jmp .lp
.done:
    ret
; eat spaces then grab a filename outta cmdbuf
getname:
.skipsp:
    cmp byte [si], ' '
    jne .go
    inc si
    jmp .skipsp
.go:
    mov di, namebuf
    call copyname
    ret
mkitty:
    call getname
    cmp byte [namebuf], 0
    je .noname
    call findkitty
    jc .exists
    call findfreekitty
    jnc .full
    ; got a slot, fill it in
    mov ax, 66
    mul bx
    mov di, kittyfiles
    add di, ax
    mov byte [di], 1
    inc di
    mov si, namebuf
.cpy:
    lodsb
    stosb
    or al, al
    jnz .cpy
    ; zero out the size field
    mov ax, 66
    mul bx
    mov di, kittyfiles
    add di, ax
    add di, 16
    mov word [di], 0
    mov si, msg_made
    call okprint
    ret
.noname:
    mov si, msg_noname
    call errprint
    ret
.exists:
    mov si, msg_exists
    call errprint
    ret
.full:
    mov si, msg_full
    call errprint
    ret
; ESC to save, everything else gets typed in
editkitty:
    call getname
    call findkitty
    jnc .nope
    push bx
    mov ax, kittydata
    mov es, ax
    mov ax, 4096
    mul bx
    mov di, ax
    mov si, msg_edit
    call infoprint
    xor cx, cx
.lp:
    mov ah, 0x00
    int 0x16
    cmp al, 27
    je .done
    cmp al, 8
    je .bksp
    cmp cx, 4095
    jae .lp
    cmp al, 13
    jne .store
    ; enter = store as LF
    mov byte [es:di], 10
    inc di
    inc cx
    call crlf
    jmp .lp
.store:
    mov [es:di], al
    inc di
    inc cx
    mov ah, 0x0E
    mov bh, 0
    mov bl, 15
    int 0x10
    jmp .lp
.bksp:
    cmp cx, 0
    je .lp
    dec di
    dec cx
    mov ah, 0x0E
    mov bh, 0
    mov bl, 15
    mov al, 8
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 8
    int 0x10
    jmp .lp
.done:
    xor ax, ax
    mov es, ax
    pop bx
    push cx
    mov ax, 66
    mul bx
    mov di, kittyfiles
    add di, ax
    add di, 16
    pop cx
    mov [di], cx
    call crlf
    mov si, msg_saved
    call okprint
    ret
.nope:
    mov si, msg_nope
    call errprint
    ret
catkitty:
    call getname
    call findkitty
    jnc .nope
    push bx
    mov ax, 66
    mul bx
    mov di, kittyfiles
    add di, ax
    add di, 16
    mov cx, [di]
    pop bx
    mov ax, kittydata
    mov es, ax
    mov ax, 4096
    mul bx
    mov di, ax
.lp:
    cmp cx, 0
    je .done
    mov al, [es:di]
    inc di
    cmp al, 10
    je .nl
    mov ah, 0x0E
    mov bh, 0
    mov bl, 15
    int 0x10
    jmp .nxt
.nl:
    call crlf
.nxt:
    dec cx
    jmp .lp
.done:
    xor ax, ax
    mov es, ax
    call crlf
    ret
.nope:
    mov si, msg_nope
    call errprint
    ret
; no undelete, sorry
rmkitty:
    call getname
    call findkitty
    jnc .nope
    mov ax, 66
    mul bx
    mov di, kittyfiles
    add di, ax
    mov byte [di], 0
    mov si, msg_del
    call okprint
    ret
.nope:
    mov si, msg_nope
    call errprint
    ret
toptext db 'CELLOS <3', 0
bn1 db ' _____ ', 0
bn2 db '| ____|', 0
bn3 db '| |', 0
bn4 db '| |', 0
bn5 db '|_____|', 0
bnhint db ' type "help" to see commands', 0 ; this looks like shit im sorry :(
promptstr db '> ', 0
msg_huh db 'unknown cmd', 13, 10, 0
msg_noname db 'need a name', 13, 10, 0
msg_exists db 'already exists', 13, 10, 0
msg_full db 'fs full', 13, 10, 0
msg_nope db 'not found', 13, 10, 0
msg_made db 'created', 13, 10, 0
msg_edit db 'editing (ESC to save):', 13, 10, 0
msg_saved db 'saved', 13, 10, 0
msg_del db 'deleted', 13, 10, 0
msg_renamed db 'renamed', 13, 10, 0
msg_help db 'cmds: ls, new, edit, cat, del, rename, snake, saver, clear, help', 13, 10, 0
snektitle db 'snake - ESC to quit', 0
msg_score db 'Score: ', 0
msg_rip db 'GAME OVER - press any key', 0
c_ls db 'ls', 0
c_new db 'new ', 0
c_edit db 'edit ', 0
c_cat db 'cat ', 0
c_del db 'del ', 0
c_help db 'help', 0
c_clear db 'clear', 0
c_rename db 'rename ', 0
c_snake db 'snake', 0
c_saver db 'saver', 0
cmdbuf db 64 dup(0)
namebuf db 16 dup(0)
oldname db 16 dup(0)
newname db 16 dup(0)
colors db 0x0C, 0x0E, 0x0A, 0x0B, 0x0D, 0x09
idletick dd 0
boottick dd 0
hx dw 40
hy dw 12
hdx db 1
hdy db 1
hcol db 0x0C
colidx db 0
snlen dw 0
sndir db 0
snalive db 0
snscore dw 0
snbody db 200 dup(0)
applex db 0
appley db 0
newx db 0
newy db 0

; hardcoded fort texas conflict because its interesting
fortexname db 'fortexconflict', 0
fortexdata:
db 'the siege of fort texas (later renamed fort brown) marked the start of major fighting in the mexican-american war. in march 1846 general zachary taylor moved us troops to the disputed rio grande border and ordered construction of an earthen star-shaped fort opposite the mexican town of matamoros. he left about 500 men under major jacob brown to hold it while the main force secured supplies at point isabel.', 10
db 10
db 'on may 3 mexican artillery under general mariano arista opened fire from across the river. the bombardment continued for six days. the fort''s thick dirt walls held up well; only two americans were killed, one of them major brown himself. the defenders returned fire and kept the mexicans from storming the works.', 10
db 10
db 'taylor marched back, defeated arista''s army at the battles of palo alto (may 8) and resaca de la palma (may 9), and the siege ended. the fort was renamed fort brown in honor of the fallen major and remained an active army post for decades.', 0
fortexlen = $ - fortexdata - 1   ; length without the final null

; 1.44mb size because it feels better - if you want it to be 32kib change the number to 32768 like a good boy
times 1474560-($-$$) db 0
kittyfiles = 0x9000
kittydata = 0x1000