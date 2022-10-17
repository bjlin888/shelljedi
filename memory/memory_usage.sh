#!/bin/bash

ROWS=$( ps -o pid,user,%mem -o comm=Command ax | grep -v PID | sort -bnr -k3 | awk '/[0-9]*/{print $1 ":" $2 ":" $4}' )
for record in $ROWS
do
    echo $record
    PID=$( echo $record | cut -d: -f1)
    OWNER=$( echo $record | cut -d: -f2)
    COMMAND=$( echo $record | cut -d: -f2)
    MEMORY=$( sudo pmap $PID | tail -n 1 | awk '/[0-9]K/{print $2}')
    
    echo "PID: $PID"
    echo "OWNER: $OWNER"
    echo "COMMAND: $COMMAND"
    echo "MEMORY": $MEMORY
done