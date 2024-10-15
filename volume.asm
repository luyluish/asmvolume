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

.data

    ; === Variáveis contendo as solicitações de entrada ===
    requestName db "Insira o nome do arquivo de entrada:", 0h
    requestCopy db "Insira o nome do arquivo de saida:", 0h
    requestVolume db "Insira o valor de reducao de volume:", 0h

    ; === Variáveis contendo as entradas do usuário ===
    inputName db 50 dup(0)
    inputCopy db 50 dup(0)
    inputVolume db 10 dup(0)
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
    readBuffer dd 16 dup(0)
    copyBuffer dd 16 dup(0)

.code

; === Função para corrigir as strings inseridas no console ===
corrigirInput:
    push ebp        ; ]
    mov ebp, esp    ; Prólogo da Função
    sub esp, 8      ; ]
    mov esi, [ebp + 8]
proximo:
    mov al, [esi]
    inc esi
    cmp al, 13
    jne proximo
    
    dec esi
    xor al, al
    mov [esi], al
    mov esp, ebp    ; ]
    pop ebp         ; Epílogo da Função
    ret 4           ; ]

; === Função para dividir o buffer pela constante inserida pelo usuário ===
reduzirVolume:
    push ebp
    mov ebp, esp
    sub esp, 8
    mov esi, [ebp + 8]  ; Volume
    mov edi, [ebp + 12] ; Copy
    mov ebx, [ebp + 16]   ; Read
    mov ecx, 4
reducao:
    mov eax, [ebx]
    cwd
    idiv esi
    mov [edi], eax

    add edi, 4
    add ebx, 4
    
    cmp ecx, 0
    je epilogo
    dec ecx
    jmp reducao
epilogo:
    mov esp, ebp
    pop ebp
    ret 12

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

leitura:
    ; === Ler os arquivos abertos anteriormente ===
    invoke ReadFile, readHandle, addr readBuffer, 44, addr readCount, NULL
    cmp readCount, 0
    je final

    ; === Dividir o buffer atual pela constante ===
    

    ; === Criar arquivo cópia ===
    invoke WriteFile, copyHandle, addr readBuffer, 44, addr copyCount, NULL
    jmp leitura

final:
    ; === Fechar os handles ===
    invoke CloseHandle, readHandle
    invoke CloseHandle, copyHandle

    invoke ExitProcess, 0
    
end start