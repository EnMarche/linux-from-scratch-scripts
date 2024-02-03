#!/bin/bash

while getopts ":c" opt; do
  case ${opt} in
    c )
      echo "Option -c passed"; 
      # Do something here when option -c is passed
      ;;
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      exit 1
      ;;
    : )
      echo "Option -$OPTARG requires an argument" 1>&2
      exit 1
      ;;
  esac
done
