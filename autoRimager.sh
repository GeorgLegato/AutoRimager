#!/bin/bash
# sh ./_DEBUG.sh
# Argument = -k 1 -k 3 -k10-20 -k0xf-0x11 -c ./wavs/cdtext.xml -s ./wavs -t Intro.wav -t chapter1.wav -t chapter2.wav

# static configurations
PRODORDERTEMPL=ProdOrderTempl.xml
RECORDSTEMPL=RecordTempl.xml

# runtime configurations
KEYS=
CDTEXT=
SOURCEFOLDER=
declare -a TRACKS
VERBOSE=
RECORDS=

EncodeWavFolder()
{
	# usage
	# $1 : source folder
	# $2 : encoding key (hexadecimal)
	
	ENCODEDWAVFOLDER=$2_dec_$(($2))
	echo "Creating encoded wav folder: $ENCODEDWAVFOLDER"
	
	mkdir $ENCODEDWAVFOLDER
	
	for f in "${TRACKS[@]}"
	do
		if [ ! -e "$SOURCEFOLDER/$f" ]
		then
			echo "Track $f missing"
			exit 10
		fi
	        ./awt2_enc_x64.exe "$SOURCEFOLDER/$f" "$ENCODEDWAVFOLDER/${f##*/}" $2
	done
}

RenderTempl()
{
eval "cat <<EOF
$(<$1)
EOF
" 2> /dev/null
}

createEncodedWavs()
{
	for K in ${KEYS[@]}
	do
		X=$(printf "0x%x" $K)
		if [[ ! -z $VERBOSE ]]
		then
			echo "Encoding from sourcefolder: $SOURCEFOLDER tracks: ${TRACKS[@]} using key: $X"
		fi
		
		EncodeWavFolder $SOURCEFOLDER $X
		
		# do the ProductionOrder substitution
		PRODINST="$ENCODEDWAVFOLDER/ProdOrder_$ENCODEDWAVFOLDER.xml"
		
		local T=$CDTEXT

		if [[ "" != $CDTEXT ]]
		then
			CDTEXT=$(cygpath.exe -wa $CDTEXT)
			CDTEXT="CD_Text_Filename=\"$CDTEXT\""
		fi

		RECORDS=
		for t in "${TRACKS[@]}"
		do		
			ABSTRACKFILE=$(cygpath.exe -wa "$ENCODEDWAVFOLDER/$t")
			RECORDS+=`RenderTempl "$RECORDSTEMPL"`
			RECORDS+=`echo`
		done
		
		ORDERID="$SOURCEFOLDER_$ENCODEDWAVFOLDER"

		RenderTempl "$PRODORDERTEMPL" > "$PRODINST"
		
		CDTEXT=$T
	done
}

verboseVariables()
{
	if [[ ! -z $VERBOSE ]]
	then
		echo "Keys (decimal): ${KEYS[@]}";
		echo "CDTEXT: $CDTEXT";
		echo "SOURCEFOLDER: $SOURCEFOLDER";
		echo "TRACKS: ${TRACKS[@]}";
	fi
}

usage()
{
 cat << EOF
 usage: $0 options

This script encodes waves using watermark and creates a Rimage production job for each encoded album 

OPTIONS:
    -h      Show this message
    -k     encoding key, start
    [-l]   encoding key, end (incl.) optional
    [-c]    CDTEXT xml file (see rimage dtd), optional
    -s      source wav file folder 
    -t      track filename order (as existing in source folder), repeatable
    -v      Verbose
EOF
}

while getopts "vhk:c:s:t:" OPTION
do
      case $OPTION in
          h)
              usage
              exit 1
              ;;
          k)
			echo "raw OPTARG: $OPTARG";
            #XDIGIT=[a-zA-Z0-9]
            #DIGIT=[0-9]
 
			if [[ $OPTARG =~ (0x[a-zA-Z0-9]+)-(0x[a-zA-Z0-9]+) ]] 
			then
				echo "keyrange hex: from: ${BASH_REMATCH[1]} to ${BASH_REMATCH[2]}"
				i=$((${BASH_REMATCH[1]}))
				j=$((${BASH_REMATCH[2]}))
				
				for ((;i<=j;i++))
				do
					KEYS=("${KEYS[@]}" $i)
				done
				
			elif [[ $OPTARG =~ ([0-9]+)-([0-9]+) ]] 
			then
				echo "keyrange dec: from: ${BASH_REMATCH[1]} to ${BASH_REMATCH[2]}"
				i=${BASH_REMATCH[1]}
				j=${BASH_REMATCH[2]}
				
				for ((;i<=j;i++))
				do
					KEYS=("${KEYS[@]}" $i)
				done
			elif [[ $OPTARG =~ (0x[a-zA-Z0-9]+) ]];
			then
				echo "xdigit found"        
				KEYS=("${KEYS[@]}" $(($OPTARG)))
			elif [[ $OPTARG =~ ([0-9]+)$ ]]
			then
				echo "decdigit found"
				KEYS=("${KEYS[@]}" $OPTARG)
			else
				echo "key format error: $OPTARG"; exit 20; 
			fi
              ;;
          c)
              CDTEXT="$OPTARG"
              ;;
          s)
              SOURCEFOLDER=$OPTARG
              ;;
          t)
              TRACKS=("${TRACKS[@]}" "$OPTARG")
              ;;
          v)
              VERBOSE=1
              ;;
          ?)
              usage
              exit
              ;;
      esac
 done

if [[ -z ${KEYS[@]} ]] || [[ -z $SOURCEFOLDER ]] || [[ -z $TRACKS ]]
then
	usage
	verboseVariables
	exit 1
fi

if [[ -z $KEY2 ]]
then
	KEY2=$KEY1
fi

if [[ -z $CDTEXT ]]
then
	echo "Warning, no CDTEXT defined..."
fi

# all input parameters ok, start proceeding
verboseVariables
createEncodedWavs
