TITLE PongASM                   (main.asm)
; Final Project of Andrew Hutson and Davis Mariotti
; Based on the windows program with animation in-class example
; Thanks, Kent!

; Currently, the program displays a moving box in a window along with two paddles
; Currently, the paddles can only move down, and collision detection is not functioning.
; The end result will hopefully be a functioning Pong game

; Original message:
; This program displays a resizable application window and
; several popup message boxes.
; Thanks to Tom Joyce for creating a prototype
; from which this program was derived.

INCLUDE Irvine32.inc
INCLUDE GraphWin.inc

DTFLAGS = 25h  ; Needed for drawtext
PADDLEHEIGHT = 250
PADDLEWIDTH = 25
BALLSIZE = 15

K_W = 57h
K_S = 53h
K_O = 4Fh
K_L = 4Ch

;==================== DATA =======================
.data

AppLoadMsgTitle BYTE "Application Loading" ,0
AppLoadMsgText  BYTE "Initiating PongASM" ,0

PopupTitle BYTE "Popup Window" ,0
PopupText	BYTE "Your clicking does nothing! *Evil Laugh*" ,0

GreetTitle BYTE "PongASM Initiated" ,0
GreetText  BYTE "Welcome to PongASM. "
					 BYTE "Press OK to continue.",0

CloseMsg   BYTE "Exiting PongASM. Thanks for playing!" ,0

Score1Str   BYTE "0",0
score1rect RECT <0,0,400,100>
Score2Str   BYTE "1",0
score2rect RECT <0,0,600,100>

ps PAINTSTRUCT <?>
hdc DWORD ?

ErrorTitle  BYTE "Error",0
WindowName  BYTE "PongASM",0
className   BYTE "PongASM",0

msg	     MSGStruct <>
winRect   RECT <>
hMainWnd  DWORD ?
hInstance DWORD ?

xloc SDWORD 50   ; x location of the box
yloc SDWORD 50   ; y location of the box
xdir SDWORD 6    ; x direction of box
ydir SDWORD 5    ; y direction of box

lpaddleloc DWORD 50	; top of left paddle
rpaddleloc DWORD 50	; top of right paddle

lScore DWORD 48 ; Ascii for 0
rScore DWORD 48

; Define the Application's Window class structure.
MainWin WNDCLASS <NULL,WinProc,NULL,NULL,NULL,NULL,NULL, \
	COLOR_WINDOW,NULL,className>
;=================== CODE =========================
.code
main PROC
; Get a handle to the current process.
	INVOKE GetModuleHandle, NULL
	mov hInstance, eax
	mov MainWin.hInstance, eax

; Load the program's icon and cursor.
	INVOKE LoadIcon, NULL, IDI_APPLICATION
	mov MainWin.hIcon, eax
	INVOKE LoadCursor, NULL, IDC_ARROW
	mov MainWin.hCursor, eax

; Register the window class.
	INVOKE RegisterClass, ADDR MainWin
	.IF eax == 0
	  call ErrorHandler
	  jmp Exit_Program
	.ENDIF

; Create the application's main window.
; Returns a handle to the main window in EAX.
	INVOKE CreateWindowEx, 0, ADDR className,
	  ADDR WindowName,MAIN_WINDOW_STYLE,
	  CW_USEDEFAULT,CW_USEDEFAULT,CW_USEDEFAULT,
	  CW_USEDEFAULT,NULL,NULL,hInstance,NULL
	mov hMainWnd,eax

; If CreateWindowEx failed, display a message & exit.
	.IF eax == 0
	  call ErrorHandler
	  jmp  Exit_Program
	.ENDIF

; Display a greeting message.
	INVOKE MessageBox, hMainWnd, ADDR GreetText,
	  ADDR GreetTitle, MB_OK

; Setup a timer
	INVOKE SetTimer, hMainWnd, 0, 30, 0

; Show and draw the window.
	INVOKE ShowWindow, hMainWnd, SW_SHOW
	INVOKE UpdateWindow, hMainWnd

; Begin the program's message-handling loop.
Message_Loop:
	; Get next message from the queue.
	INVOKE GetMessage, ADDR msg, NULL,NULL,NULL

	; Quit if no more messages.
	.IF eax == 0
	  jmp Exit_Program
	.ENDIF

	; Relay the message to the program's WinProc.
	INVOKE DispatchMessage, ADDR msg
    jmp Message_Loop

Exit_Program:
	  INVOKE ExitProcess,0
main ENDP

;-----------------------------------------------------
WinProc PROC,
	hWnd:DWORD, localMsg:DWORD, wParam:DWORD, lParam:DWORD
; The application's message handler, which handles
; application-specific messages. All other messages
; are forwarded to the default Windows message
; handler.
;-----------------------------------------------------
	mov eax, localMsg
	.IF eax == WM_LBUTTONDOWN		; mouse button?
	  INVOKE MessageBox, hWnd, ADDR PopupText,
	    ADDR PopupTitle, MB_OK
	  jmp WinProcExit
	.ELSEIF eax == WM_CREATE		; create window?
	  INVOKE MessageBox, hWnd, ADDR AppLoadMsgText,
	    ADDR AppLoadMsgTitle, MB_OK
	  jmp WinProcExit
	.ELSEIF eax == WM_CLOSE		; close window?
	  INVOKE MessageBox, hWnd, ADDR CloseMsg,
	    ADDR WindowName, MB_OK
	  INVOKE PostQuitMessage,0
	  jmp WinProcExit
	.ELSEIF eax == WM_TIMER     ; did a timer fire?
	  INVOKE InvalidateRect, hWnd, 0, 1
	  jmp WinProcExit
	.ELSEIF eax == WM_PAINT		; window needs redrawing?
	  INVOKE BeginPaint, hWnd, ADDR ps
	  mov hdc, eax

	  ; inc x position of the box
	  mov ebx, xloc
	  add ebx, xdir
	  mov xloc, ebx

	  ; inc y position of the box
	  mov ecx, yloc
	  add ecx, ydir
	  mov yloc, ecx

	  ; update the paddles
	  call	UpdatePaddles

	  ; draw the box
    mov ebx, xloc
    mov edx, yloc
    add ebx, BALLSIZE
    add edx, BALLSIZE
    INVOKE CreateRectRgn, xloc, yloc, ebx, edx
    mov ebx, eax
    INVOKE CreateSolidBrush, 00000000h
    INVOKE FillRgn, hdc, ebx, eax

    ; Draw left paddle
    mov ebx, lpaddleloc
    add ebx, PADDLEHEIGHT
    INVOKE CreateRectRgn, 10, lpaddleloc, 10 + PADDLEWIDTH, ebx
    mov ebx, eax
    INVOKE CreateSolidBrush, 001782FFh
    INVOKE FillRgn, hdc, ebx, eax

    ; Draw right paddle
    mov ebx, rpaddleloc
    add ebx, PADDLEHEIGHT
    INVOKE CreateRectRgn, 900, rpaddleloc, 900 + PADDLEWIDTH, ebx
    mov ebx, eax
    INVOKE CreateSolidBrush, 00AA1D23h
    INVOKE FillRgn, hdc, ebx, eax

    ; Bounce the ball off the paddles
    call BounceBall

	  ; reflect xdir
		cmp xloc, 1000
	  jl L1
		   mov eax, 0
	     sub eax, xdir
		   mov xdir, eax
       mov eax, rScore
       inc eax
       mov rScore, eax
	  L1:

		cmp xloc, 0
		jg L2
		   mov eax, 0
	     sub eax, xdir
		   mov xdir, eax
       mov eax, lScore
       inc eax
       mov lScore, eax
	  L2:

	  ; reflect ydir
		cmp yloc, 500
		jl L3
		   mov eax, 0
	     sub eax, ydir
		   mov ydir, eax
	  L3:

		cmp yloc, 0
		jg L4
		   mov eax, 0
	     sub eax, ydir
		   mov ydir, eax
	  L4:

    ; output text
    INVOKE DrawTextA, hdc, ADDR lScore, 1, ADDR score1rect, DTFLAGS
    INVOKE DrawTextA, hdc, ADDR rScore, 1, ADDR score2rect, DTFLAGS

	.ELSE		; other message?
	  INVOKE DefWindowProc, hWnd, localMsg, wParam, lParam
	  jmp WinProcExit
	.ENDIF

WinProcExit:
	ret
WinProc ENDP

;---------------------------------------------------


;---------------------------------------------------
ErrorHandler PROC
; Display the appropriate system error message.
;---------------------------------------------------
.data
pErrorMsg  DWORD ?		; ptr to error message
messageID  DWORD ?
.code
	INVOKE GetLastError	; Returns message ID in EAX
	mov messageID,eax

	; Get the corresponding message string.
	INVOKE FormatMessage, FORMAT_MESSAGE_ALLOCATE_BUFFER + \
	  FORMAT_MESSAGE_FROM_SYSTEM,NULL,messageID,NULL,
	  ADDR pErrorMsg,NULL,NULL

	; Display the error message.
	INVOKE MessageBox,NULL, pErrorMsg, ADDR ErrorTitle,
	  MB_ICONERROR+MB_OK

	; Free the error message string.
	INVOKE LocalFree, pErrorMsg
	ret
ErrorHandler ENDP

UpdatePaddles PROC
	; move paddles by checking key states
	; W key
	INVOKE GetAsyncKeyState, K_W
	.IF eax == 8000h
		mov ebx, lpaddleloc
		sub ebx, 5
		mov lpaddleloc, ebx
	.ENDIF

	; S key
	INVOKE GetAsyncKeyState, K_S
	.IF eax == 8000h
		mov ebx, lpaddleloc
		add ebx, 5
		mov lpaddleloc, ebx
	.ENDIF

	; O key
	INVOKE GetAsyncKeyState, K_O
	.IF eax == 8000h
		mov ebx, rpaddleloc
		sub ebx, 5
		mov rpaddleloc, ebx
	.ENDIF

	; L key
	INVOKE GetAsyncKeyState, K_L
	.IF eax == 8000h
		mov ebx, rpaddleloc
		add ebx, 5
		mov rpaddleloc, ebx
	.ENDIF

	ret
UpdatePaddles ENDP

BounceBall PROC

  ; Check left paddle
	mov eax, PADDLEWIDTH + 10
	cmp xloc, eax ; check x direction
	jge Bypass1 ; if no paddle contact, do not bounce
		mov eax, lpaddleloc
		add eax, BALLSIZE
		cmp yloc, eax ; check y direction with top of paddle
		jle Bypass1 ; if no paddle contact, do not bounce
			mov eax, lpaddleloc
			add eax, PADDLEHEIGHT
			cmp yloc, eax ; check y direction with bottom of paddle
			jge Bypass1 ; if no paddle contact, do not bounce

				; if paddle contact has occurred, bounce the ball
				mov eax, 0
				sub eax, xdir
				mov xdir, eax

	Bypass1:

  ; Check right paddle
	mov eax, xloc
	add eax, BALLSIZE
	cmp eax, 900 ; check x direction
	jle Bypass2 ; if no paddle contact, do not bounce
		mov eax, rpaddleloc
		add eax, BALLSIZE
		cmp yloc, eax ; check y direction with top of paddle
		jle Bypass2 ; if no paddle contact, do not bounce
			mov eax, rpaddleloc
			add eax, PADDLEHEIGHT
			cmp yloc, eax ; check y direction with bottom of paddle
			jge Bypass2 ; if no paddle contact, do not bounce

				; if paddle contact has occurred, bounce the ball
				mov eax, 0
				sub eax, xdir
				mov xdir, eax

	Bypass2:

	ret
BounceBall ENDP

END
