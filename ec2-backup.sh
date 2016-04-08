#!/bin/bash

dir=${@:-1}

# extract command line options with getopt
while getopts :hm:v: opt
do
	case "$opt" in
	h) echo "output help" ;;
	m) echo "option m with value $OPTARG" ;; 	 
	v) echo "option v with value $OPTARG" ;;
	*) echo "Unknown option: $opt" ;;	
	esac
done

