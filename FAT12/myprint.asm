section .data
commonfont: db  1Bh, "[39m", 0
redfont:    db  1Bh, "[31m", 0

global myprint

section .text
myprint:
    push ebx
    push eax
    mov ebx, [esp+8+8]
    cmp ebx, 0
    je notDir
    ; 是目录，加颜色
    mov eax, redfont
    call sprint
notDir:
    ; 直接输出
    mov eax, [esp+4+8]
    call sprint
    mov eax, commonfont
    call sprint

    pop eax
    pop ebx
    ret


;------------------------------------------
; int slen(String message)
; String length calculation function
slen:
    push    ebx
    mov     ebx, eax
 
.nextchar:
    cmp     byte [eax], 0
    jz      .finished
    inc     eax
    jmp     .nextchar
 
.finished:
    sub     eax, ebx
    pop     ebx
    ret
 
 
;------------------------------------------
; void sprint(String message)
; String printing function
sprint:
    push    edx
    push    ecx
    push    ebx
    push    eax
    call    slen
 
    mov     edx, eax
    pop     eax
 
    mov     ecx, eax
    mov     ebx, 1
    mov     eax, 4
    int     80h
 
    pop     ebx
    pop     ecx
    pop     edx
    ret
 