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

echo " 1/10- Instalação do server FTP (serviço vsftpd)"
yum install -y vsftpd


echo "Serviço vsftpd instalado com sucesso!"
sleep 3

# para serviço para fazer as configurações#
systemctl stop vsftpd 2>/dev/null

# BACKUP DO FICHEIRO ORIGINAL (IMPORTANTE, REFORÇADO POR VÁROIS PROFESSORES)
echo " 2/10- Backup da configuração original (serviço vsftpd)"
VSFTPD_CONF=/etc/vsftpd/vsftpd.conf

if [ -f "$VSFTPD_CONF" ] && [ ! -f "${VSFTPD_CONF}.backup" ]; then
    cp "$VSFTPD_CONF" "${VSFTPD_CONF}.backup"
    echo "Backup do ficheiro original foi criado!"
elif [ -f "${VSFTPD_CONF}.backup" ]; then
    echo "⚠ Backup já existe, não vou sobrescrever"
fi

sleep 3

# CRIAR DIRETORIOS
echo "3/10 - A criar os diretórios necessários..."

mkdir -p "$FTP_HOME"
mkdir -p "$UPLOAD_DIR"
mkdir -p "$DOWNLOAD_DIR"

echo "Foram criados os seguintes diretórios:"

echo "Diretório base: $FTP_HOME"

echo "Diretório upload: $UPLOAD_DIR"

echo "Diretório download: $DOWNLOAD_DIR"

sleep 3

# CRIAR UTILIADOR FTP #
echo "4/10 - Vamos criar um utilizador para o FTP"
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
		echo "A usar user existente: $FTP_USER"
		usermod -d "$FTP_HOME" "$FTP_USER";;

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
		echo ""
	done
	echo "$FTP_USER:$FTP_PASS" | chpasswd
	echo "Password definida"
fi
sleep 3

# CONFIG DE PERMISSÕES #
echo ""
echo "5/10 - Configurar permissões..."

# Estrutura base
chown "$FTP_USER:$FTP_USER" "$FTP_HOME"
chmod 755 "$FTP_HOME"

# UPLOAD - User FTP pode escrever
chown "$FTP_USER:$FTP_USER" "$UPLOAD_DIR"
chmod 775 "$UPLOAD_DIR"

# DOWNLOAD - Só ROOT pode escrever (user FTP so le)
chown root:"$FTP_USER" "$DOWNLOAD_DIR"
chmod 750 "$DOWNLOAD_DIR"

echo "Permissões configuradas"
echo "Upload: Escrita permitida para $FTP_USER"
echo "Download: Só leitura para $FTP_USER"

sleep 2

# CONFIGURAÇÃO DO VSFTPD 
echo "6/10 - A configurar o servidor vsftpd.."

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

# Portas
connect_from_port_20=YES
ftp_data_port=$DATA_PORT
listen_port=$CONTROL_PORT
pasv_enable=YES
pasv_max_port=$PASSIVE_MAX
pasv_min_port=$PASSIVE_MIN


# Limites
max_clients=10
idle_session_timeout=600

# Lista de users permitidos
pam_service_name=vsftpd
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

echo "7/10 - A configurar a firewall"
sleep 3

firewall-cmd --permanent --add-service=ftp
firewall-cmd --permanent --add-port=$DATA_PORT/tcp
firewall-cmd --permanent --add-port=$CONTROL_PORT/tcp
firewall-cmd --permanent --add-port=$PASSIVE_MIN-$PASSIVE_MAX/tcp
firewall-cmd --reload

echo "Firewall configurada"

# 8/10 - SELinux
echo "8/10 - Configurar SELinux para FTP..."
yum install -y policycoreutils-python-utils 2>/dev/null

# Permitir escrita e leitura FTP
setsebool -P ftp_home_dir on
setsebool -P allow_ftpd_full_access on

# Corrigir contextos
semanage fcontext -a -t public_content_rw_t "$UPLOAD_DIR(/.*)?"
semanage fcontext -a -t public_content_t "$DOWNLOAD_DIR(/.*)?"
restorecon -Rv "$FTP_HOME"

echo "SELinux configurado!"
sleep 2

# 9/10 - Instalar e configurar Fail2Ban
echo "9/10 - Instalar e configurar Fail2Ban..."
yum install -y epel-release
yum install -y fail2ban

cat > /etc/fail2ban/jail.d/vsftpd.local <<EOF
[vsftpd]
enabled = true
port    = 21
filter  = vsftpd
logpath = /var/log/vsftpd.log
maxretry = 5
bantime = 3600
EOF

systemctl enable fail2ban
systemctl start fail2ban
echo "Fail2Ban configurado e ativo!"

if systemctl is-active --quiet fail2ban; then
    echo "✓ Fail2Ban ativo e a proteger o servidor!"
else
    echo "⚠ Fail2Ban pode não estar ativo"
fi
sleep 2

# ATIVAR E ARRANQUE SERVIÇO NO BOOT #

echo "10/10 - A ativar e iniciar o serviço FTP..."
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
