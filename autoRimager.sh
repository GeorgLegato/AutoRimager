#!/bin/bash
# Argument = -k 1 -k 3 -k10-20 -k0x16-0x20 -s albumwavs -t Intro.wav -t chapter1.wav -t chapter2.wav
#  -k0x56 -k0x7890 -k0x9876 -k0xABCDEF12 -k0x12345678

VERSION=0.3

# static configurations
PRODORDERTEMPL=ProdOrderTempl.xml
RECORDSTEMPL=RecordTempl.xml
LABELACTIONTEMPL=LabelTempl.xml
CDTEXT=cdtext.xml
LABELFILE=label.btw
MERGEFILE=merge.txt

AWT_ENC=./awt2_enc.exe

# runtime configurations
declare -a KEYS
SOURCEFOLDER=
declare -a TRACKS
VERBOSE=
RECORDS=
DEB=

Decho()
{
	if [[ ! -z $DEB ]]
	then
		echo $1
	fi	
}

EncodeWavFolder()
{
	# usage
	# $1 : source folder
	# $2 : encoding key (hexadecimal)

	ENCODEDWAVFOLDER=$2_dec_$(($2))
	echo "Creating encoded wav folder: $ENCODEDWAVFOLDER"

	mkdir "$ENCODEDWAVFOLDER"

	#@FIX: support whitespaces in the track filenames
	for f in "${TRACKS[@]}"
	do
		if [ ! -e "$SOURCEFOLDER/$f" ]
		then
			echo "Track $f missing"
			exit 10
		fi
	        "$AWT_ENC" "$SOURCEFOLDER/$f" "$ENCODEDWAVFOLDER/${f##*/}" $2
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
	for K in "${KEYS[@]}"
	do
		X=$(printf "0x%x" $K)
				
		if [[ ! -z $VERBOSE ]]
		then
			echo "Encoding from source folder: $SOURCEFOLDER tracks: ${TRACKS[@]} using key: $X"
		fi
		
		EncodeWavFolder "$SOURCEFOLDER" $X

		# do the ProductionOrder substitution
		PRODINST="$ENCODEDWAVFOLDER/ProdOrder_$ENCODEDWAVFOLDER.xml"

		local T=$CDTEXT

		if [[ "" != $CDTEXT ]]
		then
			CDTEXT=$(cygpath.exe -wa "$CDTEXT")
			CDTEXT="CD_Text_Filename=\"$CDTEXT\""
		fi

		RECORDS=
		for t in "${TRACKS[@]}"
		do	
			#ABSTRACKFILE and RECORDS is used within ProdXML template                  
			ABSTRACKFILE=$(cygpath.exe -wa "$ENCODEDWAVFOLDER/$t")

			RECORDS+=$(RenderTempl "$RECORDSTEMPL")

			#add a newline
			RECORDS+=$(echo)
		done
		
		#ORDERID is used within ProdXML template
		ORDERID="$SOURCEFOLDER_$ENCODEDWAVFOLDER"

		# process the Label file if exists
		if [ -e "$SOURCEFOLDER/$LABELFILE" ]
		then
			ABSLABELFILE=$(cygpath.exe -wa "$ENCODEDWAVFOLDER/$LABELFILE")
			ABSMERGEFILE=$(cygpath.exe -wa "$ENCODEDWAVFOLDER/$MERGEFILE")
			
			cp "$SOURCEFOLDER/$LABELFILE" $ABSLABELFILE
			printf "\"Nummer\"\\n\"%05d\"" $K > $ABSMERGEFILE  		
									
			LABELACTION=$(RenderTempl "$LABELACTIONTEMPL")
		else
			LABELACTION=		
		fi

		RenderTempl "$PRODORDERTEMPL" > "$PRODINST"

		CDTEXT=$T
	done
}

verboseVariables()
{
	if [[ ! -z $VERBOSE ]]
	then
		echo "--->Summary:"
		echo "	Keys (decimal): ${KEYS[@]}";
		echo "	CDTEXT: $CDTEXT";
		echo "	SOURCEFOLDER: $SOURCEFOLDER";
		echo "	TRACKS: ${TRACKS[@]}";
		echo
	fi
}

usage()
{
 cat << EOF
AutoRimager $VERSION, Copyright GeorgLegato, GPLV2
usage: $0 options

This script encodes waves using watermark and creates a Rimage production job for each encoded album 

OPTIONS:
    -h		Show this message
    -k<n>	Encoding key(s), repeatable, n: <dec | dec"-"dec | hex | hex"-"hex>
    -s		Source wav file folder 
    -t		Track filename order (as existing in source folder), repeatable
    -v		Verbose
    -d		Debug output
EOF
}

while getopts "dvhk:c:s:t:" OPTION
do
      case $OPTION in
          d)
              DEB="bla23459"
              ;;
          h)
              usage
              exit 1
              ;;
          k)
			Decho "raw OPTARG: $OPTARG";
            #XDIGIT=[a-zA-Z0-9]
            #DIGIT=[0-9]
 
			if [[ $OPTARG =~ (0x[a-zA-Z0-9]+)-(0x[a-zA-Z0-9]+) ]] 
			then
				Decho "keyrange hex: from: ${BASH_REMATCH[1]} to ${BASH_REMATCH[2]}"
				i=$((${BASH_REMATCH[1]}))
				j=$((${BASH_REMATCH[2]}))

				for ((;i<=j;i++))
				do
					KEYS=("${KEYS[@]}" $i)
				done
				
			elif [[ $OPTARG =~ ([0-9]+)-([0-9]+) ]] 
			then
				Decho "keyrange dec: from: ${BASH_REMATCH[1]} to ${BASH_REMATCH[2]}"
				i=${BASH_REMATCH[1]}
				j=${BASH_REMATCH[2]}

				for ((;i<=j;i++))
				do
					KEYS=("${KEYS[@]}" $i)
				done
			elif [[ $OPTARG =~ (0x[a-zA-Z0-9]+) ]];
			then
				Decho "xdigit found: $((${BASH_REMATCH[1]}))"        
				KEYS=("${KEYS[@]}" $((OPTARG)))
			elif [[ $OPTARG =~ ([0-9]+)$ ]]
			then
				Decho "decdigit found: $((${BASH_REMATCH[1]}))"
				KEYS=("${KEYS[@]}" $OPTARG)
			else
				Decho "key format error: $OPTARG"; exit 20; 
			fi
              ;;
          s)
			SOURCEFOLDER=$OPTARG
			#@FIX: assume cdtext.xml may be located next to the wav files (album folder), as replacement for the explicit parameter -c
			if [ -e "$SOURCEFOLDER/$CDTEXT" ]
			then
				CDTEXT="$SOURCEFOLDER/$CDTEXT"
			else
				CDTEXT=
			fi
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

if [[ -z "${KEYS[@]}" ]] || [[ -z $SOURCEFOLDER ]] || [[ -z $TRACKS ]]
then
	usage
	verboseVariables
	exit 1
fi

if [[ -z $CDTEXT ]]
then
	echo "Warning, no CDTEXT defined..."
fi

# all input parameters ok, start proceeding
verboseVariables
createEncodedWavs
