; Author: FangFangTu
; Time: 2021-10-14 11:52
%include "util.asm"

section .data
Welcome:    db  "Please enter two numbers:", 0h
h1:   db  "sum: ", 0h
h2:   db  "product: ", 0h
length: equ 255  
decimal:  dd  10  
    
section .bss
str1:   resb    length
str2:   resb    length
flag1:  resd    1       ; 0+ | 1-
flag2:  resd    1       ; 0+ | 1-
maxlen: resd    1       ; 长度对齐后的最大长度
bigger: resd    1       ; |a| > |b| ? 0 : 1

fstlen: resd    1       ; 第一个数（短）的长度，加法中使用
carry:  resb    1       ; 进位   

addRes: resb    length  ; 加法结果
mulRes: resb    length  ; 乘法中间结果
resFlag:resd    1       ; 结果的符号 0+ | 1-

section .text
global _start
_start:
; （1）输出提示语，读入两个字符串（以LF分割）
    mov eax, Welcome
    call sprintLF
    mov eax, str1
    call Read
    mov eax, str2
    call Read
; （1.5）删去行尾换行
    mov eax, str1
    call delLF
    mov eax, str2
    call delLF

; （2）判断两个数的符号，删去负号
    mov eax, str1
    call flag
    mov [flag1], eax
    mov eax, str2
    call flag
    mov [flag2], eax
    ; <debug> 打印符号
    ; mov eax, [flag1]
    ; call iprintLF
    ; mov eax, [flag2]
    ; call quit
    ; </debug>

; （3）字符串反转 
    mov eax, str1
    call reverse
    mov eax, str2
    call reverse

; （4）长度扩展，在行尾补0，maxlen记录最大长度
    mov eax, str1
    call slen
    push eax
    mov eax, str2
    call slen
    pop ebx
    cmp eax, ebx
    ja a
    jb b
    ; 一样长
    mov [maxlen], eax
    jmp next
a:  ; 第2个数长
    mov [maxlen], eax
    mov eax, str1
    call extend
    jmp next
b:  ; 第1个数长
    mov [maxlen], ebx
    mov eax, str2
    call extend
next: 
    ; <debug> 以正序打印扩展后字串
    ; mov eax, str1
    ; call reverse
    ; mov eax, str2
    ; call reverse
    ; mov eax, str1
    ; call sprintLF
    ; mov eax, str2
    ; call sprintLF
    ; call quit
    ; </debug>  

; （5）比较两个数的大小
    mov eax, str1
    mov ebx, str2
    call scmpr
    mov [bigger], eax

; （debug）两数之和差积
    ; <debug> 
    ; mov eax, str1 
    ; mov ebx, str2
    ; call stepAdd        ; 打印两数之和
    ; call stepSub        ; 打印两数之差(a>b)
    ; call stepMul        ; 打印两数之积          
    ; mov eax, addRes
    ; call reverse
    ; call sprintLF
    ; call quit
    ; </debug>

; （6）求两数之和，根据符号进加或减操作
RealAdd:
    mov eax, [flag1]
    mov ebx, [flag2]
    xor eax, ebx
    cmp eax, 0
    je .same
    jmp .diff
.same:   ; 同号
    mov eax, [flag1]
    mov [resFlag], eax
    mov eax, str1
    mov ebx, str2
    call stepAdd
    jmp .then
.diff:   ; 异号，大减小
    cmp byte [bigger], 0
    je .fst
    jmp .sec
.fst:
    mov eax, [flag1]
    mov [resFlag], eax
    mov eax, str1
    mov ebx, str2
    call stepSub
    jmp .then
.sec:
    mov eax, [flag2]
    mov [resFlag], eax
    mov eax, str2
    mov ebx, str1
    call stepSub
    jmp .then
.then:   ; 删除多余的零，添加符号，输出
    mov eax, addRes
    call delZero
    mov eax, addRes
    mov ebx, resFlag
    call addFlag
    mov eax, h1
    call sprint
    mov eax, addRes
    call reverse
    call sprintLF

; （7）将addRes清零
    mov eax, addRes
    mov ecx, [maxlen]
    add ecx, [maxlen]
    call clear

; （8）求两数之积
RealMul:
    mov eax, [flag1]
    mov ebx, [flag2]
    xor eax, ebx
    cmp eax, 0
    je .same
    jmp .diff
.same:   ; 同号
    mov byte [resFlag], 0
    mov eax, str1
    mov ebx, str2
    call stepMul
    jmp .then
.diff:   ; 异号
    mov byte [resFlag], 1
    mov eax, str1
    mov ebx, str2
    call stepMul
    call addFlag
    jmp .then
.then:   ; 删除多余的零，添加符号，输出
    mov eax, addRes
    call delZero
    mov eax, addRes
    mov ebx, resFlag
    call addFlag
    mov eax, h2
    call sprint
    mov eax, addRes
    call reverse
    call sprintLF
; （9）程序退出
    call quit

;--------------------
; void Read(String str)
; 读取最多length字节，存入str中
Read:
    push ecx

    mov edx, length
    mov ecx, eax
    mov ebx, 0
    mov eax, 3
    int 80h

    pop ecx
    ret

;--------------------
; int isNeg(String num)
; Return 0 pos, 1 neg  并且如果num是负数，把负号用0代替
flag:
    push eax
    mov eax, [eax]
    and eax, 0x00ff
    cmp eax, 0x2d
    pop eax
    
    jne .pos
    mov byte [eax], 0x30
    mov eax, 1
    ret
.pos:
    mov eax, 0
    ret

;--------------------
; void extend(String num)
; 直接对num进行修改，在行尾以0补齐
extend:
    push ecx
    push ebx
    push eax
    call slen
    mov ebx, eax        ; ebx = 短长度
    mov ecx, [maxlen]
    sub ecx, ebx        ; ecx = 差
    pop eax
    add eax, ebx        ; eax = 字符串尾

.addZero:
    mov byte [eax], 0x30
    inc eax
    loop .addZero

    pop ebx
    pop ecx
    ret

; --------------------
; void delLF(String num)
; 直接对num修改，删去行尾换行
delLF:
    push ebx
    push eax
    call slen
    mov ebx, eax
    pop eax
    add eax, ebx
    mov byte [eax-1], 0
    pop ebx
    ret

;------------------------------------------
; void clear(String number, int ecx)
; clear string to "000..."
clear:
    mov byte [eax], 0x30
    inc eax
    loop clear
    ret

; --------------------
; void stepAdd(String a, String b)
; a和b均为正数且已反转
; 将a和b的计算结果存入addRes
stepAdd:
    push eax
    call slen
    mov [fstlen], eax
    pop eax

    mov byte [carry], 0     ; 进位清零
    push edx
    push ecx
    mov ecx, 0              ; 位偏移量

.nextchar:  ; 按位相加
    mov dl, byte [eax+ecx]
    sub dl, 0x30
    add dl, byte [ebx+ecx]
    sub dl, 0x30
    add dl, [carry]         ; dl = 两数之和（int） 
    cmp dl, 9
    ja .carried
    mov byte [carry], 0
    jmp .then
.carried:
    mov byte [carry], 1
    sub dl, 10
.then:
    add dl, 0x30
    mov byte [addRes+ecx], dl
    inc ecx
    cmp ecx, [fstlen]
    jne .nextchar

    ; 两数相加可能进位
    cmp byte [carry], 1
    jne .exit
    mov byte [addRes+ecx], 0x31
.exit:    
    pop ecx
    pop edx
    ret

; --------------------
; void stepSub(String a, String b)
; a和b均为正数且已反转，且 a > b
; 将a和b的计算结果存入addRes
stepSub:
    mov byte [carry], 0     ; 借位清零
    push edx
    push ecx
    mov ecx, 0              ; 位偏移量

.nextchar:  ; 按位相减
    mov dl, byte [eax+ecx]
    sub dl, byte [ebx+ecx]
    sub dl, [carry]         ; dl = 两数之差（int） 
    add dl, 10              ; [-9, 9] -> [1, 19]
    cmp dl, 10
    jb .carried
    mov byte [carry], 0
    sub dl, 10
    jmp .then
.carried:
    mov byte [carry], 1
.then:
    add dl, 0x30
    mov byte [addRes+ecx], dl
    inc ecx
    cmp ecx, [maxlen]
    jne .nextchar
    
    pop ecx
    pop edx
    ret

; --------------------
; void stepMul(String a, String b)
; a和b均为正数且已反转
; 将a和b的计算结果存入mulRes
stepMul:
    mov byte [carry], 0
    push edi
    push esi         
    push edx
    push ecx
    
    mov edi, 0               ; 外循环位偏移量
.outerLoop:
    ; 清空mulRes
    push eax
    mov eax, mulRes
    mov ecx, [maxlen]
    add ecx, 1
    call clear
    pop eax
    
    mov esi, 0               ; 内循环位偏移量
    .innerLoop:
        mov ecx, 0
        mov edx, 0

        mov cl, [eax+esi]
        sub cl, 0x30             
        mov dl, [ebx+edi]
        sub dl, 0x30
        
        push eax
        mov eax, ecx         
        mul edx                 ; al = cl * dl
        add al, [carry]         ; al += carry
        mov edx, 0
        div dword [decimal]        
        ; mov edx, edx            ; dl = al % 10
        mov ecx, eax            ; cl = al / 10
        pop eax

        mov byte [carry], cl            ; 记录进位
        add dl, 0x30        
        mov byte [mulRes+edi+esi], dl   ; 记录得数

        inc esi
        cmp esi, [maxlen]
        jne .innerLoop

        ; 如果最后有进位
        cmp byte [carry], 0
        je .innerLoopDone
        mov ecx, [carry]
        add ecx, 0x30
        mov byte [mulRes+edi+esi], cl
    .innerLoopDone:
    ; <debug> 打印每次乘法中间结果
    ; push eax
    ; mov eax, mulRes
    ; call sprintLF
    ; pop eax
    ; </debug>
    
    push ebx
    push eax
    mov ebx, addRes
    mov eax, mulRes
    call stepAdd
    pop eax
    pop ebx
    ; <debug> 打印每次累加中间结果
    ; push eax
    ; mov eax, addRes
    ; call sprintLF
    ; pop eax
    ; </debug>

    inc edi
    cmp edi, [maxlen]
    jne .outerLoop

    pop ecx
    pop edx
    pop esi
    pop edi
    ret

; --------------------
; void delZero(String a)
; 删去字符串尾部的'0'
delZero:
    push ecx
    push eax
    call slen
    mov ecx, eax
    pop eax
.prechar:
    dec ecx
    cmp byte [eax+ecx], 0x30
    jne .exit
    cmp ecx, 0          ; 最后一个零了别删了
    je .exit
    mov byte [eax+ecx], 0
    jmp .prechar
.exit:
    pop ecx
    ret

; --------------------
; void addFlag(String a, String flag)
; 在字符串尾部添加符号
addFlag:
    push ecx
    push eax
    call slen
    mov ecx, eax
    pop eax

    cmp byte [ebx], 0
    je .pos
    mov byte [eax+ecx], 0x2D
.pos:
    pop ecx
    ret
