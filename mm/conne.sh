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
    fi
    var_sks1=$(ps x | grep "udpvpn"|grep -v grep > /dev/null && echo -e "\033[1;32m◉ " || echo -e "\033[1;31m○ ")
    echo ""
    echo -e "\033[1;31m[\033[1;36m1\033[1;31m] \033[1;37m• \033[1;37mATIVAR BADVPN(PADRÃO 7300) $var_sks1 \033[0m"
    echo -e "\033[1;31m[\033[1;36m2\033[1;31m] \033[1;37m• \033[1;37mABRIR PORTA\033[0m"
    echo -e "\033[1;31m[\033[1;36m0\033[1;31m] \033[1;37m• \033[1;37mVOLTAR\033[0m"
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
    fi
    var_sks1=$(ps x | grep "udpvpn"|grep -v grep > /dev/null && echo -e "\033[1;32m◉ " || echo -e "\033[1;31m○ ")
    echo ""
    echo -e "\033[1;31m[\033[1;36m1\033[1;31m] \033[1;37m• \033[1;37mATIVAR BADVPN(PADRÃO 7300) $var_sks1 \033[0m"
    echo -e "\033[1;31m[\033[1;36m2\033[1;31m] \033[1;37m• \033[1;37mABRIR PORTA\033[0m"
    echo -e "\033[1;31m[\033[1;36m0\033[1;31m] \033[1;37m• \033[1;37mVOLTAR\033[0m"
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
