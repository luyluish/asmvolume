.686
.model flat, stdcall
option casemap: none
include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
include \masm32\include\user32.inc
include \masm32\include\masm32.inc
includelib \masm32\lib\masm32.lib
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\user32.lib
include \masm32\include\msvcrt.inc
includelib \masm32\lib\msvcrt.lib
include /masm32/macros/macros.asm

.data

    ; === Variáveis contendo as solicitações de entrada ===
    requestName db "Insira o nome do arquivo de entrada: ", 0h
    requestCopy db "Insira o nome do arquivo de saida: ", 0h
    requestVolume db "Insira o valor de reducao de volume: ", 0h
    requestRepeat db "Deseja alterar outro arquivo? (1 - Confirmar):  "

    ; === Variáveis contendo as entradas do usuário ===
    inputName db 50 dup(0)
    inputCopy db 50 dup(0)
    inputVolume db 10 dup(0)
    inputRepeat db 10 dup(0)
    repeatNum dw ?
    volumeNum dw ?  ; Armazenar a entrada em formato int

    ; === Handles e Contadores ===
    outputHandle HANDLE ?
    inputHandle HANDLE ?
    readHandle HANDLE ?
    copyHandle HANDLE ?
    consoleCount dd ?
    readCount dd ?
    copyCount dd ?

    ; === Buffers ===
    headerBuffer db 44 dup(?)
    readBuffer db 16 dup(?)
    copyBuffer db 16 dup(?)

.code

; === Função para corrigir as strings inseridas no console ===
corrigirInput:
    push ebp
    mov ebp, esp
    mov esi, [ebp + 8]
proximo:
    mov al, [esi]
    inc esi
    cmp al, 13
    jne proximo
    
    dec esi
    xor al, al
    mov [esi], al
    mov esp, ebp
    pop ebp
    ret 4

; === Função para dividir o buffer pela constante inserida pelo usuário ===
reduzirVolume:
    push ebp
    mov ebp, esp
    mov ebx, [ebp + 8]  ; ReadBuffer
    mov edi, [ebp + 12] ; CopyBuffer
    mov esi, DWORD PTR[ebp + 16] ; Volume
    mov ecx, 8
reducao:
    mov ax, WORD PTR[ebx]
    cwd
    idiv si
    mov WORD PTR[edi], ax

    add edi, 2
    add ebx, 2
    
    dec ecx
    cmp ecx, 0
    jne reducao
epilogo:
    mov esp, ebp
    pop ebp
    ret 10

; === Início do Programa ===
start:
    ; === Inicializar os handles de saída e entrada ===
    invoke GetStdHandle, STD_OUTPUT_HANDLE
    mov outputHandle, eax
    invoke GetStdHandle, STD_INPUT_HANDLE
    mov inputHandle, eax

    ; === Solicitar o nome do arquivo de entrada ===
    invoke WriteConsole, outputHandle, addr requestName, sizeof requestName - 1, addr consoleCount, NULL
    invoke ReadConsole, inputHandle, addr inputName, sizeof inputName, addr consoleCount, NULL
                                    ; ===================================================
    push offset inputName           ; Chamada da função para corrigir a string de entrada
    call corrigirInput              ; ===================================================

    ; === Solicitar o nome do arquivo de saída (Cópia) ===
    invoke WriteConsole, outputHandle, addr requestCopy, sizeof requestCopy - 1, addr consoleCount, NULL
    invoke ReadConsole, inputHandle, addr inputCopy, sizeof inputCopy, addr consoleCount, NULL
                                    ; ===================================================
    push offset inputCopy           ; Chamada da função para corrigir a string de saída
    call corrigirInput              ; ===================================================

    ; === Solicitar a constante para reduzir o volume do arquivo ===
    invoke WriteConsole, outputHandle, addr requestVolume, sizeof requestVolume - 1, addr consoleCount, NULL
    invoke ReadConsole, inputHandle, addr inputVolume, sizeof inputVolume, addr consoleCount, NULL
                                    ; ===================================================
    push offset inputVolume         ; Chamada da função para corrigir a constante de redução
    call corrigirInput              ; E depois, converter de ASCII para DWORD
    invoke atodw, addr inputVolume  ; ===================================================
    mov volumeNum, ax

; ==============================================================================================================

abrir:
    ; === Abrir/Criar os arquivos de entrada e cópia ===
    invoke CreateFile, addr inputName, GENERIC_READ, 0, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
    mov readHandle, eax

    invoke CreateFile, addr inputCopy, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL
    mov copyHandle, eax

    ; === Lendo o arquivo inteiro, copiando os 44 primeiros bytes
    invoke ReadFile, readHandle, addr headerBuffer, 44, addr readCount, NULL
    invoke WriteFile, copyHandle, addr headerBuffer, 44, addr copyCount, NULL

leituraDiv:    
    ; === Lendo o resto do arquivo para reduzir o volume
    invoke ReadFile, readHandle, addr readBuffer, 16, addr readCount, NULL
    
    ; === Dividir o buffer atual pela constante (volumeNum) ===
    push DWORD PTR[volumeNum]
    push offset copyBuffer
    push offset readBuffer
    call reduzirVolume
    
    ; === Escrever o buffer processado no arquivo de saída ===
    invoke WriteFile, copyHandle, addr copyBuffer, 16, addr copyCount, NULL

    cmp readCount, 0
    jne leituraDiv

final:
    ; === Fechar os handles ===
    invoke CloseHandle, readHandle
    invoke CloseHandle, copyHandle

perguntarOutro:
    ; === Perguntar se usuário quer repetir ===
    invoke WriteConsole, outputHandle, addr requestRepeat, sizeof requestRepeat - 1, addr consoleCount, NULL
    invoke ReadConsole, inputHandle, addr inputRepeat, sizeof inputRepeat, addr consoleCount, NULL
                                    ; ===================================================
    push offset inputRepeat         ; Chamada da função para corrigir a resposta
    call corrigirInput              ; E depois, converter de ASCII para DWORD
    invoke atodw, addr inputRepeat  ; ===================================================
    mov repeatNum, ax

    cmp repeatNum, 1
    je start

    invoke ExitProcess, 0
    
end start