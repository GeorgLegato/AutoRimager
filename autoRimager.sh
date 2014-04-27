#!/bin/bash
# Argument = -k 1 -k 3 -k10-20 -k0x16-0x20 -s albumwavs -t Intro.wav -t chapter1.wav -t chapter2.wav
#  -k0x56 -k0x7890 -k0x9876 -k0xABCDEF12 -k0x12345678

VERSION=0.60

# static configurations
PRODORDERTEMPL=ProdOrderTempl.xml
RECORDSTEMPL=RecordTempl.xml
LABELACTIONTEMPL=LabelTempl.xml
LABELFILE=label.btw
MERGEFILE=merge.txt
ALLJOBSLIST=all.txt
CDTEXTNAME=cdtext.xml


AWT_ENC=./awt2_enc.exe

# runtime configurations
CDTEXT=
declare -a KEYS
SOURCEFOLDER=
declare -a TRACKS
declare -a ISRCCODES
VERBOSE=
RECORDS=
DEB=
OUTPUTFOLDER=
KEYLENGTH=4

source ./xmlbashing.sh

Decho()
{
	if [[ ! -z $DEB ]]
	then
		echo $1
	fi	
}



prepareISRCCodes()
{
	
	# 1st clear all codes matching to the amount of tracks, where index 0 is the album isrc (no sense)
	for (( i=0; i<${#TRACKS[@]}; i++ ))
	do
			ISRCODES[i+1]=""
	done	

	declare -a trackNumbers
	declare -a isrcs
	
	for TRNO in $(xml_read "$CDTEXT" TrackInfo TrackNumber)
	do
		trackNumbers=("${trackNumbers[@]}" $TRNO) 
	done

	for ISRC in $(xml_read "$CDTEXT" TrackInfo ISRC_Code)
	do
		isrcs=("${isrcs[@]}" $ISRC) 
	done
	
	for (( i=0; i<${#trackNumbers[@]}; i++ ))
	do
		local TNO=${trackNumbers[$i]}
		local ISRC=${isrcs[$i]}
		ISRCCODES[$TNO]="$ISRC"
	done	
	
	#echo "debug: All isrcs read from xml: ${ISRCCODES[@]}" 
	#for i in "${!ISRCCODES[@]}"
	#do
	#  echo "key  : $i"
	#  echo "value: ${ISRCCODES[$i]}"
	#done	
}


EncodeWavFolder()
{
	# usage
	# $1 : source folder
	# $2 : encoding key (hexadecimal)

	ENCODEDWAVFOLDER="$2_dec_$(($2))"
	echo "Creating encoded wav folder: $OUTPUTFOLDER/$ENCODEDWAVFOLDER"

	mkdir "$OUTPUTFOLDER/$ENCODEDWAVFOLDER" || exit 1;

	#@FIX: support whitespaces in the track filenames
	for f in "${TRACKS[@]}"
	do
		if [ ! -e "$SOURCEFOLDER/$f" ]
		then
			echo "Track $f missing"
			exit 10
		fi
	        "$AWT_ENC" "$SOURCEFOLDER/$f" "$OUTPUTFOLDER/$ENCODEDWAVFOLDER/${f##*/}" $2 || exit 1;
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
	if [[ -e $SOURCEFOLDER/$ALLJOBSLIST ]]
	then
		rm $SOURCEFOLDER/$ALLJOBSLIST || exit 1
	fi
	
	for K in "${KEYS[@]}"
	do
		local FORMAT="0x%0${KEYLENGTH}x"
		X=$(printf $FORMAT $K)
				
		if [[ ! -z $VERBOSE ]]
		then
			echo "Encoding from source folder: $SOURCEFOLDER tracks: ${TRACKS[@]} using key: $X"
		fi
		
		EncodeWavFolder "$SOURCEFOLDER" $X

		# do the ProductionOrder substitution
		PRODINST="$OUTPUTFOLDER/$ENCODEDWAVFOLDER/ProdOrder_$ENCODEDWAVFOLDER.xml"

		local T=$CDTEXT

		if [[ "" != $CDTEXT ]]
		then
			Decho "CDTEXT: $CDTEXT"
			Decho "EncodeFolder: $ENCODEDWAVFOLDER"
			
			local CDT="$OUTPUTFOLDER/$ENCODEDWAVFOLDER/$CDTEXTNAME"
			cp "$CDTEXT" "$CDT" || exit 1
			CDTEXT=$(cygpath.exe -wa "$CDT")
			CDTEXT="CD_Text_Filename=\"$CDT\""
		fi

		RECORDS=
		ISRCCODE=
		for (( i=0; i<"${#TRACKS[@]}"; ++i ))
		do	
			local t=${TRACKS[$i]}
			ISRCCODE=${ISRCCODES[$i+1]}

			#ABSTRACKFILE and RECORDS is used within ProdXML template                  
			ABSTRACKFILE=$(cygpath.exe -wa "$OUTPUTFOLDER/$ENCODEDWAVFOLDER/$t")

			RECORDS+=$(RenderTempl "$RECORDSTEMPL")

			#add a newline
			RECORDS+=$(echo)
		done
		
		#ORDERID is used within ProdXML template
		ORDERID="$SOURCEFOLDER_$ENCODEDWAVFOLDER"

		# process the Label file if exists
		if [ -e "$SOURCEFOLDER/$LABELFILE" ]
		then
			ABSLABELFILE=$(cygpath.exe -wa "$OUTPUTFOLDER/$ENCODEDWAVFOLDER/$LABELFILE")
			ABSMERGEFILE=$(cygpath.exe -wa "$OUTPUTFOLDER/$ENCODEDWAVFOLDER/$MERGEFILE")
			
			cp "$SOURCEFOLDER/$LABELFILE" $ABSLABELFILE || exit 1;
			printf "\"Nummer\"\\n\"%d\"" $K > $ABSMERGEFILE		
									
			LABELACTION=$(RenderTempl "$LABELACTIONTEMPL")
		else
			LABELACTION=		
		fi

		RenderTempl "$PRODORDERTEMPL" > "$PRODINST"
		
		# append to the all.txt 
		echo "$PRODINST" >> "$SOURCEFOLDER/$ALLJOBSLIST"

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
    -l		length of the encoding size (1,2,4,8,16, depends on your license)
    -s		Source wav file folder
    -o		Output folder, optional, default: same as source folder 
    -t		Track filename order (as existing in source folder), repeatable
    -v		Verbose
    -d		Debug output
EOF
}

while getopts "dvhk:c:s:t:o:l:" OPTION
do
      case $OPTION in
          d)
              DEB="1"
              ;;
          h)
              usage
              exit 1
              ;;
          l)
        		KEYLENGTH=$OPTARG
        		;;
       
          k)
			Decho "raw OPTARG: $OPTARG";
            #XDIGIT=[a-zA-Z0-9]
            #DIGIT=[0-9]
 
			if [[ $OPTARG =~ (0x[a-zA-Z0-9]+)-(0x[a-zA-Z0-9]+) ]] 
			then
				Decho "keyrange hex: from: ${BASH_REMATCH[1]} to ${BASH_REMATCH[2]}"
				#KEYLENGTH=$(expr ${#BASH_REMATCH[1]##0x} - 2)
				#Decho "detected keylength: $KEYLENGTH"
				
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
				#KEYLENGTH=$(expr ${#BASH_REMATCH[1]##0x} - 2)
				#Decho "detected keylength: $KEYLENGTH"
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
			if [ -e "$SOURCEFOLDER/$CDTEXTNAME" ]
			then
				CDTEXT="$SOURCEFOLDER/$CDTEXTNAME"
			else
				CDTEXT=
			fi
			;;			
          t)
              TRACKS=("${TRACKS[@]}" "$OPTARG")
              ;;
          o)
              OUTPUTFOLDER="$OPTARG"
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

if [[ -z $OUTPUTFOLDER ]]
then
	OUTPUTFOLDER="$SOURCEFOLDER"
fi

# all input parameters ok, start proceeding
verboseVariables
prepareISRCCodes
createEncodedWavs
