# Snake Game

Simple implementation of the **classic Snake game** using Bash scripting. The game is played in the terminal and provides a nostalgic experience with basic graphics and controls. It is designed to be lightweight and easy to run on any system with a Bash shell.

![Game Rules](images/title-screen.png)

## Game Rules
The player controls a **snake** moving on the **board**. There are **apples** (red squares) on the board, which, when eaten, **increase the length of the snake**. When one apple is eaten, a new one is randomly generated on the board. The goal of the game is to achieve **the longest possible snake**.

![Snake Game](images/game-preview.png)

Collision with the edges of the board or with the snake itself **ends the game**.

![Game Over](images/game-over-screen.png)

## Features
- Score counting.
- Start a new game after losing.
- Graphic design.
- Keyboard control.
- Help and version information.

## Dependencies
To run the game, ensure your system has the following dependencies installed:
- Bash (version 4.0 or later)
- `tput` (part of ncurses package)
- `stty` (for reading keyboard input)
- `sleep` (for game timing control)
- `zenity` (for graphical dialogs,)

These tools are available by default on most Linux distributions and macOS. For Windows users, it is recommended to run the game using WSL (Windows Subsystem for Linux) or a Git Bash terminal.

## Installation
Clone the repository and run the script:
```bash
git clone https://github.com/AdrianSzwaczyk/bash-snake-game.git
cd bash-snake-game
./snake.sh
```
