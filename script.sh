#!/bin/bash

timeout=600
file="?"
browser="?"
runOnlyOnce="0"
writeToFile="0"
writeToScreen="0"

function printHelp() {
  echo "Name: Waiting for changes"
  echo "Usage: sh script.sh [OPTIONS] [URLS]"
  echo ""
  echo "[OPTIONS]:"
  echo ""
  echo "-h"
  echo "Print help."
  echo ""
  echo "-o"
  echo "Disable infinite searching loop, checking process runs only once per url."
  echo ""
  echo "-f [FILE_PATH]"
  echo "Specify file from which urls will be read. Each url should be placed in separate line."
  echo ""
  echo "-t [INTERVAL]"
  echo "Specify interval between checks."
  echo ""
  echo "-b [BROWSER]"
  echo "Specify in which browser given urls should be opened. Disabled when -w or -s enabled."
  echo ""
  echo "-w"
  echo "Write result into a result.txt file. Works interchangeably with -s option."
  echo ""
  echo "-s"
  echo "Write result on the screen. Works interchangeably with -w option."
  exit 0
}

function readUrlsFromFile() {
  filename=$1
  k=0
  while IFS= read -r line; do
    urls[k]="$line"
  done <"$filename"
}

function parseArguments() {
  while getopts "f:t:b:hows" option; do
    case "${option}" in
    f)
      file=${OPTARG}
      readUrlsFromFile "$file"
      ;;
    t)
      timeout=${OPTARG}
      ;;
    b)
      browser=${OPTARG}
      ;;
    h)
      printHelp
      ;;
    o)
      runOnlyOnce="1"
      ;;
    w)
      writeToFile="1"
      ;;
    s)
      writeToScreen="1"
      ;;
    *)
      echo "$OPTARG" parameter does not exists
      ;;
    esac
  done
  shift $(($OPTIND - 1))

  if [ "$file" = "?" ]; then
    i=0
    for arg in "$@"; do
      urls[i]="$arg"
    done
  fi
}

function downloadPages() {
  i=0
  for url in ${urls[*]}; do
    echo downloading "$url"...
    if [ -z ${pageNames[i]+x} ]; then
      pageNames[i]=$(wget -nv "$url" 2>&1 | cut -d\" -f2)
    else
      pageNames2[i]=$(wget -nv "$url" 2>&1 | cut -d\" -f2)
    fi
    i=$((i + 1))
  done
}

function writeResult() {
  localResult="A webpage under url $1 has $2 in given time"
  if [ "$writeToScreen" = "1" ]; then
    echo "$localResult"
  elif [ "$writeToFile" = "1" ]; then
    echo "$localResult" >>result.txt
  elif [ "$2" = "not changed" ]; then
     if [ "$browser" = "?" ]
     then
       xdg-open "$1"
     else
       echo "$1" | xargs "$browser"
     fi
  fi
}

removeFiles() {
  for pageName in ${1}; do
    rm "$pageName"
  done
}

function checkDiff() {
  i=0
  for name in ${pageNames[*]}; do
    result=$(diff "$name" "${pageNames2[i]}")
    if [ "$result" != "" ]; then
      writeResult "${urls[i]}" "changed"
    else
      writeResult "${urls[i]}" "not changed"
    fi

    i=$((i + 1))
  done

  removeFiles "${pageNames[@]}"
  pageNames=("${pageNames2[@]}")
}

function countingDown() {
  j=$timeout
  while ((j >= 0)); do
    echo "$j"...
    sleep 1
    j=$((j - 1))
  done
}

function mainFlow() {
  downloadPages "$@"
  countingDown
  downloadPages "$@"
  checkDiff
}

function runEventLoop() {
  while :; do
    mainFlow "$@"
  done
}

parseArguments "$@"

if [ "${#urls[@]}" -eq 0 ]; then
  echo "No urls to check"
  exit 0
elif [ "$runOnlyOnce" = "1" ]; then
  mainFlow "$@"
else
  runEventLoop "$@"
fi

removeFiles "${pageNames2[@]}"
