; TASM-compatible segment structure

.model small

.stack 100h

mydata SEGMENT
    src_box_num db 0    ; temp storage for source box number
    dst_box_num db 0    ; temp storage for destination box number

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
    input_text db 'Enter source Jar number:            $'
    input_text2 db 'Enter destination Jar number:       $'
    blank_line db '                                        $'

    ; Game state arrays - each box holds 4 colored blocks
    ; Index 0 = bottom block, Index 3 = top block
    ; Value: 0 = black/empty, 1 = green, 2 = red
    box1 db 2, 4, 2, 4      ; LEFT box: green, red, green, red (bottom to top)
    box2 db 2, 4, 2, 4      ; MIDDLE box: green, red, green, red (bottom to top)
    box3 db 0, 0, 0, 0      ; RIGHT box: empty (destination for moves)
    
    ; Top block index for each box (tracks which index holds the topmost block)
    ; -1 = empty box, 0-3 = index of topmost block
    box1_top db 3           ; box1 starts full (top at index 3)
    box2_top db 3           ; box2 starts full (top at index 3)
    box3_top db -1          ; box3 starts empty

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

    ; Fill LEFT rectangle: index 0 (bottom) at y=141, index 3 (top) at y=51
    mov cx, 11
    mov dx, 141      ; index 0 bottom
    mov bl, 2
    call fill_quarter_rectangle
    mov cx, 11
    mov dx, 111      ; index 1
    mov bl, 4
    call fill_quarter_rectangle
    mov cx, 11
    mov dx, 81       ; index 2
    mov bl, 2
    call fill_quarter_rectangle
    mov cx, 11
    mov dx, 51       ; index 3 top
    mov bl, 4
    call fill_quarter_rectangle

    ; Fill MIDDLE rectangle: index 0 (bottom) at y=141, index 3 (top) at y=51
    mov cx, 71
    mov dx, 141      ; index 0 bottom
    mov bl, 2
    call fill_quarter_rectangle
    mov cx, 71
    mov dx, 111      ; index 1
    mov bl, 4
    call fill_quarter_rectangle
    mov cx, 71
    mov dx, 81       ; index 2
    mov bl, 2
    call fill_quarter_rectangle
    mov cx, 71
    mov dx, 51       ; index 3 top
    mov bl, 4
    call fill_quarter_rectangle

    ; Loop 10 times to get user input for moves
    mov cx, 10          ; loop counter for 10 moves
    mov si, 0           ; move counter (for display)

game_loop:
    ; Erase row 1 leftover from previous move, then show source prompt on row 0
    mov dh, 1
    mov dx, offset blank_line
    call clear_row_and_print_prompt

    mov dh, 0
    mov dx, offset input_text
    call clear_row_and_print_prompt

    ; Get source box number (1, 2, or 3)
    mov ah, 1h
    int 21h
    sub al, '0'         ; convert ASCII to number
    mov bl, al          ; bl = source box number
    mov [src_box_num], bl   ; Save source box number in memory

    ; Show destination prompt on row 1
    mov dh, 1
    mov dx, offset input_text2
    call clear_row_and_print_prompt

    ; Get destination box number (1, 2, or 3)
    mov ah, 1h
    int 21h
    sub al, '0'         ; convert ASCII to number
    mov bh, al          ; bh = destination box number

    mov [dst_box_num], bh   ; Save destination box number BEFORE get_source_color corrupts bh

    ; Save the loop counter before calling procedures that modify cx/cl
    push cx

    ; Get the source color and update the arrays
    call get_source_color  ; returns: al = color, cl = old top index
    mov dl, al          ; dl = source color (save it)
    mov bl, [src_box_num]   ; Restore source box number for fill_top_block_black

    ; Fill the top source block with black
    call fill_top_block_black  ; bl = source box number, cl = old top index

    ; Place the color at the destination
    mov bl, [dst_box_num]   ; Restore destination box number from memory
    mov al, dl          ; al = color to place
    call put_destination_color  ; bl = destination box number, al = color to place

    ; Restore the loop counter and continue looping
    pop cx
    dec cx              ; loop instruction replaced with near jump (loop body > 127 bytes)
    jz game_loop_done
    jmp game_loop
game_loop_done:

    ; Switch back to text mode before exiting
    mov ax, 3h
    int 10h

    ; Exit to DOS
    mov ax, 4c00h
    int 21h

; -------- PRINT PROMPT ON ROW --------
; Input: dh = row number, dx = offset of prompt string
; Clears the row first, then prints the prompt at col 0
PUBLIC clear_row_and_print_prompt
clear_row_and_print_prompt proc near
    push ax
    push bx
    push cx
    push dx
    push si

    mov si, dx          ; save prompt address (dx needed for cursor call)

    ; Position cursor at col 0 of requested row
    mov ah, 02h
    mov bh, 0
    mov dl, 0
    int 10h

    ; Print blank line to erase old content
    mov dx, offset blank_line
    mov ah, 9h
    int 21h

    ; Reposition cursor at col 0 of same row
    mov ah, 02h
    mov bh, 0
    mov dl, 0
    int 10h

    ; Print the prompt
    mov dx, si
    mov ah, 9h
    int 21h

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
clear_row_and_print_prompt endp

; -------- DRAW RECTANGLE --------
; Input: cx = start_x (left edge), dx = start_y (bottom edge)
; Draws a hollow rectangle outline: 41 pixels wide x 120 pixels tall
; Uses INT 10h AH=0Ch to write pixels in VGA mode 13h
PUBLIC draw_rectangle
draw_rectangle proc near
    ; Save all registers we'll use
    push cx
    push dx
    push bx
    push ax
    push si
    push di

    ; Store starting position in di and si (preserved throughout procedure)
    ; di = x coordinate (left edge), si = y coordinate (bottom edge)
    mov di, cx
    mov si, dx

    ; Set up video interrupt parameters (same for all sides)
    mov al, 13      ; color: light cyan
    mov ah, 0Ch     ; INT 10h function: write pixel in graphics mode
    mov bh, 0       ; video page 0

; -------- DRAW TOP HORIZONTAL LINE --------
    mov cx, di      ; cx = x coordinate, start at left edge
    mov dx, si      ; dx = y coordinate, at bottom of rectangle
    mov bl, 41      ; bl = pixel counter (rectangle is 41 pixels wide)
top_loop:
    int 10h         ; write pixel at (cx, dx)
    inc cx          ; move right to next pixel
    dec bl          ; decrement remaining pixels
    jnz top_loop    ; repeat until 41 pixels drawn

; -------- DRAW LEFT VERTICAL LINE --------
    mov cx, di      ; cx = x coordinate, back at left edge
    mov dx, si      ; dx = y coordinate, back at bottom
    mov bl, 122     ; bl = pixel counter (rectangle is 122 pixels tall)
left_loop:
    int 10h         ; write pixel at (cx, dx)
    inc dx          ; move up to next pixel
    dec bl          ; decrement remaining pixels
    jnz left_loop   ; repeat until 120 pixels drawn

; -------- DRAW RIGHT VERTICAL LINE --------
    mov cx, di      ; cx = x coordinate, reset to left edge
    add cx, 41      ; cx = right edge (left + 41 pixels wide)
    mov dx, si      ; dx = y coordinate, back at bottom
    mov bl, 122     ; bl = pixel counter (rectangle is 122 pixels tall)
right_loop:
    int 10h         ; write pixel at (cx, dx)
    inc dx          ; move up to next pixel
    dec bl          ; decrement remaining pixels
    jnz right_loop  ; repeat until 120 pixels drawn

; -------- DRAW BOTTOM HORIZONTAL LINE --------
    mov cx, di      ; cx = x coordinate, back at left edge
    mov dx, si      ; dx = y coordinate, reset to bottom
    add dx, 122     ; dx = bottom edge (top + 122 pixels tall)
    mov bl, 41      ; bl = pixel counter (rectangle is 41 pixels wide)
bottom_loop:
    int 10h         ; write pixel at (cx, dx)
    inc cx          ; move right to next pixel
    dec bl          ; decrement remaining pixels
    jnz bottom_loop ; repeat until 41 pixels drawn

    ; Restore all registers
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
; Fills a quarter rectangle (41x30 pixels - full width, quarter height)
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
    mov bx, 40       ; 40 pixels wide (inside borders)
    mov bh, 0

fill_quarter_cols:
    int 10h          ; write pixel
    inc cx           ; next pixel
    dec bx           ; decrement pixel counter
    jnz fill_quarter_cols

    inc bp           ; next row
    cmp bp, 30       ; 30 pixels tall (quarter of 120)
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

; -------- REDRAW CONTAINER --------
; Input: cx = x position, dx = y position
; Redraws the container with current array values
PUBLIC redraw_container
redraw_container proc near
    push ax
    push bx
    push cx
    push dx
    
    ; Determine which box to redraw based on cx
    cmp cx, 10
    je redraw_box1_contents
    cmp cx, 70
    je redraw_box2_contents
    cmp cx, 130
    je redraw_box3_contents
    jmp redraw_done
    
redraw_box1_contents:
    lea bx, box1
    jmp redraw_contents
    
redraw_box2_contents:
    lea bx, box2
    jmp redraw_contents
    
redraw_box3_contents:
    lea bx, box3
    
redraw_contents:
    ; Redraw all 4 blocks for this container
    mov di, 0           ; block index counter
    
redraw_block_loop:
    mov al, byte ptr [bx + di]  ; get color from array
    
    ; Calculate y position: 50 + (di * 30)
    mov dx, 50
    mov ax, di
    mov cl, 30
    mul cl
    add dx, ax          ; dx = 50 + (di * 30)
    
    ; Set color and redraw
    mov bl, al          ; bl = color
    call fill_quarter_rectangle
    
    inc di
    cmp di, 4
    jl redraw_block_loop
    
redraw_done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret
redraw_container endp

; -------- GET SOURCE COLOR --------
; Input: bl = source box number (1, 2, or 3)
; Output: al = color at top, cl = old top index
; Updates: array by clearing top block, decrements top index
PUBLIC get_source_color
get_source_color proc near
    push dx
    push si
    
    ; Get the address of the top index variable and box array
    cmp bl, 1
    je src_box1
    cmp bl, 2
    je src_box2
    ; else source is box 3
    lea si, box3_top
    lea dx, box3
    jmp src_get_color
    
src_box1:
    lea si, box1_top
    lea dx, box1
    jmp src_get_color
    
src_box2:
    lea si, box2_top
    lea dx, box2
    
src_get_color:
    ; si points to top index variable, dx points to box array
    mov cl, byte ptr [si]   ; cl = top index (0-3)
    mov bx, dx              ; bx = box array base address
    xor ax, ax              ; ax = 0
    mov al, cl              ; ax = index (zero-extend cl)
    add bx, ax              ; bx = box array + index
    mov al, byte ptr [bx]   ; al = color at that index
    
    ; Clear the top block (set to 0/black)
    mov byte ptr [bx], 0
    
    ; Decrement the top index
    dec byte ptr [si]
    
    pop si
    pop dx
    ret
get_source_color endp

; -------- FILL TOP BLOCK BLACK --------
; Input: bl = source box number (1, 2, or 3), cl = old top index
; Fills the top block position with black color
PUBLIC fill_top_block_black
fill_top_block_black proc near
    push ax
    push bx
    push cx
    push dx
    push di

    ; Save old top index and source box number before overwriting registers
    mov al, cl          ; al = old top index
    mov ah, bl          ; ah = source box number

    ; Determine x position into di (not cx, to avoid wiping al)
    cmp ah, 1
    je ftb_box1
    cmp ah, 2
    je ftb_box2
    mov di, 131
    jmp ftb_calc_y
ftb_box1:
    mov di, 11
    jmp ftb_calc_y
ftb_box2:
    mov di, 71

ftb_calc_y:
    ; Calculate y = 140 - old_top_index * 30  (index 3=y50 top, index 0=y140 bottom)
    xor ah, ah          ; ax = old_top_index
    mov bx, 30
    mul bx              ; ax = old_top_index * 30
    mov dx, 141
    sub dx, ax          ; dx = 141 - (old_top_index * 30)

    mov cx, di          ; cx = x
    mov bl, 0           ; bl = black
    call fill_quarter_rectangle

    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
fill_top_block_black endp

; -------- PUT DESTINATION COLOR --------
; Input: bl = destination box number (1, 2, or 3), al = color to place
; Updates: array by placing color at next position, increments top index
; Draws: the new block with the placed color
PUBLIC put_destination_color
put_destination_color proc near
    push ax
    push bx
    push cx
    push dx
    push si

    ; bl = box number (input), al = color (input)
    ; Save both before any lea/mov destroys them
    mov ah, bl          ; ah = destination box number
    mov ch, al          ; ch = color to place

    ; Get the address of the top index variable and box array based on box number in ah
    cmp ah, 1
    je dst_box1
    cmp ah, 2
    je dst_box2
    ; else destination is box 3
    lea si, box3_top
    lea bx, box3
    jmp dst_put_color
dst_box1:
    lea si, box1_top
    lea bx, box1
    jmp dst_put_color
dst_box2:
    lea si, box2_top
    lea bx, box2

dst_put_color:
    ; si = top index variable, bx = box array base
    mov cl, byte ptr [si]   ; cl = current top index
    inc cl                  ; cl = new top position
    mov byte ptr [si], cl   ; update the top index

    ; Place the color at the new position: array[cl] = color
    ; Determine x into di HERE, before xor ax,ax wipes ah
    cmp ah, 1
    je dst_x_box1
    cmp ah, 2
    je dst_x_box2
    mov di, 131
    jmp dst_do_array
dst_x_box1:
    mov di, 11
    jmp dst_do_array
dst_x_box2:
    mov di, 71

dst_do_array:
    xor ax, ax
    mov al, cl
    add bx, ax              ; bx = box array + new index
    mov byte ptr [bx], ch   ; store color (ch) into array

dst_calc_y:
    ; Calculate y = 140 - cl * 30
    xor ax, ax
    mov al, cl
    mov dl, 30
    mul dl                  ; ax = cl * 30
    mov dx, 141
    sub dx, ax              ; dx = 141 - (cl * 30)

dst_draw_block:
    mov bl, ch              ; bl = color
    mov cx, di              ; cx = x position
    call fill_quarter_rectangle

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
put_destination_color endp


mycode ENDS
end start

