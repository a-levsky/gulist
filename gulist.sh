#!/bin/bash

#Script for displaying all the groups a user belongs to or all the users in a group (and the other groups that they belong to)
#Group listing requires that GROUP_FILE and PASSWD_FILE point to the correct locations
#Current GROUP_FILE and PASSWD_FILE values are based on Linux defaults

#Only users belonging to a group in a secondary group capacity are listed in the group's entry in the GROUP_FILE file
#If a user belongs to a group in a primary group capacity they will not be displayed under the group's entry in the GROUP_FILE file

#If script is run with the -g option it will first create an array of users belonging to the group in a secondary capacity
#Script will then cross-reference the specified group's group id in the GROUP_FILE with the primary group id of all users in the PASSWD_FILE
#If a match is found the matched user will also be appended to the array of users belonging to that group

#Execute with -u [user_name] for individual users
#Execute with -g [group_name] for groups

#GROUP_FILE and PASSWD_FILE are based on defaults, change them here if need be
GROUP_FILE="/etc/group"
PASSWD_FILE="/etc/passwd"

function groupList {
  GROUP_NAME=$1

  #Determine GROUP_ID of the group by querying GROUP_FILE
  GROUP_ID="$(grep ^$GROUP_NAME: $GROUP_FILE | cut -d ":" -f3 | sed 's/,/ /g')"

  #Extract all users belonging to the group in a secondary capacity and add them to USERS array
  GROUP_EXTRACT="grep :$GROUP_ID: $GROUP_FILE | cut -d\":\" -f4 | sed 's/,/ /g'"

  read -ra USERS <<<$(eval $GROUP_EXTRACT)

  #Read every line of PASSWD_FILE and compare users' primary group ids to the id of the specified group
  #Add matching users to USERS array
  while IFS= read -r passwd_entry
  do
    if [ "$GROUP_ID"  == "$(cut -d ":" -f4 <(echo \"$passwd_entry\"))" ]; then
      USERS+=("$(cut -d ":" -f1 <(echo "$passwd_entry"))")
    fi
  done < $PASSWD_FILE

  #Throw error if no users found for specified group
  if [ ${#USERS[@]} -eq 0 ]; then
    printf "\nERROR: no users found for group \"$GROUP_NAME\"\n\n"
    exit 1
  fi

  #Remove duplicate entries from USERS array
  UNIQUE_USERS=$(echo "${USERS[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')

  #Display all users belonging to the group in a primary and secondary capacity
  for USER in ${UNIQUE_USERS[@]}
  do
    userList $USER
  done
}

function userList {
  USERNAME=$1

  #Check to see if inputted username exists in /etc/passwd file
  if grep -q $USERNAME: $PASSWD_FILE; then

    NAME_SIZE=${#USERNAME}
    read -ra ROLES <<<$(id -Gn $1)
    ROLES_SIZE=${#ROLES[@]}
    LAST=$(( ROLES_SIZE - 1 ))

    RED='\033[1;31m'
    YELLOW='\033[1;33m'
    GREEN='\033[1;32m'
    NC='\033[0m'

    #User's roles are counted before appropriate listing is displayed
    if [ $ROLES_SIZE -eq 0 ]; then
      printf "${GREEN}$USERNAME${NC} is not a member of any groups"
    elif [ $ROLES_SIZE -eq 1 ]; then
      printf "${GREEN}$USERNAME${NC}───${RED}${ROLES[0]}${NC}\n\n"
    else
      printf "${GREEN}$USERNAME${NC}─┬─${RED}${ROLES[0]}${NC}\n"
      for (( i=1; i<${ROLES_SIZE}; i++ ));
      do
        #Print spaces to reflect size of username
        for (( h=0; h<=${NAME_SIZE}; h++ ));
        do
          printf " "
        done

        #Print secondary role name based on its position in role list
        if [ $i -eq $LAST ]; then
          printf "└─${YELLOW}${ROLES[$i]}${NC}\n\n"
        else
	  printf "├─${YELLOW}${ROLES[$i]}${NC}\n"
        fi

      done
    fi
  else
    printf "\nERROR: no user found for username "$USERNAME"\n\n"
    exit 1
  fi
}

#Error checking to ensure proper number of arguments is entered
if [ $# -ne 2 ]; then
  printf "\nERROR: invalid number of arguments\n\n"
  exit 1
fi

#Inputted options are validated
while getopts g:u o
do case "$o" in
    g)    groupList $2;;
    u)    userList $2;;
    [?])  printf "\nERROR: invalid option please use -g -u options\n\n"
	  exit 1
   esac
done
