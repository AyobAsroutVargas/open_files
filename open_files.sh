#!/bin/bash

###Constantes
TITLE="Script open_files"
HEADER="Users in who:"
OUTPUT_FORMAT="NAME NUMBER_OF_OPEN_FILES UID OLDEST_PROCESS_PID"
FILTER_TEXT="USING FILTER: "

#Estilos
TEXT_BOLD=$(tput bold)
TEXT_ULINE=$(tput sgr 0 1)
TEXT_GREEN=$(tput setaf 2)
TEXT_RESET=$(tput sgr0)

# Variables
Users=
offline_users=$(cut -d: -f1 /etc/passwd)
Filtro=
op_f=
op_o=0
op_u=0
number_of_users=0
tmp_user=
# Funcion para salir en caso de error.
error_exit()
{
        echo "$1" 1>&2
        exit 1
}

usage () 
{
	echo "usage: ./open_files.sh [-o/--offline] [-f filter] [-h/--help]"
}
#Funcion para comprobar que un usuario existe
check_user()
{
	id -u $1 &> /dev/null || error_exit "Error: The user $1 does not exist"
}
# Procesar la línea de comandos del script para leer las opciones 
while [ "$1" != "" ]; do
   case $1 in
       -h | --help )
            usage
           exit
           ;;
				-f )
						shift
						if [ "$1" = "" ];then
							error_exit "Error: After the -f option must come a filter"
						fi
						Filtro=$1
						op_f=1
					 ;;
				-o | --offline )
						if [ "$op_u" = "1" ];then
							error_exit "Error: -o and -u are incompatible options"
						else
							op_o=1
						fi
						echo $offline_users
					 ;;
				-u | --users )
						shift
						if [ "$op_o" = "1" ];then
							error_exit "Error: -o and -u are incompatible options"
						else
							op_u=1
							while [ "$1" != "" ] && [ "$1" != "-f" ];do
								if [ "$1" = "-o" ];then
									error_exit "Error: -o and -u are incompatible options"
								fi
								#Comprobamos que todos los usuarios insertados existen
								check_user $1
								Users="$Users $1"
								number_of_users=$(( $number_of_users + 1 ))
								shift
							done
							#Si leemos -f aplicamos la funcionalidad de dicha opcion porque me estaba dando errores raros
							if [ "$1" = "-f" ];then
								shift
								if [ "$1" = "" ];then
									error_exit "Error: After the -f option must come a filter"
								fi
								Filtro=$1
								op_f=1
							fi 
						fi
						;;
       * )
            error_exit "Error: option not supported"
   esac
   shift
done
# Funcion para contar los ficheros abiertos por un usuario
count_open_files()
{
	if [ "$op_f" = "1" ]; then
		#En lsof en los usuarios offline la ultima columna es un warning de permision denied
		#Por eso si añadimos el caracter $ siempre aparecera que hay 0 archivos abiertos
		if [ "$op_o" = "1" ] || [ "$op_u" = "1" ];then
			lsof -u $1 | grep $Filtro | wc -l
		else
			lsof -u $1 | grep $Filtro$ | wc -l
		fi
	else
		lsof -u $1 | wc -l
	fi
	
}
# Funcion para ver cual es el uid de un usuario
user_uid()
{
	id -u $1 
}
# Funcion para ver cual es el pid del proceso mas antiguo de un usuario
user_oldest_process_pid()
{
	# Si el usuario no tiene procesos en marcha lo indicamos en lugar de no poner nada
	if [ "$(ps --no-headers -U $1 -u $1 -o pid --sort=-etime| tr -d ' ' | head -1)" = "" ]; then
		echo $TEXT_GREEN"User currently has no processes running"$TEXT_RESET
	else
		ps --no-headers -U $1 -u $1 -o pid --sort=-etime| tr -d ' ' | head -1
	fi
}
# Funcion para ver si lsof esta instalado
is_lsof_installed()
{
	type lsof &> /dev/null || error_exit "The script requires lsof to be installed"
}
# Programa principal
$(is_lsof_installed)
# Si lsof no esta instalado salimos con codigo de salida 1
if [ "$?" = "1" ]; then
	error_exit "Try sudo apt-get install lsof"
else
	#Si no hemos recibido los usuarios mediante la opcion -u establecemos los usuarios como aquellos en who
	if [ "$op_u" = "0" ];then
			Users=$(who | cut -d " " -f 1 | sort | uniq)
		fi
	echo $TEXT_BOLD$TITLE$TEXT_RESET
	echo $TEXT_ULINE$HEADER$TEXT_RESET
	echo $TEXT_BOLD$TEXT_GREEN$OUTPUT_FORMAT$TEXT_RESET
	#El siguiente bloque solo se usa para formatear la informacion auxiliar
	if [ "$op_f" = "1" ];then
		if [ "$op_o" = "0" ] && [ "$op_u" = "0" ] ;then
			echo $TEXT_BOLD$FILTER_TEXT$TEXT_RESET$Filtro"$"
		else
			echo $TEXT_BOLD$FILTER_TEXT$TEXT_RESET$Filtro
		fi
	else
		echo $TEXT_BOLD"No filter being used"$TEXT_RESET
	fi

	#Si queremos usar los usuarios offline recorremos todos los usuarios e ignoramos los que aparezcan en who(Users, si no tenemos
	#la opcion -u activada)
	if [ "$op_o" = 1 ];then
		for element1 in $offline_users; do
			for element2 in $Users;do
				if [ $element1 = $element2 ]; then
					continue
				else
					echo $element1 $(count_open_files $element1) $(user_uid $element1) $(user_oldest_process_pid $element1)
				fi
			done
		done
	elif [ "$op_u" = 1 ];then
		for (( i=1; i<=number_of_users; i++ ));do
			tmp_user=$(echo $Users | cut -d " " -f $i)
			echo $tmp_user $(count_open_files $tmp_user) $(user_uid $tmp_user) $(user_oldest_process_pid $tmp_user)
		done
	else
		#Si la opción -o no está activada, trabajamos con los usuarios en users(los que salen en who si no se uso la opcion -u,
		# o los proporcionados por linea de comandos en caso contrario)
		for user in "$Users"; do
			echo $user $(count_open_files $user) $(user_uid $user) $(user_oldest_process_pid $user)
		done
	fi
fi
