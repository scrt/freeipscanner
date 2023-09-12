#!/usr/bin/env bash

function get_subnet_ip_addresses() {
    if [ $# -ne 1 ]; then echo "Missing argument"; return 1; fi

    # Get network interface information
    i_info=$(ip -o -f inet addr show $1)
    if [ $? -ne 0 ]; then return 1; fi

    # Suppress redundant spaces
    i_info=$(echo "$i_info" | sed s/' '+/' '/g)
    i_info_arr=(${i_info// / })

    # Extract IP address and broadcast address
    i_name=${i_info_arr[1]}     # eth0
    i_ip_cidr=${i_info_arr[3]}  # 192.168.140.136/24
    i_brd=${i_info_arr[5]}      # 255.255.255.0

    # Extract IP address and CIDR
    i_ip_cidr_arr=(${i_ip_cidr//\// })
    i_ip=${i_ip_cidr_arr[0]}    # 192.168.140.136
    i_cidr=${i_ip_cidr_arr[1]}  # 24

    # Build network mask from CIDR
    if [ $((i_cidr)) -lt 8 ]; then
        mask_arr=($((256-2**(8-i_cidr))) 0 0 0)
    elif [[ $((i_cidr)) -lt 16 ]]; then
        mask_arr=(255 $((256-2**(16-i_cidr))) 0 0)
    elif [[ $((i_cidr)) -lt 24 ]]; then
        mask_arr=(255 255 $((256-2**(24-i_cidr))) 0)
    elif [[ $((i_cidr)) -lt 32 ]]; then
        mask_arr=(255 255 255 $((256-2**(32-i_cidr))))
    elif [[ ${i_cidr} == 32 ]]; then
        mask_arr=(255 255 255 255)
    fi

    # Apply the network mask to the IP address to get the subnet IP adddress
    i_brd_arr=(${i_brd//./ })
    i_ip_arr=(${i_ip//./ })
    net_ip_arr=($(( mask_arr[0] & i_ip_arr[0] )) $(( mask_arr[1] & i_ip_arr[1] )) $(( mask_arr[2] & i_ip_arr[2] )) $(( mask_arr[3] & i_ip_arr[3] )))

    # Loop through all values from subnet address to broadcast address.
    for b1 in $(seq ${net_ip_arr[0]} ${i_brd_arr[0]}); do
        for b2 in $(seq ${net_ip_arr[1]} ${i_brd_arr[1]}); do
            for b3 in $(seq ${net_ip_arr[2]} ${i_brd_arr[2]}); do
                for b4 in $(seq ${net_ip_arr[3]} ${i_brd_arr[3]}); do
                    echo "$b1.$b2.$b3.$b4"
                done
            done
        done
    done
    return 0
}

function test_free_ip() {
    interface=$1
    ip=$2
    printf "[*] Testing : $ip\n"
    arping $ip -c 1 -I $interface -q
    if [ $? -eq 1 ] 
    then
        # arping didn't return a result, so we attempt a lookup
        names=$(dig -x $ip +short)
        if [ ${#names} -gt 0 ]
        then
            printf "\033[0;32m[+]\033[0m Found free IP : $ip with following name(s)\n"
            printf "\033[0;32m$names\n\033[0m"
        fi
    fi
}

export -f test_free_ip

if [ $# -ne 1 ]; then echo "Missing argument, please supply network interface"; exit 1; fi
interface=$1
get_subnet_ip_addresses $interface | xargs -P 10 -I {} bash -c "test_free_ip $interface {}"

