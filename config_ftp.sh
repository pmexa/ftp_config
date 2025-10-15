#!/bin/bash

#se for para ser usado como root#

if [[ $EUID -ne 0 ]];then
	echo "Tem de entrar como root para executar isto"
	exit 1
fi

#FTP#

#variaveis com nomes, caminho e portas
FTP_USER="ftpuser"
FTP_PASS="ftppass"
FTP_HOME="/srv/ftp"
UPLOAD_DIR="$FTP_HOME/upload"
DOWNLOAD_DIR="$FTP_HOME/download"
DATA_PORT="20"
CONTROL_PORT="21"
PASSIVE_MIN="40000" 	#portas passivas são usadas para a ação de transferir dados (o client 
PASSIVE_MAX="40100"	#estabelece conexão pela porta 21 mas os dados são transferidos pelas portas passivas)
#instalar vsftpd

echo " 1/7 - Instalação do server FTP (serviço vsftpd)"
yum install -y vsftpd


echo "vsftpd instalado com sucesso"

# para serviço para fazer as configurações#
systemctl stop vsftpd 2>/dev/null

# BACKUP DO FICHEIRO ORIGINAL (IMPORTANTE, REFORÇADO POR VÁROIS PROFESSORES)

echo " 2/7 - A criar um backup da config original caso seja preciso..."
VSFTPD_CONF="/etc/vsftpd/vsftpd.conf"
cp "$VSFTPD_CONF" "${VSFTPD_CONF}.backup"
	echo "Backup criado"

# CRIAR DIRETORIOS
echo "3/7 - A criar os diretórios necessários..."

mkdir -p "$FTP_HOME"
mkdir -p "$UPLOAD_DIR"
mkdir -p "$DOWNLOAD_DIR"

echo "Foram criados os seguintes diretórios:"
echo "Diretório base: $FTP_HOME"
echo "Diretório upload: $UPLOAD_DIR"
echo "Diretório download: $DOWNLOAD_DIR"

# CRIAR UTILIADOR FTP #
echo "4/7 - Vamos criar um utilizador para o FTP"

if id "$FTP_USER" &>/dev/null;then
	echo "Utilizador $FTP_USER já existe.."
else
	useradd -d "$FTP_HOME" -s /bin/bash "$FTP_USER"
	echo "$FTP_USER:$FTP_PASS" | chpasswd
	echo "Utilizador $FTP_USER criado"
	echo "Password temporária: $FTP_PASS"
	echo "MUDE A PASSWORD APÓS O PRIMEIRO LOGIN QUE FIZER!"
fi

# CONFIG DE PERMISSÕES #
echo "5/7 -  Estou a configurar permissões..."

chown -R "$FTP_USER:$FTP_USER" "$FTP_HOME"

chmod 755 "$FTP_HOME"
chmod 755 "$DOWNLOAD_DIR"
chmod 755 "$UPLOAD_DIR"

#? setfacl -m u: $FTP_USER:rwx "$UPLOAD_DIR" 2>/dev/null || \ chmod 755 "$UPLOAD_DIR"

echo "As permissões foram configuradas!"

# CONFIGURAÇÃO DO VSFTPD #
echo "6/7 - A configurar o servidor vsftpd.."

#cat > "$VSFTPD_CONF" <<EOF
#??????
#EOF
#echo "Ficheiro de configuração acabado."

# CCONFIGURAR LISTA DE USERS
echo "$FTP_USER" >> /etc/vsftpd/user_list
echo "A lista de users foi configurada com o user ftpuser"

# CRIAR DIRETORIO PARA CHROOT #
#??????????????#

#CONFIGURAR A FW#

echo "7/8 - A configurar a firewall"

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
	echo "O serviço não está a funcionar corretamente. Aconselho journalctl -x |tail -50"
fi


