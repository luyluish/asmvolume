; Equipe: Luis Henrique Fernandes de Carvalho, Maria Eduarda Bezerra de Macedo, Rauana de Carvalho Bento

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

; === Glossário de Variáveis ===
;
; NOME DA VARIÁVEL   | SIGNIFICADO
; ------------------------------------------
; 1. requestName     | Armazena a mensagem que solicita ao usuário o nome do arquivo de entrada
; 2. requestCopy     | Armazena a mensagem que solicita o nome do arquivo de saída (onde será salva a cópia do arquivo de áudio com volume reduzido)
; 3. requestVolume   | Armazena a mensagem que solicita ao usuário a constante de redução de volume
; 4. requestContinue | Armazena a mensagem que pergunta ao usuário se ele deseja deseja reduzir o volume de outro arquivo de aúdio (1 para sim)
; 5. inputName       | Armazena o nome do arquivo de entrada que o usuário insere
; 6. inputCopy       | Armazena o nome do arquivo de saída inserido pelo usuário
; 7. inputVolume     | Armazena a constante de volume (como string) inserida pelo usuário, antes de ser convertida em número
; 8. inputContinue   | Armazena a resposta que o usuário insere
; 9. volumeNum       | Armazena o valor numérico da constante de volume após a conversão de string para número (do tipo WORD)
; 10. continueNum    | Armazena o valor numérico da resposta do usuário ao fim do programa
; 11. outputHandle   | Armazena o handle (referência) do console de saída para escrever mensagens no console
; 12. inputHandle    | Armazena o handle do console de entrada, usado para ler o que o usuário digita
; 13. readHandle     | Armazena o handle do arquivo de entrada (arquivo de áudio .WAV) que está sendo lido
; 14. copyHandle     | Armazena o handle do arquivo de saída (arquivo onde o áudio processado será salvo).
; 15. consoleCount   | Armazena a quantidade de caracteres lidos ou escritos no console durante as operações de entrada/saída
; 16. readCount      | Armazena o número de bytes lidos do arquivo de entrada em cada operação de leitura
; 17. copyCount      | Armazena o número de bytes escritos no arquivo de saída em cada operação de escrita
; 18. headerBuffer   | Armazena temporariamente o cabeçalho do arquivo .WAV (os primeiros 44 bytes), que será copiado para o arquivo de saída sem alterações
; 19. readBuffer     | Armazena temporariamente os blocos de 16 bytes lidos do arquivo de áudio para serem processados
; 20. copyBuffer     | Armazena temporariamente os dados processados (com o volume reduzido) antes de serem gravados no arquivo de saída

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
    repeatNum dw ?  ; Armazenar a resposta final em formato int
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
    mov ebx, [ebp + 8]              ; Ponteiro para o buffer Read
    mov edi, [ebp + 12]             ; Ponteiro para o buffer Copy
    mov esi, DWORD PTR[ebp + 16]    ; Volume
    mov ecx, 8                      ; Contador para as 8 amostras de 2 bytes
reducao:
    mov ax, word ptr[ebx]           ; Carrega uma amostra do buffer de leitura
    cwd
    idiv si                         ; Divide a amostra pelo valor do volume
    mov word ptr[edi], ax           ; Armazena o resultado no buffer de cópia

    add edi, 2                      ; Avança 2 bytes no buffer de cópia
    add ebx, 2                      ; Avança 2 bytes no buffer de leitura
    
    dec ecx                         ; Decrementa do contador de amostras
    cmp ecx, 0                      ; Se for 0, os 16 bytes foram lidos
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

    ; === Ler o arquivo inteiro e copiar diretamente os 44 primeiros bytes
    invoke ReadFile, readHandle, addr headerBuffer, 44, addr readCount, NULL
    invoke WriteFile, copyHandle, addr headerBuffer, 44, addr copyCount, NULL

leituraDiv:    
    ; === Ler o resto do arquivo de 16 em 16 bytes para reduzir o volume
    invoke ReadFile, readHandle, addr readBuffer, 16, addr readCount, NULL
    cmp readCount, 0
    je final    ; Se o arquivo inteiro for lido, pula pro final do programa
    
    ; === Dividir o buffer atual pela constante (volumeNum) ===
    push DWORD PTR[volumeNum]
    push offset copyBuffer
    push offset readBuffer
    call reduzirVolume
    
    ; === Escrever o buffer processado no arquivo de saída ===
    invoke WriteFile, copyHandle, addr copyBuffer, 16, addr copyCount, NULL

    jmp leituraDiv

final:
    ; === Fechar os handles ===
    invoke CloseHandle, readHandle
    invoke CloseHandle, copyHandle

perguntarOutro:
    ; === Perguntar se usuário quer repetir ===
    invoke WriteConsole, outputHandle, addr requestRepeat, sizeof requestRepeat - 1, addr consoleCount, NULL
    invoke ReadConsole, inputHandle, addr inputRepeat, sizeof inputRepeat, addr consoleCount, NULL
                                    ; ===================================================
    push offset inputRepeat         ; Chamada da função para corrigir a resposta do usuário
    call corrigirInput              ; E depois, converter de ASCII para DWORD
    invoke atodw, addr inputRepeat  ; ===================================================
    mov repeatNum, ax

    cmp repeatNum, 1
    je start

    invoke ExitProcess, 0
    
end start