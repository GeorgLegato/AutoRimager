 #!/bin/bash

xml_read_dom()
{
# https://stackoverflow.com/questions/893585/how-to-parse-xml-in-bash
	local ENTITY IFS=\>
	if $ITSACOMMENT; then
	  read -d \< COMMENTS
	  COMMENTS="$(rtrim "${COMMENTS}")"
	  return 0
	else
	  read -d \< ENTITY CONTENT
	  CR=$?
	  [ "x${ENTITY:0:1}x" == "x/x" ] && return 0
	  TAG_NAME=${ENTITY%%[[:space:]]*}
	  ATTRIBUTES=${ENTITY#*[[:space:]]}
	fi
	
# when comments sticks to !-- :
	[ "x${TAG_NAME:0:3}x" == "x!--x" ] && COMMENTS="${TAG_NAME:3} ${ATTRIBUTES}" && ITSACOMMENT=true && return 0
	
# http://tldp.org/LDP/abs/html/string-manipulation.html
	[ "x${ATTRIBUTES:(-1):1}x" == "x/x" ] && ATTRIBUTES="${ATTRIBUTES: 0: ${#ATTRIBUTES}-1}" && return $CR
	[ "x${ATTRIBUTES:(-1):1}x" == "x?x" ] && ATTRIBUTES="${ATTRIBUTES: 0: ${#ATTRIBUTES}-1}" && return $CR
	return $CR

}

xml_read() 
{
# https://stackoverflow.com/questions/893585/how-to-parse-xml-in-bash
	! (($#)) && echo "${C}${FUNCNAME} ${c}[-d] <file.xml> [tag | \"any\"] [attribute | \"content\"]${N}${END}" && return 99
	
	local Debug=false
	[ "x$1" == "x-d" ] && Debug=true && shift
	[ ! -s "$1" ] && ERROR empty "$1" 0 && return 1
	tag=$2
	attribute=$3
	ITSACOMMENT=false
	
	while xml_read_dom; do
	  # (( CR != 0 )) && break
	  (( PIPESTATUS[1] != 0 )) && break
	
	  if $ITSACOMMENT; then
	    if [ "x${COMMENTS:(-2):2}x" == "x--x" ]; then COMMENTS="${COMMENTS:0:(-2)}" && ITSACOMMENT=false
	    elif [ "x${COMMENTS:(-3):3}x" == "x-->x" ]; then COMMENTS="${COMMENTS:0:(-3)}" && ITSACOMMENT=false
	    fi
	    $Debug && echo2 "${N}${COMMENTS}${END}"
	  elif test "${TAG_NAME}"; then
	    if [ "x${TAG_NAME}x" == "x${tag}x" -o "${tag}" == "any" ]; then
	      if [ "${attribute}" == "content" ]; then
	        CONTENT="$(trim "${CONTENT}")"
	        test "${CONTENT}" && echo "${CONTENT}"
	      else
	        eval local "$ATTRIBUTES"
	        $Debug && (echo2 "${m}${TAG_NAME}: ${M}$ATTRIBUTES${END}"; test ${CONTENT} && echo2 "${m}CONTENT=${M}$CONTENT${END}")
	        test "${attribute}" && test $(eval "echo \$${attribute}") && eval "echo \$${attribute}" && eval unset ${attribute}
	      fi
	    fi
	  fi
	  unset CR TAG_NAME ATTRIBUTES CONTENT COMMENTS
	done < "$1"
	unset ITSACOMMENT
}

rtrim() 
{
	local var=$@
	var="${var%"${var##*[![:space:]]}"}"   # remove trailing whitespace characters
	echo -n "$var"
}

trim() 
{
	local var=$@
	var="${var#"${var%%[![:space:]]*}"}"   # remove leading whitespace characters
	var="${var%"${var##*[![:space:]]}"}"   # remove trailing whitespace characters
	echo -n "$var"
}

echo2() 
{ 
	echo -e "$@" 1>&2; 
}

export -f echo2
export -f trim
export -f rtrim
export -f xml_read
export -f xml_read_dom
