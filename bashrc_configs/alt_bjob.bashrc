################################################################
## SPECIFIC TO SANGER, BUT COULD BE USED ON ANY LSF SYSTEM    ##
## BY DAMON-LEE B POINTON (DLBPointon)                        ##
## WRITTEN: 07/2025                                           ##
################################################################

# Customise the output of bjobs for more information - name defaults to 40
betterbj () {
        local name_max="${1:-40}"
        local user_name="${2:-${USER}}"
        local queue="${3:-}"
        bjobs -o "ID STAT QUEUE NAME:-${name_max} MAX_REQ_PROC:7 cpu_peak:7 memlimit:8 MEM:8 MAX_MEM:8 FIRST_HOST:-12 START_TIME delimiter='\'" -u ${user_name} ${queue}| sed 's/\\/\t/g' | sed 's/MA
X_REQ/CPU_REQ/g' | sed 's/CPU_PEA/CPU_USE/g' | sed 's/CPU_PEA/CPU_USE/g'
}

# Get the unique queues based on the jobs currently running
bjuniq_queues () {
        local name_max="${1:-40}"
        local user_name="${2:-${USER}}"
        betterbj ${name_max} ${user_name} | sed 1d | cut -f 3 | sort | uniq
}

# Get the BJOB data per queue, format, and colour it
# TODO: must be a better way of cleaning up the awk for colouring the output

# First Section of this deals with !oversubscribed queues
# Second Section only deals with the oversubscribed queue, this is so it is always last
#   - and has a longer name field so that we can see the name of the ticket running
bjdata () {
        local name_len="${1:-40}"
        local user_name="${2:-${USER}}"
        bjuniq=$(bjuniq_queues)
        odd_statuses=("DONE" "PSUSP" "USUSP" "SSUSP")
        for i in $bjuniq; do
                if [ "$i" != "oversubscribed" ]; then
                        echo "Group for: ${i^^}"
                        betterbj "$name_len" "$user_name" "-q ${i}" \
                                | awk 'BEGIN {
                                                FS="\t";
                                                OFS="\t";
                                        }
                                        {
                                                reset = "\033[0m"
                                                green = "\033[32m"
                                                yellow = "\033[33m"
                                                blue = "\033[34m"
                                                cyan = "\033[36m"
                                        }
                                        NR==1 { print; next }  # print header unchanged
                                        {
                                                if ($2 == "RUN")        $2 = green $2 reset
                                                else if ($2 == "PEND")  $2 = yellow $2 reset
                                                else                    $2 = red $2 reset

                                                if ($3 == "normal")             $3 = green $3 reset
                                                else if ($3 == "hugemem")       $3 = yellow $3 reset
                                                else if ($3 == "terramem")      $3 = red $3 reset
                                                else if ($3 == "oversubscribed") $3 = blue $3 reset
                                                else if ($3 == "week")          $3 = blue $3 reset
                                                else if ($3 == "long")          $3 = cyan $3 reset
                                                print
                                        }'
                fi
        done

        line_count=$(betterbj 1 | grep "oversubscribed" | wc -l)
        if [ $line_count != 0 ]; then
                echo "Group for: OVERSUBSCRIBED - uses alt function calls"
                betterbj 52 ${user_name} "-q oversubscribed" |  sed 's/sanger,singularity,production/S1,S2,P1\t\t/g' \
                        | awk 'BEGIN {
                                        FS="\t";
                                        OFS="\t";
                                        }
                                        {
                                                reset = "\033[0m"
                                                green = "\033[32m"
                                                yellow = "\033[33m"
                                                blue = "\033[34m"
                                                cyan = "\033[36m"
                                        }
                                                NR==1 { print; next }  # print header unchanged
                                        {
                                                if ($2 == "RUN")        $2 = green $2 reset
                                                else if ($2 == "PEND")  $2 = yellow $2 reset
                                                else                    $2 = red $2 reset

                                                if ($3 == "normal")                     $3 = green $3 reset
                                                else if ($3 == "hugemem")               $3 = yellow $3 reset
                                                else if ($3 == "terramem")              $3 = red $3 reset
                                                else if ($3 == "oversubscribed")        $3 = blue $3 reset
                                                else if ($3 == "long")                  $3 = cyan $3 reset
                                                else if ($3 == "week")                  $3 = blue $3 reset

                                                print
                                        }'
        fi
}

# CLI of the config
# Prints the bjob data
# Then prints out some stats like:
#   - Count of Jobs by STATUS and QUEUE
#   - Count of Jobs by STATUS
bjobber () {
        local width=40
        local user_name="$USER"

        while [[ $# -gt 0 ]]; do
                case "$1" in
                        -u|--user)
                                user_name=$2
                                shift 2;;
                        -w|--width)
                                width="$2"
                                shift 2;;
                        -h|--help)
                                echo "Usage: bjobber [-u USER] [-w WIDTH]"
                                echo " --user  | USERNAME to report on | default is \$USER"
                                echo " --width | WIDTH of bjob name as output | default is 40"
                                return 0
                                ;;
                        *)
                                echo "UNKOWN ARG: $i"
                                return 1
                                ;;
                esac
        done

        bjdata "$width" "$user_name"

        # Get count of jobs in queue AND status
        echo -e "\nJob Queue Counter\n"
        bjobs -o "queue stat" -u "$user_name" | awk '{ if ($1 != "QUEUE") print $2 "\t" $1}' | sort | uniq -c

        # Get raw count of jobs per status
        echo -e "\nStatus Counter\n"
        bjobs -o "stat" -u "$user_name" | awk '{ if ($1 != "STAT") print $1}' | sort | uniq -c
}
