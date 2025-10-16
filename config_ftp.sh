#!/bin/bash

#se for para ser usado como root#

if [[ $EUID -ne 0 ]];then
	echo "Tem de entrar como root para executar isto"
	exit 1
fi

#FTP#

echo "========================================"
echo 	   "Configuração do Servidor FTP"
echo "========================================"

#variaveis com nomes, caminho e portas
FTP_USER=""
FTP_PASS=""
FTP_HOME="/srv/ftp"
UPLOAD_DIR="$FTP_HOME/upload"
DOWNLOAD_DIR="$FTP_HOME/download"
DATA_PORT="20"
CONTROL_PORT="21"
PASSIVE_MIN="40000" 	#portas passivas são usadas para a ação de transferir dados (o client 
PASSIVE_MAX="40100"	#estabelece conexão pela porta 21 mas os dados são transferidos pelas portas passivas)
#instalar vsftpd

echo " 1/8 - Instalação do server FTP (serviço vsftpd)"
yum install -y vsftpd


echo "Serviço vsftpd instalado com sucesso!"
sleep 3

# para serviço para fazer as configurações#
systemctl stop vsftpd 2>/dev/null

# BACKUP DO FICHEIRO ORIGINAL (IMPORTANTE, REFORÇADO POR VÁROIS PROFESSORES)

echo " 2/8 - A criar um backup da config original caso seja preciso..."
VSFTPD_CONF="/etc/vsftpd/vsftpd.conf"
cp "$VSFTPD_CONF" "${VSFTPD_CONF}.backup"

echo "Backup do ficheiro original foi criado!"

sleep 3

# CRIAR DIRETORIOS
echo "3/8 - A criar os diretórios necessários..."

mkdir -p "$FTP_HOME"
mkdir -p "$UPLOAD_DIR"
mkdir -p "$DOWNLOAD_DIR"

echo "Foram criados os seguintes diretórios:"

echo "Diretório base: $FTP_HOME"

echo "Diretório upload: $UPLOAD_DIR"

echo "Diretório download: $DOWNLOAD_DIR"

sleep 3

# CRIAR UTILIADOR FTP #
echo "4/8 - Vamos criar um utilizador para o FTP"
read -p "Como queres chamar ao user com que vais aceder ao servidor FTP? " FTP_USER

#validar que isto n funciona vazio#
while [ -z "$FTP_USER" ]; do
	echo "O nome do user não pode estar vazio."
	read -p "Como queres chamar ao user com que vais aceder ao servidor FTP? " FTP_USER
done

#verificar se o user já existe
if id "$FTP_USER" &>/dev/null;then
	echo "Utilizador $FTP_USER já existe.."
	echo "Opções:"
	echo "1 - Usar utilizador existente (manter password atual)"
	echo "2 - Alterar password do utilizador existente"
	read -p "Escolhe uma opção (1/2): " opcao

	case $opcao in
	1)
		echo "A usar user existente: $FTP_USER";;

	2)
		echo "A usar user existente: $FTP_USER"
		usermod -d "$FTP_HOME" "$FTP_USER"
		#pedir pass nova
		read -sp "Nova password para $FTP_USER: " FTP_PASS
		echo ""
		while [ -z "$FTP_PASS" ]; do
			echo "PASSWORD NÃO PODE ESTAR VAZIA"
			read -sp "Password: " FTP_PASS
			echo ""
		done
		echo "$FTP_USER:$FTP_PASS" | chpasswd
		echo "Pass alterada";;
	*)
		echo "Opção inválida"
		exit 1;;
	esac
else
	#criar user novo
	useradd -d "$FTP_HOME" -s /bin/bash "$FTP_USER"
	echo "User $FTP_USER criado"

	#password deste user novo
	read -sp "Password para user novo $FTP_USER: " FTP_PASS
	echo ""
	while [ -z "$FTP_PASS" ]; do
		echo "PASS NÃO PODE ESTAR VAZIA!"
		read -sp "Password: " FTP_PASS
	done
	echo "$FTP_USER:$FTP_PASS" | chpasswd
	echo "Password definida"
fi
sleep 3

# CONFIG DE PERMISSÕES #
echo "5/8 -  Estou a configurar permissões..."

chown -R "$FTP_USER:$FTP_USER" "$FTP_HOME"

chmod 755 "$FTP_HOME"
chmod 755 "$DOWNLOAD_DIR"
chmod 775 "$UPLOAD_DIR"

echo "As permissões foram configuradas!"
sleep 2

# CONFIGURAÇÃO DO VSFTPD 
echo "6/8 - A configurar o servidor vsftpd.."

cat > "$VSFTPD_CONF" <<EOF
#configuração do vsftpd, gerado automaticamente pelo ficheiro config_ftp.sh

# Desativar modo anónimo
anonymous_enable=NO

# Acesso local ativo
local_enable=yes
write_enable=yes

# Mensagens
dirmessage_enable=YES
ftpd_banner=Bem vindo ao Server FTP

# Logs
xferlog_enable=YES
xferlog_file=/var/log/vsftpd.log
log_ftp_protocol=YES

# Portas
ftp_data_port=$DATA_PORT
listen_port=$CONTROL_PORT


# Limites
max_clients=10
idle_session_timeout=600

# Lista de users permitidos
userlist_enable=YES
userlist_file=/etc/vsftpd/user_list
userlist_deny=NO

EOF

#echo "Ficheiro de configuração acabado."
sleep 3

# CCONFIGURAR LISTA DE USERS
echo "$FTP_USER" >> /etc/vsftpd/user_list
echo "A lista de users foi configurada"


#CONFIGURAR A FW#

echo "7/8 - A configurar a firewall"
sleep 3

firewall-cmd --permanent --add-service=ftp
firewall-cmd --permanent --add-port=$DATA_PORT/tcp
firewall-cmd --permanent --add-port=$PASSIVE_MIN/tcp
firewall-cmd --permanent --add-port=$PASSIVE_MAX/tcp
firewall-cmd --permanent --add-port=$CONTROL_PORT/tcp
firewall-cmd --reload

echo "Firewall configurada"
# ATIVAR E ARRANQUE SERVIÇO NO BOOT #

echo "8/8 - A ativar e iniciar o serviço FTP..."
systemctl enable vsftpd
systemctl start vsftpd

sleep 2
if systemctl is-active --quiet vsftpd;then
	echo "O serviço está ativo"
else
	echo "O serviço não está a funcionar corretamente: "
	journalctl -u vsftpd -n --no-pager
	exit 1
fi

############### FIM DO SCRIPT, MOSTRAR INFORMAÇOES ACERCA DO USER, ETC################
echo "====================================================="
echo   "O seu servidor FTP está configurado e está ativo!"
echo "====================================================="
echo ""
echo "Informações do Servidor FTP:"
echo "O user é: $FTP_USER"
echo "O diretório é: $FTP_HOME"
echo ""
echo "Se quiser testar a ligação, pode fazer:"
echo " ftp localhost "
echo "Nome: $FTP_USER"

exit 0
