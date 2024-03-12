
;=======================================================
section .data

; rdi register is preserved for this shit
; if you want to change it then you will
; need to save it
printing_buffer: times 256 db 0

PRINTING_BUFFER_SIZE equ 256

num_buffer:		times 64 db '0'

NUM_BUFFER_SIZE equ 64

;=======================================================
section .text

STDOUT_FD equ 1

global MyPrintf
;=======================================================
;
; Printf() asm implementation
;
; Entry: 	rdi - format string
;			...
;
; Assumes:	duno
;
; Return:	rax
;
; Destroy: rdi, rsi, rcx,
;=======================================================
MyPrintf:
; Saving rbp
	push rbp

; Creating stack frame
	mov rbp, rsp

	call RememberArgs

; r10 same with rbp, but we shouldnt
; change rbp (r10 points to args in stack)
	mov r10, rbp
	sub r10, 16

; rsi = &format_string
	mov rsi, [rbp - 8]

	xor rax, rax

; Passed args count = 0
	xor rcx, rcx

	mov rdi, printing_buffer

	jmp .Test

.PrintingLoop:
	cmp al, '%'
	jne .NotSpecificator

; If al == '%', we dont get arg from stack
	inc rsi
	mov al, [rsi]
	cmp al, '%'
	je .DontGetArg

	mov rbx, [r10]
; Go to next arg
	sub r10, 8
.DontGetArg:
	push rsi
	call HandleSpecificator
	pop rsi
	inc rsi

	jmp .Test

.NotSpecificator:
	call PushSymbol
	inc rsi

.Test:
	xor rax, rax
	mov al, BYTE [rsi]

; 0 - ASCII code of '\0' - string terminator
	cmp al, 0
	jne .PrintingLoop

	call PrintBuffer

; Ret value
	mov eax, 0

; Leaving func
	mov rsp, rbp
	pop rbp

	ret
;=======================================================
;
; Puts symbol in printing buffer
;
;=======================================================
;
; Entry:	al - symbol
;
; ASSumes:	rdi - pointer to current pos in buffer
;
; Destroy:	rdi
;
;=======================================================
PushSymbol:
	push rdi

	sub rdi, printing_buffer
	cmp rdi, PRINTING_BUFFER_SIZE

	pop rdi
	jb .PutSymbol

	call PrintBuffer

.PutSymbol:
	mov BYTE [rdi], al

	inc rdi
	ret
;=======================================================
;
; Prints buffer in stdout
;
;=======================================================
;
; Entry:	-
;
; ASSumes:	-
;
; Destroy:	rdi, rax
;
;=======================================================
PrintBuffer:
; 1 - write() syscall code
	mov rax, 1

	mov rdi, STDOUT_FD

	mov rsi, printing_buffer

	mov rdx, PRINTING_BUFFER_SIZE

	syscall

	mov rdi, printing_buffer

	ret
;=======================================================
;
; Prints number depending on specificator
;
;=======================================================
;
; Entry:	rbx - number we need to print
;
; ASSumes:	rsi - poiner on '%'
;
; Destroy:	rsi, al, rbx
;
;=======================================================
HandleSpecificator:
	cmp al, '%'
	je .Percent

	cmp al, 'z'
	ja .End

	cmp al, 'a'
	jb .End

	mov r11, HandleSpecificator.jmp_table

	sub al, 'a'

	mov rax, QWORD HandleSpecificator.jmp_table[0+rax*8]

	jmp rax

.jmp_table:	dq .End    ; a
			dq .Binary ; Binary
			dq .Char   ; Char
			dq .Decimal; Decimal
			dq .End	   ; e
			dq .End	   ; f
			dq .End	   ; g
			dq .End	   ; h
			dq .End	   ; i
			dq .End	   ; j
			dq .End	   ; k
			dq .End	   ; l
			dq .End	   ; m
			dq .End	   ; n
			dq .Octal  ; Octal
			dq .End	   ; p
			dq .End	   ; q
			dq .End	   ; r
			dq .String ; String_
			dq .End	   ; t
			dq .End	   ; u
			dq .End	   ; v
			dq .End	   ; w
			dq .Hex	   ; heX
			dq .End	   ; y
			dq .End	   ; z

.Hex:
; Save current rdi
	push rdi

	mov rdi, num_buffer

; Save pos in hex_buffer
	push rdi

	mov dl, 4d
	mov dh, 64d
	mov ch, 60d
	call SetNumBuffer
	pop rdi

	mov rsi, rdi

	pop rdi
	mov rdx, 16
	call WriteNumBuffer

	jmp .End

.Char:
	mov al, bl
	call PushSymbol

	jmp .End

.Percent:
	call PushSymbol

	jmp .End

.String:
	call WriteString

	jmp .End

.Binary:
; Save current rdi
	push rdi

	mov rdi, num_buffer

; Save pos in hex_buffer
	push rdi

	mov dl, 1d
	mov dh, 64d
	mov ch, 63d
	call SetNumBuffer
	pop rdi

	mov rsi, rdi

	pop rdi
	mov rdx, 64
	call WriteNumBuffer

	jmp .End

.Octal:
; Save current rdi
	push rdi

	mov rdi, num_buffer

; Save pos in hex_buffer
	push rdi

	mov dl, 3d
	mov dh, 60d
	mov ch, 60d
	call SetNumBuffer
	pop rdi

	mov rsi, rdi

	pop rdi
	mov rdx, 64
	call WriteNumBuffer

	jmp .End

.Decimal:
; Testing sign bit
	test ebx, 8000h
	je .NotNegativeDecimal

	neg ebx

	mov al, '-'
	call PushSymbol

.NotNegativeDecimal:
	push rdi

	mov rdi, num_buffer

	push rdi
	call SetDecimalBuffer
	pop rdi

	mov rsi, rdi

	pop rdi
	mov rdx, 21

	call WriteNumBuffer

	jmp .End

.End:
	ret
;=========================================================
;
; Writes string in buffer
;
;=========================================================
;
; Enrtry: 	rbx - pointer to a string
;
;=========================================================
WriteString:
	jmp .Test

.Loop:
	call PushSymbol

	inc rbx
.Test:
	mov al, BYTE [rbx]
	cmp al, 0
	jne .Loop

	ret
;=========================================================
;
; Sets decimal buffer with chars
;
;=========================================================
;
; Entry:	rsi - pointer to buffer
;			rdx - size of buffer
;			rbx - number
; Assumes:	-
;
; Destroy:	rsi, rdx
;
; Return:	-
;
;=========================================================
SetDecimalBuffer:
;set buffer from the end
	add rdi, NUM_BUFFER_SIZE

; We will div on 10
	mov rcx, 10
	mov rax, rbx

	jmp .Test

.Loop:
	cmp rax, 10
	jae .Convert

	add rax, '0'

	mov BYTE [rdi], al

	jmp .LoopEnd

.Convert:
	cqo
	div rcx

	add rdx, '0'
	mov [rdi], dl
	dec rdi

.Test:
	push rdi
	sub rdi, num_buffer
	pop rdi
	cmp rdi, 0
	jbe .LoopEnd

	cmp rbx, 0

	jae .Loop
.LoopEnd:

	ret
;=========================================================
;
; Sets the num buffer
;
;=========================================================
;
; Entry:	rbx - number
;			rdi - buffer
;			dl - step
;			dh - number of bits at all
; 			ch - number of bytes to shift to right
;
; Assumes:	-
;
; Destroys:	rdi, rcx
;
; Returns:  -
;
;=========================================================
SetNumBuffer:
	xor cl, cl

.Loop:
; Save rbx to use it again
	push rbx

; Getting 4 bytes and moving them to BL
    shl rbx, cl

	push rcx

	mov cl, ch
    shr rbx, cl

	pop rcx

	mov al, bl

    call ConvertHexNumToChar

	mov [rdi], al
	inc rdi

	pop rbx

    add cl, dl

    cmp cl, dh

    jbe .Loop

    ret

;=========================================================
; Converts hex number in AL to char
;
; Entry:      AL - hex number
;
; Assumes:    AX contains 2 lower bytes
;
; Return:     AL
;
; Destroys:   -
;=========================================================
ConvertHexNumToChar:
    cmp al, 0d
    jb .Exit

    cmp al, 9d
    ja .Isalpha

; if(isdigit(AL)) {AL += '0'}
    add al, 48

    jmp .Exit

.Isalpha:
; isalpha(AL)
    cmp al, 0ah
    jb .Exit

    cmp al, 0fh
    ja .Exit

; if (isalpha(AL)) {AL -= 'A' - 10d}
    add al, 65 - 10

.Exit:
    ret
;=========================================================
;
; Prints number buffer
;
;=========================================================
;
; Entry:	rsi - pointer to buffer
;			rdx - size of buffer
;
; Assumes:	-
;
; Destroy:	rsi, rdx
;
; Return:	-
;
;=========================================================
WriteNumBuffer:

	jmp .SkipingTest
.SkipingLoop:
	inc rsi
	dec rdx

.SkipingTest:
; We need to print atleast 1 simbol
	cmp rdx, 1d
	jbe .SkipingLoopEnd

	cmp BYTE [rsi], '0'
	je .SkipingLoop
.SkipingLoopEnd:

	jmp .PrintingTest
.PrintingLoop:
	mov al, [rsi]
	call PushSymbol

	inc rsi
	dec rdx

.PrintingTest:
	cmp rdx, 0
	ja .PrintingLoop

	ret
;=======================================================
;
; Places args in stack frame
;
;=======================================================
;
; Entry:	 rdi - pointer to a format string
;
; Assumes:   duno (may be i will mind about it)
;
; Destroys:  rdi, r10
;
;=======================================================
RememberArgs:
; To return on the begining position
; This trick will destroy return addres
; of this func that placed in stack.
; But we saved it in r10,
; so we are afraid of nothing
	pop r10

; Save current stack pos for passing stack args
	mov r11, rsp
	add r11, 8

; Push registers to save them in stackframe
	push rdi
	push rsi
	push rdx
	push rcx
	push r8
	push r9

	add rsp, 5 * 8

; rcx - arg counter
	xor rcx, rcx


	jmp .RegPassTest
.RegPassLoop:
	cmp BYTE [rdi], '%'
	jne .RegPassGoNext
	inc rdi

	cmp BYTE [rdi], '%'
	je .RegPassGoNext

	inc rcx

	sub rsp, 8

.RegPassGoNext:
	inc rdi

.RegPassTest:
; 5 - count of args passed through registers
; (first arg must be format string)
	cmp rcx, 5d
	jae .RegPassLoopEnd

	cmp BYTE [rdi], 0
	jne .RegPassLoop
.RegPassLoopEnd:


	jmp .StackPassTest
.StackPassLoop:
	cmp BYTE [rdi], '%'
	jne .StackPassGoNext

	inc rdi

	cmp BYTE [rdi], '%'
	je .RegPassGoNext

	add r11, 8

	mov rax, [r11]
	push rax

.StackPassGoNext:
	inc rdi

.StackPassTest:
	cmp BYTE [rdi], 0
	jne .StackPassLoop


; Returning on begin position
	push r10

	ret
