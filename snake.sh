#!/bin/bash

# Author           : Adrian Szwaczyk 193233 ( adrianszwaczyk@gmail.com )
# Created On       : 05.05.2023
# Last Modified On : 09.05.2023 
# Version          : 1.0
#
# Description      :
# Bash implementation of a classic game "Snake"
#
# Licensed under GPL (see /usr/share/common-licenses/GPL for more details
# or contact # the Free Software Foundation for a copy)

resize -s 24 80

#general variables
WIDTH=$(tput cols)								#screen width
HEIGHT=$(tput lines)							#screen height
HEIGHT=$[HEIGHT-1]								#board width (last line is for score)
WIDTH=$[WIDTH/2*2]								#board height (board bust be 2|WIDTH)
INITIAL_TICK_TIME=0.1							#time between snake updates
INITIAL_FOOD_RATE=$[((WIDTH*HEIGHT/1000))]		#quantity of food at the beggining
declare -A FOOD									#associative array, to search for food by coordinates

#handling console setup
CMD_INITIAL_SETUP=$(stty -g)
printf "\e[?25l"				#disable cursor
printf "\e]0;SNAKE\007"			#set cmd title
stty -echo -icanon				#disable echoing user input and enable immediate processing of the input

#draw title screen and wait for user input
function title_screen() {
	clear
	draw_ascii_art 73 ${#TITLE_SCREEN[@]} TITLE_SCREEN
	read_option
}

# 1 and 2 - numbers to be compared
function min() {
    if (( $1 <= $2 )); then
        echo $1
    else
        echo $2
    fi
}

#get array element by index
function get_by_index() {
	eval echo \"\${$2[\$1]}\"
}

#get array element key by its index
function get_key_by_index() {
    eval echo \${!$2[@]} | cut -d ' ' -f $1
}

function display_score() {
	printf "\e[$[HEIGHT+1];$[WIDTH/2-6]fScore: %6d" $SCORE
}

#check user choice
function read_option() {
	while :
	do 
		read -rn1 input
		case "$input" in
			q) quit ;;
			h) help ;;
			i) info ;;
			*) break ;;
		esac
	done
}

# 1 - width of the art, 2 - height of the art, 3 - the art itself (array)
function draw_ascii_art() {
	local WINDOW_W WINDOW_H x y
	WINDOW_W=$(min $1 $[WIDTH-1])
	WINDOW_H=$(min $2 $HEIGHT)
	x=$[(WIDTH-WINDOW_W)/2]
	y=$[(HEIGHT-WINDOW_H)/2]
	printf "\e[${y};${x}f┌" ; printf '─%.0s' $(eval echo {1..$WINDOW_W}) ; printf '┐\n'
	for ((ROW=0;ROW<=$WINDOW_H;ROW++)) 
	do 
		printf "\e[$[y+ROW+1];${x}f│" ; echo -en "$(get_by_index $ROW $3)" ; printf "\e[$[y+ROW+1];$[x+WINDOW_W+1]f│"
	done
	printf "\e[$[y+WINDOW_H+1];${x}f└" ; printf '─%.0s' $(eval echo {1..$WINDOW_W}) ; printf '┘\n'
}

#draw game area (borders)
function draw_board() {
	local x y cy cx
	cx=$[WIDTH/2]
	cy=$[HEIGHT/2]
	printf "\e[30;1m"
	for ((x=0;x<=$cx;x++))
	do
		printf  "\e[1;$[cx-x]f█\e[1;$[cx+x]f█" ; printf  "\e[$HEIGHT;$[cx-x]f█\e[$HEIGHT;$[cx+x]f█"
		sleep 0.005
	done
	for ((y=0;y<=$cy;y++))
	do
		printf "\e[${y};1f█\e[${y};${WIDTH}f█\e[${y};2f█\e[${y};$[WIDTH-1]f█"
		printf "\e[$[HEIGHT-y];1f█\e[$[HEIGHT-y];${WIDTH}f█\e[$[HEIGHT-y];2f█\e[$[HEIGHT-y];$[WIDTH-1]f█"
		sleep 0.01
	done
	printf "\e[0m"
}

function new_game() {
	unset SNAKE OPPOSITE DIRECTION DEL1 DEL2 OHEAD_Y OHEAD_X LENGTH
	for i in ${!FOOD[@]}
	do 
		unset FOOD[$i]
	done
	HEAD_X=$[(WIDTH/4)*2+1] HEAD_Y=$[HEIGHT/2]					#start at the middle
	OHEAD_X=$[(WIDTH/4)*2+1] OHEAD_Y=$[HEIGHT/2]
	SNAKE=([0]="$HEAD_Y;$HEAD_X"  [1]="$HEAD_Y;$[HEAD_X+1]") 	#initialize snake array with head
	DIRECTION='' 
	DEAD=0
	SCORE=0
	LENGTH=1
	TICK_TIME=${INITIAL_TICK_TIME}								#set tick time back to initial
	clear
	draw_board
	gen_initial_food
}

function move() {
	check_collisions	#check if snake ate or collided with wall or himself

	EAT=$?
	[ $DEAD -eq 1 ] && game_over
	[ "$DIRECTION" != '' ] && [ $EAT -eq 0 ] && remove_tail		#remove last segment of the snake

	remove_eyes			#remove eyes left by head
	draw_head			#draw head in new location

	( sleep $TICK_TIME; trap - ALRM && kill -ALRM $$ 2>/dev/null ) &	#calls ALRM every $TICK_TIME[s], which calls this function

	move_head			#move beggining of the snake (creating new segment in new location)
	display_score
	set_opposite		#to prevent player from turning back, right into the snake
}

#read player arrow and option input
function read_movement() {
	read -n1 input
	case "$input" in
		$'\033') 					#indicates that input is an arrow
			read -n2 arrow
			[[ ${arrow:1} != $OPPOSITE ]] && DIRECTION=${arrow:1} ;;
		q) quit ;;
		h) help ;;
		i) info ;;
	esac
}

#set opposite direction to prevent player from choosing it
function set_opposite() {
	[[ "$DIRECTION" == A ]] && OPPOSITE=B 
	[[ "$DIRECTION" == B ]] && OPPOSITE=A 
	[[ "$DIRECTION" == C ]] && OPPOSITE=D 
	[[ "$DIRECTION" == D ]] && OPPOSITE=C
	[[ $LENGTH -le 1 ]] && OPPOSITE=X			#head only snake can move in any directon
}

function move_head() {
	case "$DIRECTION" in
		A) HEAD_Y=$[HEAD_Y-1] ;; #up
		B) HEAD_Y=$[HEAD_Y+1] ;; #down
		C) HEAD_X=$[HEAD_X+2] ;; #right	
		D) HEAD_X=$[HEAD_X-2] ;; #left
	esac
	SNAKE[$[LENGTH*2]]="$HEAD_Y;$HEAD_X"		#adding a new segment as a new head location
	SNAKE[$[LENGTH*2+1]]="$HEAD_Y;$[HEAD_X+1]"
}

#draw first segment, with eyes
function draw_head() {
	if [ "$DIRECTION" == "D" ] ; then							#eyes are different, according to the direction
		echo -en "\e[$HEAD_Y;${HEAD_X}f\e[1;30;42m:\e[0m"
		echo -en "\e[$HEAD_Y;$((HEAD_X+1))f\e[1;30;42m \e[0m"
	elif [ "$DIRECTION" == "C" ] ; then
		echo -en "\e[$HEAD_Y;${HEAD_X}f\e[1;30;42m \e[0m"
		echo -en "\e[$HEAD_Y;$((HEAD_X+1))f\e[1;30;42m:\e[0m"
	else 
		echo -en "\e[$HEAD_Y;${HEAD_X}f\e[1;30;42m·\e[0m"
		echo -en "\e[$HEAD_Y;$((HEAD_X+1))f\e[1;30;42m·\e[0m"
	fi
}

function remove_eyes() {
	if [ $LENGTH -gt 1 ] ; then					#remove eyes from field which is no longer a head
		echo -en "\e[$OHEAD_Y;${OHEAD_X}f\e[42m \e[0m"
		echo -en "\e[$OHEAD_Y;$((OHEAD_X+1))f\e[42m \e[0m"
	fi
	OHEAD_X=$HEAD_X
	OHEAD_Y=$HEAD_Y
}

#delete last segment - the snake moves by adding new segments at the beggining and removing at the end
function remove_tail() {
	printf "\e[${SNAKE[$DEL1]}f "
	unset SNAKE[$DEL1]
	printf "\e[${SNAKE[$DEL2]}f "
	unset SNAKE[$DEL2]
	SNAKE=("${SNAKE[@]}")
	DEL1=$(get_key_by_index 1 SNAKE)
	DEL2=$(get_key_by_index 2 SNAKE)
}

#initial food generation
function gen_initial_food() {
	for ((i=0; i<$INITIAL_FOOD_RATE; i++))
	do
		gen_new_food
	done
}

function gen_new_food() {
	local x y food
	x=$[((2*(RANDOM%((WIDTH-4)/2))+3))]
	y=$[RANDOM%(HEIGHT-2)+2]
	#make sure that a new food is in unique place and not on a snake
	while [[ $(echo ${!FOOD[@]} | tr ' ' '\n' | grep -c "^$y;$x$") -gt 0 ]] || [[ $(echo ${SNAKE[@]} | tr ' ' '\n' | grep -c "^$y;$x$") -gt 0 ]]
	do
		x=$[((2*(RANDOM%((WIDTH-4)/2))+3))]
		y=$[RANDOM%(HEIGHT-2)+2]
	done
	FOOD["$y;$x"]=1
	printf "\e[$y;${x}f\e[41m \e[0m"
	printf "\e[$y;$((x+1))f\e[41m \e[0m"
}

function check_collisions() {
	if [ ! -z "$DIRECTION" ] ; then
	 	local last
	 	last=${#SNAKE[@]}
	 	[ $(echo ${SNAKE[@]} | tr ' ' '\n' | head -n $[last-4] | grep -c "^$HEAD_Y;$HEAD_X$") -gt 0 ] && DEAD=1
	fi	#check if head coordinates are the same as coordinates of any of the body segments

	if [ "${FOOD["$HEAD_Y;$HEAD_X"]}" == "1" ] ; then
		unset FOOD["$HEAD_Y;$HEAD_X"]
		: $[SCORE++] $[LENGTH++]
		TICK_TIME=$(echo "$TICK_TIME * 0.99" | bc -l)
		gen_new_food
		return 1
	fi	#check if head coordinates are occupied by food

	[ $HEAD_Y -le 1 ] || [ $HEAD_X -le 2 ] || [ $HEAD_Y -ge $HEIGHT ] || [ $HEAD_X -ge $[WIDTH-1] ] && DEAD=1
	#check if head is on the board

	return 0
}

#when snake is dead
function game_over() {
	draw_ascii_art 98 ${#GAME_OVER[@]} GAME_OVER
	read_option
	DEAD=0 SCORE=0
	new_game
}

#make cmd as it was before playing snake
function clean() {
	stty "$CMD_INITIAL_SETUP"
	tput sgr0
	clear
}

#quit alert
function quit() {
	zenity --question --title "Exit" --text "Are you sure to quit?" --ok-label "Yes" --cancel-label "No" --width 300 --height 150
	[[ $? -eq 0 ]] && kill -s INT $$
}

#help window
function help() {
	zenity --info --title "Help" --width 300 --height 150 --text "Eat apples, grow longer
And watch out for walls and your own body!

Arrows - movement
Q - exit"
}

#info window
function info() {
	zenity --info --title "Info" --text "!" --width 500 --height 150 --text "Author: Adrian Szwaczyk 193233 (adrianszwaczyk@gmail.com)
Created On: 05.05.2023
Last Modified On: 09.05.2023 
Version: 1.0

Description:
Bash implementation of a classic game "Snake"

Licensed under GPL (see /usr/share/common-licenses/GPL for more details
or contact # the Free Software Foundation for a copy)"
}

#title screen ascii art
{
	TITLE_SCREEN[0]='\e[1;35m ________       ________       ________      ___  ___       _______      \e[0m'
	TITLE_SCREEN[1]='\e[1;35m|\   ____\     |\   ___  \    |\   __  \    |\  \|\  \     |\  ___ \     \e[0m'
	TITLE_SCREEN[2]='\e[1;35m\ \  \___|_    \ \  \\\ \  \   \ \  \|\  \   \ \  \/  /|_   \ \   __/|    \e[0m'
	TITLE_SCREEN[3]='\e[1;35m \ \_____  \    \ \  \\\ \  \   \ \   __  \   \ \   ___  \   \ \  \_|/__  \e[0m'
	TITLE_SCREEN[4]='\e[1;35m  \|____|\  \    \ \  \\\ \  \   \ \  \ \  \   \ \  \\\ \  \   \ \  \_|\ \ \e[0m'
	TITLE_SCREEN[5]='\e[1;35m    |\_______\    \ \__\\\ \__\   \ \__\ \__\   \ \__\\\ \__\   \ \_______\\\e[0m'
	TITLE_SCREEN[6]='\e[1;35m    \|_______|     \|__| \|__|    \|__|\|__|    \|__| \|__|    \|_______|\e[0m'
	TITLE_SCREEN[7]='\e[1;35m                                                                         \e[0m'
	TITLE_SCREEN[8]='\e[1;37m                          PRESS ANY KEY TO START                         \e[0m'
	TITLE_SCREEN[9]='\e[1;37m  i - info                       h - help                      q - quit  \e[0m'
}

#game over screen ascii art
{
	GAME_OVER[0]='\e[1;35m ________  ________  _____ ______   _______         ________  ___      ___ _______   ________     \e[0m'
	GAME_OVER[1]='\e[0;35m|\   ____\|\   __  \|\   _ \  _   \|\  ___ \      |\   __  \|\  \    /  /|\  ___ \ |\   __  \    \e[0m'
	GAME_OVER[2]='\e[1;35m\ \  \___|\ \  \|\  \ \  \\\\\__\ \  \ \   __/|     \ \  \|\  \ \  \  /  / | \   __/|\ \  \|\  \   \e[0m'
	GAME_OVER[3]='\e[0;35m \ \  \  __\ \   __  \ \  \\\|__| \  \ \  \_|/__    \ \  \\ \\  \ \  \/  / / \ \  \_|/_\ \   _  _\  \e[0m'
	GAME_OVER[4]='\e[1;35m  \ \  \|\  \ \  \ \  \ \  \    \ \  \ \  \_|\ \    \ \  \\ \\  \ \    / /   \ \  \_|\ \ \  \\\  \| \e[0m'
	GAME_OVER[5]='\e[1;35m   \ \_______\ \__\ \__\ \__\    \ \__\ \_______\    \ \_______\ \__/ /     \ \_______\ \__\\\ _\ \e[0m'
	GAME_OVER[6]='\e[1;35m    \|_______|\|__|\|__|\|__|     \|__|\|_______|     \|_______|\|__|/       \|_______|\|__|\|__|\e[0m'
	GAME_OVER[7]='\e[1;35m                                                                                                 \e[0m'
	GAME_OVER[8]='\e[1;37m                                 PRESS ANY KEY TO START A NEW GAME                               \e[0m'
	GAME_OVER[9]='\e[1;37m  i - info                                   h - help                                  q - quit  \e[0m'
}

#main
trap 'clean ; exit 0' EXIT		#on exit call cleaning function
trap move ALRM					#on kill ALRM call move (which calls kill ALRM to call the next move)
title_screen					#display title screen
new_game						#begin a first game
move							#start a move function
while :
do
	read_movement				#read arrows and options all the time
done