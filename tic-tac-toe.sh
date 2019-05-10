#!/bin/ksh
### INPUT ###
read_raw() {
	OLD_STTY=`stty -g`
	stty raw 
	local input="`dd bs=1 count=1 2>/dev/null`"
	stty "$OLD_STTY"
	echo $input
}

read_key() {
	local input=`read_raw`
	local keycode=`echo $input | hexdump -v -n1 -e '/1 "%02X"'`
	
	if [ "$keycode" = "03" ]; then echo INTERRUPT; exit; fi
	if [ "$keycode" = "0D" ]; then echo ENTER; exit; fi
	if [ "$keycode" = "0A" ]; then echo SPACE; exit; fi
	if [ "$keycode" != "1B" ]; then echo $input; exit; fi

	keycode=`echo $(read_raw) | hexdump -v -n1 -e '/1 "%02X"'`
	if [ "$keycode" = "5B" ]; then
		keycode=`echo $(read_raw) | hexdump -v -n1 -e '/1 "%02X"'`
		case $keycode in
			41) echo UP ;;
			42) echo DOWN ;;
			43) echo RIGHT ;;
			44) echo LEFT ;;
			*) echo $keycode
		esac
	fi
}


### MENU ###
menu_entry() {
	local selected=1
	while true; do
		local i=1
		for item in $@; do
			if [ "$i" != "1" ]; then printf ' | '; fi
			if [ "$i" = "$selected" ]; then
				tput bold
				printf "[$item]"
				tput sgr0
			else printf " $item "; fi
			let i=$i+1
		done
		
		printf '\r'
		local key=`read_key`
		if [ "$key" = "LEFT" ] && [ "$selected" -gt "1" ]; then
			let selected=$selected-1
		elif [ "$key" = "RIGHT" ] && [ "$selected" -lt "$#" ]; then
			let selected=$selected+1
		elif [ "$key" = "ENTER" ]; then
			return $selected
		elif [ "$key" = "INTERRUPT" ]; then
			return 0
		fi
	done
}

color() { tput bold setaf 3 0 0; printf "$*"; tput sgr0; }
bold() { tput bold; printf "$*"; tput sgr0; }

conrtols() {
	tput sc cup $1 28
	shift
	if [ "$1" == "BOLD" ]; then shift; bold "$*"
	else printf "$*"; fi
	tput sgr0 rc
}

menu() {
	clear
	printf "\n +=============+\n | "
	color "TIC TAC TOE"
	printf " | \n +=============+"

	bold '\n\n Select who starts:\n'
	menu_entry PLAYER COMPUTER
	case "$?" in
		1) START=0 ;;
		2) START=1 ;;
		*) return 1
	esac

	bold '\n\n Select your symbol:\n'
	menu_entry O X
	case "$?" in
		1) PLAYER='O'; AI='X' ;;
		2) PLAYER='X'; AI='O' ;;
		*) return 1
	esac

	conrtols 10 BOLD " CONTROLS: "
	conrtols 11 " q | w | e "
	conrtols 12 "---+---+---"
	conrtols 13 " a | s | d "
	conrtols 14 "---+---+---"
	conrtols 15 " z | x | c "
	return 0
}


### GAME ###
check() { [ "${BOARD[$2]}" == "$1" ]; }
winning() {
	if check $1 0 && check $1 1 && check $1 2; then return 1; fi
	if check $1 3 && check $1 4 && check $1 5; then return 2; fi
	if check $1 6 && check $1 7 && check $1 8; then return 3; fi
	if check $1 0 && check $1 3 && check $1 6; then return 4; fi
	if check $1 1 && check $1 4 && check $1 7; then return 5; fi
	if check $1 2 && check $1 5 && check $1 8; then return 6; fi
	if check $1 0 && check $1 4 && check $1 8; then return 7; fi
	if check $1 2 && check $1 4 && check $1 6; then return 8; fi
	return 0
}

check_win() {
	if ! winning "1";  then color " * You won!\n\n"; return 0; fi
	if ! winning "-1"; then color " * Computer won!\n\n"; return 0; fi
	for i in ${BOARD[@]}; do if [ "$i" == "0" ]; then return 1; fi; done
	color " * Draw!\n\n"; return 0
}

draw_spot() {
	local win=$1
	local spot=" "
	if [ "${BOARD[$2]}" == "1" ]; then spot=$PLAYER;
	elif [ "${BOARD[$2]}" == "-1" ]; then spot=$AI; fi

	shift; shift
	for i in $@; do
		if [ "$win" == "$i" ]; then
			color "$spot"
			exit;
		fi
	done
	printf "$spot"
}

draw_board() {
	winning "-1"
	local win=$?
	tput cup 10 0
	printf "\n    $(draw_spot $win 0 1 4 7) | $(draw_spot $win 1 1 5    ) | $(draw_spot $win 2 1 6 8) \n   ---+---+--- "
	printf "\n    $(draw_spot $win 3 2 4  ) | $(draw_spot $win 4 2 5 7 8) | $(draw_spot $win 5 2 6  ) \n   ---+---+--- "
	printf "\n    $(draw_spot $win 6 3 4 8) | $(draw_spot $win 7 3 5    ) | $(draw_spot $win 8 3 6 7) \n\n"
}

minimax() {
	local state=''
	for i in ${BOARD[@]}; do state="$state$i:"; done
	local move=`awk -v STATE="$state" -v FIRST=$FIRST -v RAND=$RANDOM '
		function check_winner() {
			if (BOARD[1] && BOARD[1] == BOARD[2] && BOARD[1] == BOARD[3]) return BOARD[1];
			if (BOARD[4] && BOARD[4] == BOARD[5] && BOARD[4] == BOARD[6]) return BOARD[4];
			if (BOARD[7] && BOARD[7] == BOARD[8] && BOARD[7] == BOARD[9]) return BOARD[7];
			if (BOARD[1] && BOARD[1] == BOARD[4] && BOARD[1] == BOARD[7]) return BOARD[1];
			if (BOARD[2] && BOARD[2] == BOARD[5] && BOARD[2] == BOARD[8]) return BOARD[2];
			if (BOARD[3] && BOARD[3] == BOARD[6] && BOARD[3] == BOARD[9]) return BOARD[3];
			if (BOARD[1] && BOARD[1] == BOARD[5] && BOARD[1] == BOARD[9]) return BOARD[1];
			if (BOARD[3] && BOARD[3] == BOARD[5] && BOARD[3] == BOARD[7]) return BOARD[3];
			return 0;
		}

		function minimax(val, depth, i, score, best, changed) { 
			if ((score = check_winner())) return (score == val) ? 100 : -100;
			for (i = 1; i <= 9; i++) {
				if (BOARD[i]) continue;

				BOARD[i] = val;
				changed = val;
				score = -minimax(-val, depth+1, 0, 0, -1, 0);
				BOARD[i] = 0;
		
				if (score <= best) continue;
				if (!depth) BEST = i;
				best = score;
			}
			return changed ? best : 0;
		}

		BEGIN {
			if (!STATE) STATE="_:_:_:_:_:_:_:_:_";
			split(STATE, BOARD,":");
			srand(RAND);
			if (FIRST == 1) {
				if		(BOARD[1] || BOARD[7] || BOARD[9])	print 4;
				else if (BOARD[2] || BOARD[4] || BOARD[5])	print 0;
				else if (BOARD[6] || BOARD[8])				print 2;
				else if (BOARD[3])							print 3;
				else print int(rand()*9);
			} else {
				minimax(-1, 0, 0, 0, -1, 0);
				print BEST-1;
			}
		}
	'`
	if [ "$FIRST" != "0" ]; then FIRST=0; fi
	if [ "$move" != "-1" ]; then BOARD[$move]='-1'; fi
}

start_game() {
	set -A BOARD 0 0 0 0 0 0 0 0 0
	set -A MOVEMENT q w e a s d z x c
	FIRST=1
	if [ "$START" == "0" ]; then draw_board; fi

	while true; do
		if [ "$START" != "0" ]; then START=0;
		else
			local mvmnt=0
			local input=`read_key`
			for i in `jot 9 0`; do
				if [ "$input" == "INTERRUPT" ]; then return 1; fi
				if [ "${MOVEMENT[$i]}" == "$input" ] && [ "${BOARD[$i]}" == "0" ]; then BOARD[$i]='1'; mvmnt=1; break; fi
			done
			if [ "$mvmnt" == 0 ]; then continue; fi
		fi
		minimax
		draw_board
		if check_win; then break; fi
	done
	return
}

if menu; then start_game
else echo "\n"; fi
