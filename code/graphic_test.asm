; TASM-compatible segment structure

; TASM-compatible segment structure

.model small

.stack 100h

mydata SEGMENT

    temp_word dw 0
    x_coordinate dw 10
    y_coordinate dw 50
    color dw 13
    pixel dw 120
    pixel_r dw 120
    x_coordinate_top dw 10
    y_coordinate_top dw 50
    color_top dw 13
    pixel_top db 41
    x_coordinate_line dw 10
    y_coordinate_line dw 170
    color_line dw 13
    pixel_line db 41
mydata ENDS

mycode SEGMENT
ASSUME CS:mycode, DS:mydata
PUBLIC start
start:
    mov ax, mydata
    mov ds, ax

    ; graphics mode
    mov ax, 13h
    int 10h

    ; Draw three rectangles
    mov cx, 10
    mov dx, 50
    call draw_rectangle

    mov cx, 70
    mov dx, 50
    call draw_rectangle

    mov cx, 130
    mov dx, 50
    call draw_rectangle

    ; Fill LEFT rectangle (leftmost) with alternating green and red blocks
    mov cx, 10       ; bottom-left x
    mov dx, 50       ; bottom-left y
    mov bl, 2        ; green color
    call fill_quarter_rectangle
    
    mov cx, 10       ; bottom-left x
    mov dx, 110      ; move up to next block
    mov bl, 4        ; red color
    call fill_quarter_rectangle
    
    mov cx, 30       ; move right to next block
    mov dx, 50       ; bottom-left y
    mov bl, 4        ; red color
    call fill_quarter_rectangle
    
    mov cx, 30       ; move right
    mov dx, 110      ; move up to next block
    mov bl, 2        ; green color
    call fill_quarter_rectangle

    ; Fill MIDDLE rectangle with alternating green and red blocks
    mov cx, 70       ; bottom-left x
    mov dx, 50       ; bottom-left y
    mov bl, 2        ; green color
    call fill_quarter_rectangle
    
    mov cx, 70       ; bottom-left x
    mov dx, 110      ; move up to next block
    mov bl, 4        ; red color
    call fill_quarter_rectangle
    
    mov cx, 90       ; move right to next block
    mov dx, 50       ; bottom-left y
    mov bl, 4        ; red color
    call fill_quarter_rectangle
    
    mov cx, 90       ; move right
    mov dx, 110      ; move up to next block
    mov bl, 2        ; green color
    call fill_quarter_rectangle

    ; Draw green square at bottom of RIGHTMOST rectangle
    mov cx, 135      
    mov dx, 140      
    mov bl, 2       
    call draw_filled_square

    ; Wait for keypress then exit
    mov ah, 0
    int 16h
    mov ax, 4c00h
    int 21h

; -------- DRAW RECTANGLE --------
; Input: cx = start_x, dx = start_y
PUBLIC draw_rectangle
draw_rectangle proc near
    push cx
    push dx
    push bx
    push ax
    push si
    push di

    mov di, cx
    mov si, dx

    mov al, 13
    mov ah, 0Ch
    mov bh, 0

; TOP
    mov cx, di
    mov dx, si
    mov bl, 41
top_loop:
    int 10h
    inc cx
    dec bl
    jnz top_loop

; LEFT
    mov cx, di
    mov dx, si
    mov bl, 120
left_loop:
    int 10h
    inc dx
    dec bl
    jnz left_loop

; RIGHT
    mov cx, di
    add cx, 41
    mov dx, si
    mov bl, 120
right_loop:
    int 10h
    inc dx
    dec bl
    jnz right_loop

; BOTTOM
    mov cx, di
    mov dx, si
    add dx, 120
    mov bl, 41
bottom_loop:
    int 10h
    inc cx
    dec bl
    jnz bottom_loop

    pop di
    pop si
    pop ax
    pop bx
    pop dx
    pop cx
    ret
draw_rectangle endp

; -------- FILL QUARTER RECTANGLE --------
; Input: cx = bottom-left x, dx = bottom-left y, bl = color
; Fills a quarter rectangle (20x60 pixels)
PUBLIC fill_quarter_rectangle
fill_quarter_rectangle proc near
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp

    mov di, cx       ; di = x coordinate
    mov si, dx       ; si = y coordinate
    mov al, bl       ; al = color
    mov ah, 0Ch      ; video interrupt for pixel writing
    mov bh, 0        ; video page 0
    mov bp, 0        ; row counter

fill_quarter_rows:
    mov dx, si       ; dx = y coordinate
    add dx, bp       ; add row offset

    mov cx, di       ; cx = x coordinate
    mov bx, 20       ; 20 pixels wide (quarter of 41)
    mov bh, 0

fill_quarter_cols:
    int 10h          ; write pixel
    inc cx           ; next pixel
    dec bx           ; decrement pixel counter
    jnz fill_quarter_cols

    inc bp           ; next row
    cmp bp, 60       ; 60 pixels tall (quarter of 120)
    jl fill_quarter_rows

    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
fill_quarter_rectangle endp

; -------- DRAW FILLED SQUARE (green) --------

PUBLIC draw_filled_square
draw_filled_square proc near
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp

    mov di, cx       
    mov si, dx       
    mov al, bl       
    mov ah, 0Ch      
    mov bh, 0      
    mov bp, 0        

fill_rows:
    mov dx, si       
    add dx, bp       

    mov cx, di      
    mov bx, 30       
    mov bh, 0

fill_cols:
    int 10h          
    inc cx           
    dec bx           
    jnz fill_cols

    inc bp           ; next row
    cmp bp, 30
    jl fill_rows

    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
draw_filled_square endp


mycode ENDS
end start


