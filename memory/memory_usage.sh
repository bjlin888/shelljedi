#!/bin/bash

printf "%-10s%-15s%-15s%s\n" "PID" "OWNER" "MEMORY" "COMMAND"
function main() {
    ROWS=$( ps -o pid,user,%mem -o comm=Command ax | grep -v PID | sort -bnr -k3 | awk '/[0-9]*/{print $1 ":" $2 ":" $4}' )
    for record in $ROWS
    do
        PID=$( echo $record | cut -d: -f1)
        OWNER=$( echo $record | cut -d: -f2)
        COMMAND=$( echo $record | cut -d: -f3)
        MEMORY=$( sudo pmap $PID | tail -n 1 | awk '/[0-9]/{print $2}')
        
        printf "%-10s%-15s%-15s%s\n" "$PID" "$OWNER" "$MEMORY" "$COMMAND"
    done
}

main | sort -bnr -k3