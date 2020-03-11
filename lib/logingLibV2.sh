#!/bin/bash
#
#
#                       logingLibV2.sh
#
#		This script contains the functions used to send messages to a log file  
#		and send the log file by email 
#		It also manages 3 alert levels : INFORMATION, WARNING and ERROR
#		The library will remember the highest level used (it starts on INFORMATIOn, when the first WARNNING message is printed
##		it will change to WARNNING until an ERROr message is printed when it will change to ERROR)
#		
#		The functions included are :

# setLogFile
## This function sets the name of the logfile to be used by all the rest
##	Arguments :
##				$1 : A string with the full name (path + filename) of the log file

# initLogFile
## This function clears a log file

# printInfo
## This function prints an information message to the log file 
## This means that the message will have the date and the string "## INFO  :" concatenated at the begining
##	Arguments :
##				$1 : A string with the message we want to print

# printWarning
## This function prints a warning message to the log file 
## This means that the message will have the date and the string "## WARN  : " concatenated at the begining
##	Arguments :
##				$1 : A string with the message we want to print

# printError
## This function prints a warnning message to the log file 
## This means that the message will have the date and the string "## ERROR  :" concatenated at the begining
##	Arguments :
##				$1 : A string with the message we want to print

# catLog
## This function will concatenate to the log file any other file you sent as an argument
## It will add a separator at the beginning and end of the file 
##	Arguments :
##				$1 : A string with the full name (path + filename) of the file we want to cat

# sendEmail
## This function will send an email to the corresponding distribution list depending on alert level
## Distribution list indicate the minimun level of alert for which the user will get the email
## So people on the INFO_RECIP_LIST will get emails for INFO,WARNING and ERROR. People on the WARNING_RECIP_LIST will
## get emails for WARNING and ERROR (but not for info) and people on the ERROR_RECIP_LIST will emails only for errors
## 
## When no recipients are found for the current alert level no email will be sent
## The email will contain the LOG File as an attachement and an  optional body sent as the second parameter 
## Arguments : 
##				$1 : Subject of the email 
##				$2 : Body for the email 

# abortOnError
## This function is used to abort the script execution. Log it on the logfile and mail the log file
## I know it is perhaps too much for only one function......
## Arguments
##				$1 : Subject of the email 
##				$2 : Body for the email 

# printSeparator
## This function just print a separator on the log file



#  /**********************************/
# /* 	Logging library             */
#/**********************************/

# This will have an standar name. Which can be changed (this way I make sure I always have a defined name
# Name of the script with the date, simple enough
LOG_FILE=${0}_`date +"%y.%m.%d_%H%M"`.log

# These "constants" define de different alert levels
LOG_INFO=0
LOG_WARNING=1
LOG_ERROR=2

## Nice (long) description for the alert levels. To be use when sending the log by email
alertLvlDesc=([${LOG_INFO}]="INFORMATION" [${LOG_WARNING}]="WARNING" [${LOG_ERROR}]="ERROR")

## This is the current alert level. These variable gets updated when a new line is added to the log file
## with it's corresponding alert level
## It starts on INFO. 
LOG_CURR_ALERT=${LOG_INFO}


# setLogFile
## This function sets the name of the logfile to be used by all the rest
##	Arguments :
##				$1 : A string with the full name (path + filename) of the log file
function setLogFile() {
	LOG_FILE=$1
}

# initLogFile
## This function clears a log file
function initLogFile() {
	echo "" > ${LOG_FILE}
	LOG_CURR_ALERT=${LOG_INFO} ## Reset also the alert level
}

# printInfo
## This function prints an information message to the log file 
## This means that the message will have the date and the string "## INFO  :" concatenated at the begining
##	Arguments :
##				$1 : A string with the message we want to print
function printInfo {
	echo "`date +"%D %H:%M:%S"` ## INFO  :${1}" >> ${LOG_FILE}
}

 

# printWarning
## This function prints a warning message to the log file 
## This means that the message will have the date and the string "## WARN  : " concatenated at the begining
##	Arguments :
##				$1 : A string with the message we want to print
function printWarning {
	echo "`date +"%D %H:%M:%S"` ## WARN  :${1}" >> ${LOG_FILE}
	## If the alert level is not error (ie it is info or warning..not much difference at this time)
	## set the alert level to WARNING
	if [ LOG_CURR_ALERT != ${LOG_ERROR} ]; then
		LOG_CURR_ALERT=${LOG_WARNING}
	fi
}

# printError
## This function prints a warnning message to the log file 
## This means that the message will have the date and the string "## ERROR  :" concatenated at the begining
##	Arguments :
##				$1 : A string with the message we want to print
function printError {
	echo "`date +"%D %H:%M:%S"` ## ERROR :${1}" >> ${LOG_FILE}
	## No need to check here :)
	LOG_CURR_ALERT=${LOG_ERROR}
}


# catLog
## This function will concatenate to the log file any other file you sent as an argument
## It will add a separator at the beginning and end of the file 
##	Arguments :
##				$1 : A string with the full name (path + filename) of the file we want to cat
function catLog() {
	echo "------------------------------------------------------------------------" >> ${LOG_FILE}
	cat ${1} 2>> ${LOG_FILE}  >>  ${LOG_FILE}
	echo "------------------------------------------------------------------------" >> ${LOG_FILE}
}



# abortOnError
## This function is used to abort the script execution. Log it on the logfile and mail the log file
## I know it is perhaps too much for only one function......
## Arguments
##				$1 : Subject of the email 
##				$2 : Body for the email 
function abortOnError {

	## Tell everybody I'm getting the hell out of here
	printError "Exiting..."
	sendEmail "${1}" "${2}"
	exit 1	

}


# printSeparator
## This function just print a separator on the log file
function printSeparator {
        echo "------------------------------------------------------------------------" >> ${LOG_FILE}

}

# concatenateRecipList
## This function will concatenate 2 recipient lists (any of those or both can  be empty) 
## and return the new string on it's output so the function shoul be called RESULT=$(concatenateRecipList $RECIP1 $RECIP2)
function concatenateRecipList {
	
	## If both have somethig we need a separator!
	if [ -n "${1}" ] && [ -n "${2}" ]; then
		SEPARATOR=","
	fi

	echo "${1}${SEPARATOR}${2}"
}


# sendEmail
## This function will send an email to the corresponding distribution list depending on alert level
## Distribution list indicate the minimun level of alert for which the user will get the email
## So people on the INFO_RECIP_LIST will get emails for INFO,WARNING and ERROR. People on the WARNING_RECIP_LIST will
## get emails for WARNING and ERROR (but not for info) and people on the ERROR_RECIP_LIST will emails only for errors
## 
## When no recipients are found for the current alert level no email will be sent
## The email will contain the LOG File as an attachement and an  optional body sent as the second parameter 
## Arguments : 
##				$1 : Subject of the email 
##				$2 : Body for the email 
function sendEmail {

	FINAL_RECIP_LIST=""

	## Build final recipient list depending on Alert level
	case ${LOG_CURR_ALERT} in 
	${LOG_INFO}) # Only the INFO
		FINAL_RECIP_LIST=${INFO_RECIP_LIST}
		;;
	${LOG_WARNING}) # Here we concatenate INFO and WARNING
		FINAL_RECIP_LIST=$(concatenateRecipList ${INFO_RECIP_LIST} ${WARNING_RECIP_LIST})	
		;;
	${LOG_ERROR}) ## And here all three
		FINAL_RECIP_LIST=$(concatenateRecipList $(concatenateRecipList ${INFO_RECIP_LIST} ${WARNING_RECIP_LIST}) ${ERROR_RECIP_LIST})
		;;
	esac

	if  [ -n "${FINAL_RECIP_LIST}" ]; then
		## Send email- If it fails I'll cat the error to the log (it is not much but it is something
		echo "$2" | mutt  -s "${1} - ALERT LEVEL = ${alertLvlDesc[${LOG_CURR_ALERT}]}" -a ${LOG_FILE} -- ${FINAL_RECIP_LIST} 2>&1 >> ${LOG_FILE}
	fi
}

