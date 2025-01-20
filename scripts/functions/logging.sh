#!/usr/bin/env bash
# logging.sh - Functions to define logging utilities.
# shellcheck disable=SC2034

# Colors
readonly END="\033[0m" ;
readonly BLACK="\033[0;30m" ;
readonly BLACKB="\033[1;30m" ;
readonly WHITE="\033[0;37m" ;
readonly WHITEB="\033[1;37m" ;
readonly RED="\033[0;31m" ;
readonly REDB="\033[1;31m" ;
readonly GREEN="\033[0;32m" ;
readonly GREENB="\033[1;32m" ;
readonly YELLOW="\033[0;33m" ;
readonly YELLOWB="\033[1;33m" ;
readonly BLUE="\033[0;34m" ;
readonly BLUEB="\033[1;34m" ;
readonly PURPLE="\033[0;35m" ;
readonly PURPLEB="\033[1;35m" ;
readonly LIGHTBLUE="\033[0;36m" ;
readonly LIGHTBLUEB="\033[1;36m" ;

# Print info messages
# Arguments:
#   $1 - The message to be displayed
function print_info {
  echo -e "${BLUEB}[INFO]${END} ${1}" ;
}

# Print warning messages
# Arguments:
#   $1 - The message to be displayed
function print_warning {
  echo -e "${YELLOWB}[WARNING]${END} ${1}" ;
}

# Print debug messages
# Arguments:
#   $1 - The message to be displayed
function print_debug {
  echo -e "${LIGHTBLUEB}[DEBUG]${END} ${1}" ;
}

# Print success messages
# Arguments:
#   $1 - The message to be displayed
function print_success {
  echo -e "${GREENB}[SUCCESS]${END} ${1}" ;
}

# Print error messages
# Arguments:
#   $1 - The message to be displayed
function print_error {
  echo -e "${REDB}[ERROR]${END} ${1}" ;
}

# Print command messages
# Arguments:
#   $1 - The message to be displayed
function print_command {
  echo -e "${PURPLEB}[COMMAND]${END} ${1}" ;
}