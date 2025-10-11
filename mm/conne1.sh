#!/bin/bash
    clear
    echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "\E[44;1;37m            GERENCIAR BADVPN             \E[0m"
echo -e "\033[1;37m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo ""
    if ps x | grep -w udpvpn | grep -v grep 1>/dev/null 2>/dev/null; then
        echo -e "\033[1;37mPORTAS\033[1;37m: \033[1;32m$(netstat -nplt | grep 'badvpn-ud' | awk {'print $4'} | cut -d: -f2 | xargs)"
    else
        sleep 0.1
    echo ""
    echo -e "\033[1;31m[\033[1;36m1\033[1;31m] \033[1;37m• \033[1;37mBADVPN PRO $stsu\033[0m"
    echo -e "\033[1;31m[\033[1;36m2\033[1;31m] \033[1;37m• \033[1;37mBADVPN 2 \033[0m"
    echo -e "\033[1;31m[\033[1;36m3\033[1;31m] \033[1;37m• \033[1;37mBADVPN 3 \033[0m"
    echo -e "\033[1;31m[\033[1;36m4\033[1;31m] \033[1;37m• \033[1;37mBADVPN 4 ACKHTTP \033[0m"
    echo -e "\033[1;31m[\033[1;36m0\033[1;31m] \033[1;37m• \033[1;37mVOLTAR  \033[1;32m<\033[1;33m<\033[1;31m< \033[0m"
    echo ""
    echo -ne "\033[1;32mO QUE DESEJA FAZER \033[1;37m?\033[1;37m ";
			read x
			tput cnorm
			clear
			case $x in
			1 | 01)
			badvpn
			;;
			2 | 02)
			badvpn2
			;;
			3 | 03)
			badpro1
			;;
			4 | 04)
			badvpn3
			;;
			0 | 00)
			clear
			menu
			;;
			*)
			echo -e "\033[1;31mOpcao invalida !\033[0m"
			sleep 2
			;;
			esac
		done
	}
	fun_conexao
}
