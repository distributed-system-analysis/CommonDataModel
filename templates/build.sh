#!/bin/bash

file=$1
cat header >$file.json
while [ ! -z "$1" ]; do
    cat $1.base >> $file.json
    shift
done
