#!/bin/bash

set -e

# This should be set outside of this script
# SM2DIR="$HOME/code/sm-2-cli"

CFG="$SM2DIR/settings.json"
TMPFILE="$SM2DIR/settings.tmp"
CARDS=[]

USING_DEBUG_DATE=0

# TODO:
# - catch kill signal and clean up
# - also clean up on setup

# if date string passed in:
if [[ $# -gt 0 ]]
then
  # Got an argument
  USING_DEBUG_DATE=1
  echo "------DEBUG-----"
  echo "Date: $1"
  echo "------DEBUG-----"
  # Use the first argument as the debug 'last_run' date
  jq --arg LAST "$(date -d "$1" +%s)" '.debug_last_run = ($LAST | tonumber | todate)' $CFG > $TMPFILE
  mv $TMPFILE $CFG
fi

setup () {
  ## TODO: set up settings.json file if it's empty. CREATE IT if it's not present.
  # {
  #   "files": [],
  #   "last_run": "1921-06-30T00:00:00Z"
  # }

  clear -x
  # Loop through all cards in /cards directory, add any that we haven't seen yet
  # to the settings.
  shopt -s nullglob
  for f in $SM2DIR/cards/*
  do
    filename=$(basename $f)
    if [[ `jq --arg FILENAME "$filename" 'any(.files[].filename; .== $FILENAME)' $CFG` = true ]]
    then
      continue
      # Already in the config file, do nothing
    else
      # Add this entry to the list with default settings
      jq --arg FILENAME "$filename" '.files += [{"filename": $FILENAME, "n": 0, "EF": 2.5, "I": 0, "last_seen":"1921-06-28T00:00:00Z"}]' $CFG > $TMPFILE
      mv $TMPFILE $CFG
      echo "$filename added to config"
    fi
  done

  #let DAYS_SINCE_RUN=($(date +%s -d -)-$(date +%s -d "2021-06-27"))/86400
  # No. See below:
  # use jq for dates, since its apparently easier than mixing with UNIX's 'date'
  jq '.today = (now | todate)' $CFG > $TMPFILE
  mv $TMPFILE $CFG

  #### Welcome
  printf "\n###########\n"
  printf "\n### Welcome to spaced-repetition active recall with SM-2\n"

  if [[ USING_DEBUG_DATE -eq 1 ]]
  then
    DAYS_SINCE_RUN=`jq '((.today | fromdate) - (.debug_last_run | fromdate))/86400 | floor' $CFG`
    printf "\nDays since last review: $DAYS_SINCE_RUN"
    printf "\n(Last run on $(cat $CFG | jq '.debug_last_run | fromdate | strftime("%Y-%m-%d")'))"
  else
    DAYS_SINCE_RUN=`jq '((.today | fromdate) - (.last_run | fromdate))/86400 | floor' $CFG`
    printf "\nDays since last review: $DAYS_SINCE_RUN"
    printf "\n(Last run on $(cat $CFG | jq '.last_run | fromdate | strftime("%Y-%m-%d")'))"
  fi

  # TODO: Remove any cards from settings.json that _are not_ in /cards
  #       Or are broken symlinks. (and report these)
}


i_less_than_x_days_ago () {
  AGE=$1
  # find cards with I <= AGE in days
  CARDS=`jq -r --arg AGE "$AGE" '.files[] | select(.I <= ($AGE | tonumber)).filename' $CFG`
}

update_last_seen () {
  FILE=$1
  jq --arg FILENAME "$FILE" '(.files[] | select(.filename == $FILENAME)) |= . + { last_seen: (now | todate) }' $CFG > $TMPFILE
  mv $TMPFILE $CFG
}

update_q_only () {
  FILE=$1
  q=$2

  jq --arg FILENAME "$FILE" --arg Q "$q" '(.files[] | select(.filename == $FILENAME)) |= . + { last_q: ($Q | tonumber) }' $CFG > $TMPFILE
  mv $TMPFILE $CFG
}

update_sm2 () {
  FILE=$1
  q=$2

  n=$(jq --arg FILENAME "$FILE" '.files[] | select(.filename == $FILENAME).n' $CFG)
  EF=$(jq --arg FILENAME "$FILE" '.files[] | select(.filename == $FILENAME).EF' $CFG)
  I=$(jq --arg FILENAME "$FILE" '.files[] | select(.filename == $FILENAME).I' $CFG)

  # SM-2 algorithm
  if [[ $q -ge 3 ]]
  then
    if [[ $n -eq 0 ]]
    then
      NEW_I=1
    elif [[ $n -eq 1 ]]
    then
      NEW_I=6
    else
      NEW_I=$(echo - | awk -v I="$I" -v EF="$EF" '{print (I * EF);}')
    fi

    # Determine if new EF has to be forced to 1.3
    NEW_EF=$(echo - | awk -v q="$q" -v EF="$EF" '{print (EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02)));}')
    if awk -v EF="$NEW_EF" 'BEGIN {exit !(EF < 1.3)}'; then
      NEW_EF=1.3
    else
      NEW_EF=$NEW_EF
    fi

    let NEW_N=($n+1)
  else
    NEW_N=0
    NEW_I=1
    NEW_EF=$EF
  fi

  # Set new parameters
  jq --arg FILENAME "$FILE" --arg NEW_N "$NEW_N" --arg NEW_EF "$NEW_EF" --arg NEW_I "$NEW_I" --arg Q "$q" '(.files[] | select(.filename == $FILENAME)) |= . + { n: ($NEW_N | tonumber), EF: ($NEW_EF | tonumber), I: ($NEW_I | tonumber), last_q: ($Q | tonumber) }' $CFG > $TMPFILE
  mv $TMPFILE $CFG
}


run_cards() {
  # Fill up CARDS array:
  i_less_than_x_days_ago "$DAYS_SINCE_RUN"

  # Count today's cards for display
  FOR_TODAY=`jq -r --arg AGE "$DAYS_SINCE_RUN" '[ .files[] | select(.I <= ($AGE | tonumber)) ] | length' $CFG`

  printf "\n"
  printf "\n    You have $TOTAL_CARDS cards in your collection.\n"
  if [[ FOR_TODAY -eq 0 ]]
  then
    printf "\n    ...But none to show today.\n"
    printf "    Try again tomorrow!\n"
    printf "\n"
    exit 0
  else
    printf "\n    We'll show you $FOR_TODAY of them today\n"
    printf "\n"
    printf "\nPress any key to start.\n"
    read -n 1 advance
  fi

  for FILE in $CARDS
  do
    clear -x

    ask_card $FILE

    n=$(jq --arg FILENAME "$FILE" '.files[] | select(.filename == $FILENAME).n' $CFG)
    I=$(jq --arg FILENAME "$FILE" '.files[] | select(.filename == $FILENAME).I' $CFG)

    clear -x
    printf "\n###########\n"
    printf "### That was: '$FILE'\n"
    printf "\n    You've recalled this card $n times in a row."
    printf "\n    We will show it to you again in $I days."
    printf "\n\nPress any key for the next card.\n"

    read -n 1 advance
  done # CARDS for loop

  clear -x
  printf "\nYou've completed the main review\n"
  printf "Press any key to continue\n"
  read -n 1 continue
}

ask_card () { # $1 FILE, $2 RE_REVIEW
  FILE=$1
  RE_REVIEW=$2

  while true; do # y/n loop
    # Check if card has a divider - if so it's a flash card
    if grep -qE '([-]){3,}' $SM2DIR/cards/$FILE; then
      printf "\n###########\n"
      printf "\n### This is a flash card:\n"
      printf "\n"
      printf "\n"

      # show only the top half first:
      sed -E '/([-]){3,}/Q' $SM2DIR/cards/$FILE

      printf "\n"
      printf "\n###########\n"
      printf "### Press any key to reveal the whole card.\n"

      read -n 1 advance

      printf "\n"

      # show bottom half only
      # sed -E '1,/([-]){3,}/ d' $SM2DIR/cards/$FILE
      clear -x
    else
      printf "\n### This is not flash card:\n"
      printf "\n"
    fi

    printf "\n"
    cat "$SM2DIR/cards/$FILE"

    printf "\n"
    printf "\n"

    printf "\n###########\n"
    printf "### That was: '$FILE'\n"
    printf "\n- Press y if you recalled it correctly\n"
    printf "\n- Press n if you if you did not\n"
    printf "\n- (Press q to quit at any time)\n"
    printf "\n> "

    read -n 1 decision
    case $decision in
      [yY])
        clear -x
        printf "\n###########\n"
        printf "### That was: '$FILE'\n"
        printf "\n    Great, you recalled it.\n"
        printf "\n"
        printf "\nHow easy was it? (1-3)?\n"
        printf "\n1: Significant difficulty recalling.\n"
        printf "\n2: Some hesitation.\n"
        printf "\n3: Perfect recall.\n"
        printf "\n> "

        while true; do # 1-3 loop
          read -n 1 q

          case $q in
            [123])
              let q=($q+2)
              if [[ $RE_REVIEW -eq 1 ]]
              then
                update_q_only $FILE $q
              else
                update_sm2 $FILE $q
                update_last_seen $FILE
              fi
              break # 1-3 loop break
            ;;
            *)
              echo 'Please choose 1-3' >&2
            ;;
          esac
        done # 1-3 loop

        break # y/n loop break
      ;;
      [nN])

        echo "Sub 4: $SUB_4_CARDS"
        # TODO: add to sub-4 array
        SUB_4_CARDS+=($FILE)
        echo "Sub 4: $SUB_4_CARDS"

        clear -x
        printf "\n###########\n"
        printf "### That was: '$FILE'\n"
        printf "\n    You did not recall it.\n"
        printf "\n"
        printf "\nHow did it feel? (1-3)?\n"
        printf "\n1: Total blackout/failure to recall.\n"
        printf "\n2: Felt familiar after seeing answer.\n"
        printf "\n3: Seemed easy to remember after seeing answer.\n"
        printf "\n> "

        while true; do # 1-3 loop
          read -n 1 q

          case $q in
            [123])
              # Seems to be an issue with subtracting 1 from 1....
              if [[ "$q" -eq 1 ]]
              then
                q=0
              else
                let q=($q-1)
              fi

              if [[ $RE_REVIEW -eq 1 ]]
              then
                update_q_only $FILE $q
              else
                update_sm2 $FILE $q
                update_last_seen $FILE
              fi

              break # 1-3 loop break
            ;;
            *)
              echo 'Please choose 1-3' >&2
            ;;
          esac
        done # 1-3 loop

        break # y/n loop break
      ;;
      q*)
        printf "\nCleaning up and quitting...\n"
        # TODO
        break # y/n/q loop break
      ;;
      *)
        echo 'Invalid input' >&2
      ;;
    esac
  done
}

re_run_sub_fours () {
  # If any cards have their last_q as < 4,
  # re-ask them until they're all >= 4
  clear -x

  SUB_4_COUNT=`jq -r '[ .files[] | select(.last_q < (4 | tonumber)) ] | length' $CFG`

  printf "\n###########\n"
  printf "### Now you'll review $SUB_4_COUNT cards that were\n"
  printf "    giving you a hard time this session.\n"
  printf "    You'll see them repeatedly until your recall is good.\n"

  printf "\n"
  printf "\nPress any key to continue\n"
  read -n 1 continue

  # SUB_4_Qs=`jq -r '[ .files[] | select(.last_q < (4 | tonumber)) ] | length' $CFG`
  while [[ `jq -r '[ .files[] | select(.last_q < (4 | tonumber)) ] | length' $CFG` -gt 0 ]]; do
    SUB_4=`jq -r --arg AGE "$AGE" '.files[] | select(.last_q < (4 | tonumber)).filename' $CFG`

    for FILE in $SUB_4
    do
      clear -x
      SUB_4_COUNT=`jq -r '[ .files[] | select(.last_q < (4 | tonumber)) ] | length' $CFG`
      printf "\n($SUB_4_COUNT review cards left) \n"
      ask_card $FILE 1
    done
  done

  clear -x
  printf "\n###########\n"
  printf "### Reinforcement complete!\n"
  printf "\n"

  printf "\nPress any key to continue\n"
  read -n 1 continue
}

exit_if_no_cards () {
  TOTAL_CARDS=`cat $CFG | jq '.files | length'`

  if [[ "$TOTAL_CARDS" -lt 1 ]]; then
    printf "\n\nWe have no cards. Add or symlink to /cards\n"
    exit 1
  fi
}

# 0: "Total blackout", complete failure to recall the information.
# 1: Incorrect response, but upon seeing the correct answer it felt familiar.
# 2: Incorrect response, but upon seeing the correct answer it seemed easy to remember.
# 3: Correct response, but required significant difficulty to recall.
# 4: Correct response, after some hesitation.
# 5: Correct response with perfect recall.

#algorithm SM-2 is
#    input:  user grade q
#            repetition number n
#            easiness factor EF
#            interval I
#    output: updated values of n, EF, and I
#
#    if q ≥ 3 (correct response) then
#        if n = 0 then
#            I ← 1
#        else if n = 1 then
#            I ← 6
#        else
#            I ← ⌈I × EF⌉
#        end if
#        EF ← EF + (0.1 − (5 − q) × (0.08 + (5 − q) × 0.02))
#        if EF < 1.3 then
#            EF ← 1.3
#        end if
#        increment n
#    else (incorrect response)
#        n ← 0
#        I ← 1
#    end if
#
#    return (n, EF, I)


cleanup () {
  clear -x
  printf "\n###########\n"
  printf "\n### Cleaning up...\n"
  # move 'today' to 'last_run' field
  jq '.last_run = .today' $CFG > $TMPFILE
  mv $TMPFILE $CFG

  # remove 'today' field
  jq 'del(.today)' $CFG > $TMPFILE
  mv $TMPFILE $CFG

  # If we were debugging, remove the debug field
  if [[ USING_DEBUG_DATE -eq 1 ]]
  then
    jq 'del(.debug_last_run)' $CFG > $TMPFILE
    mv $TMPFILE $CFG
  fi
  printf "\n    All done.\n"
  printf "\n    See you tomorrow!\n"
  printf "\n"
}


setup
exit_if_no_cards
run_cards

SUB_4_COUNT=`jq -r '[ .files[] | select(.last_q < (4 | tonumber)) ] | length' $CFG`
if [[ $SUB_4_COUNT -gt 0 ]]
then
  re_run_sub_fours
fi

cleanup

exit 0
