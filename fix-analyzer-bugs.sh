#!/bin/bash

for ((a=0; a <= 1000 ; a++))
do
    sleep 1s
    xdotool key F8
    sleep 1s
    xdotool key F9
    sleep 1s
    xdotool key KP_Enter
    sleep 1s
    xdotool key F11
done