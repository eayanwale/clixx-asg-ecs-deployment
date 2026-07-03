
set -euo pipefail

touch /var/log/user-data.log
exec > /var/log/user-data.log 2>&1

# shellcheck disable=SC2154
local_env () {
    DB_HOST="${database_endpoint%%:*}"
    DB_NAME="${database_name}"
    DB_USER="${database_user}"
    DB_PASS="${database_pass}"
    SITE_ADDR="http://${lb_dns_name}"
}
local_env

# EFS CREATION AND MOUNTING
echo "[$(date '+%H:%M:%S')] Creating and mounting EFS..."

yum update -y
yum install -y nfs-utils

TOKEN=$(curl --request PUT "http://169.254.169.254/latest/api/token" --header "X-aws-ec2-metadata-token-ttl-seconds: 3600")
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region --header "X-aws-ec2-metadata-token: $TOKEN")
EFS_MOUNT_POINT=/var/www/html

mkdir -p ${EFS_MOUNT_POINT}
chown ec2-user:ec2-user ${EFS_MOUNT_POINT}

echo ${file_system_id}.efs."${REGION}".amazonaws.com:/ ${EFS_MOUNT_POINT} nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0 >> /etc/fstab

mount -a -t nfs4
mountpoint -q "${EFS_MOUNT_POINT}" || { echo "[$(date '+%H:%M:%S')] ERROR: EFS mount failed"; exit 1; }
chmod -R 755 /var/www/html

echo "[$(date '+%H:%M:%S')] EFS created and mounted on ${EFS_MOUNT_POINT} at ${file_system_id}"

############################################################################

# EBS PARTITIONING AND MOUNTING
    # echo "[$(date '+%H:%M:%S')] Installing lvm2..."
    # yum install -y lvm2

    # DEV_PREFIX="/dev"
    # ROOT_PART=$(findmnt -no SOURCE /)
    # ROOT_DISK=$(lsblk -no PKNAME "${ROOT_PART}" 2>/dev/null | head -1)
    # [ -z "${ROOT_DISK}" ] && ROOT_DISK=$(basename "${ROOT_PART}")
    # OTHER_DISKS=$(lsblk -ndo NAME | grep -vx "${ROOT_DISK}" || true)
    # COUNT=$(echo "${OTHER_DISKS}" | wc -w)
    # VG_NAME="stack_vg"
    # PARTITIONS=()

    # if [ "${COUNT}" -eq 0 ]; then
    #     echo "[$(date '+%H:%M:%S')] No additional disks found"
    #     echo "Skipping EBS partitioning and mounting..."
    # else
    #     DEVICES=()
    #     for i in ${OTHER_DISKS}; do
    #         DEVICES+=("${DEV_PREFIX}/$i")
    #     done

    #     echo "[$(date '+%H:%M:%S')] EBS Disks/Devices:"
    #     echo "                          ${DEVICES[*]}"

    #     echo "[$(date '+%H:%M:%S')] Partitioning disks..."
    #     for device in "${DEVICES[@]}"; do
    #         PARTITIONS+=("${device}1")

    #         if [ -b "${device}1" ]; then
    #             echo "[$(date '+%H:%M:%S')] ${device}1 already exists, skipping fdisk"
    #             continue
    #         fi

    #         fdisk "${device}" << EOF
    # p
    # n




    # p
    # w
    # EOF
    #     done

    #     partprobe 2>/dev/null || true

    #     echo "[$(date '+%H:%M:%S')] Creating disk labels..."
    #     for p in "${PARTITIONS[@]}"; do
    #         if pvs "${p}" >/dev/null 2>&1; then
    #             echo "[$(date '+%H:%M:%S')] PV ${p} already exists, skipping pvcreate"
    #         else
    #             pvcreate "${p}"
    #         fi
    #     done

    #     echo "[$(date '+%H:%M:%S')] Creating volume group..."
    #     if vgs "${VG_NAME}" >/dev/null 2>&1; then
    #         echo "[$(date '+%H:%M:%S')] VG ${VG_NAME} already exists, skipping vgcreate"
    #     else
    #         vgcreate "${VG_NAME}" "${PARTITIONS[@]}"
    #     fi

    #     echo "[$(date '+%H:%M:%S')] Creating logical volumes..."
    #     for ((i=1; i<=COUNT; i++)); do
    #         lv_name="Lv_u0${i}"
    #         if lvs "${VG_NAME}/${lv_name}" >/dev/null 2>&1; then
    #             echo "[$(date '+%H:%M:%S')] LV ${lv_name} already exists, skipping lvcreate"
    #         else
    #             lvcreate -L 5G -n "${lv_name}" "${VG_NAME}"
    #         fi
    #     done

    #     mapfile -t lv_list < <(lvs --noheadings -o lv_name --select "vg_name=${VG_NAME}" | tr -d ' ')

    #     echo "[$(date '+%H:%M:%S')] Creating ext4 file systems on volumes..."
    #     echo "      ${lv_list[*]}"
    #     for lv in "${lv_list[@]}"; do
    #         dev_path="${DEV_PREFIX}/${VG_NAME}/${lv}"
    #         if blkid "${dev_path}" >/dev/null 2>&1; then
    #             echo "[$(date '+%H:%M:%S')] FS on ${dev_path} already present, skipping mkfs"
    #         else
    #             mkfs.ext4 "${dev_path}"
    #         fi
    #     done

    #     echo "[$(date '+%H:%M:%S')] Creating mount points and mounting volumes..."
    #     for ((i=1; i<=COUNT; i++)); do
    #         mkdir -p /u0${i}
    #         mountpoint -q "/u0${i}" || 
    #         mount ${DEV_PREFIX}/${VG_NAME}/"${lv_list[$((i-1))]}" /u0${i}
    #     done

    #     uuid_list=()
    #     lv_names=()
    #     for lv in "${lv_list[@]}"; do
    #         volume_name="${VG_NAME}-${lv}"
    #         lv_names+=("${volume_name}")

    #         vol_uuid=$(lsblk -no UUID "${DEV_PREFIX}/${VG_NAME}/${lv}" | head -1)
    #         uuid_list+=("${vol_uuid}")
    #     done

    #     echo "[$(date '+%H:%M:%S')] Writing to /etc/fstab for persistence..."
    #     for ((i=1; i<=COUNT; i++)); do
    #         uuid="${uuid_list[$i-1]}"
    #         if [ -z "${uuid}" ]; then
    #             echo "[$(date '+%H:%M:%S')] WARNING: No UUID for /u0$i, skipping fstab entry"
    #             continue
    #         fi
    #         if ! grep -q "${uuid}" /etc/fstab; then
    #             echo "UUID=${uuid}   /u0$i   ext4    defaults,nofail   0   2" >> /etc/fstab
    #         fi
    #     done

    #     echo "[$(date '+%H:%M:%S')] /etc/fstab updated:"
    #         tail -n "${COUNT}" /etc/fstab

    #     if ! df -h | grep ${DEV_PREFIX}/mapper/${VG_NAME} 2>&1 | grep /u0; then
    #         echo "[$(date '+%H:%M:%S')] EBS volume mounting using lvm failed. Check logs:"
    #         echo "      /var/log/lamp_dep_script.log"
    #     else
    #         echo "[$(date '+%H:%M:%S')] EBS disks mounted successfully"
    #         lsblk
    #     fi
    # fi

#################################################################################

echo "[$(date '+%H:%M:%S')] Installing packages..."

yum update -y
amazon-linux-extras install -y lamp-mariadb10.2-php7.2 php7.2
yum install -y httpd mariadb-server php-gd php-mbstring php-xml php-mysqlnd

echo "[$(date '+%H:%M:%S')] All packages installed."

systemctl start httpd
systemctl enable httpd
systemctl start php-fpm
systemctl enable php-fpm

usermod -a -G apache ec2-user
chown -R ec2-user:apache /var/www
chmod 2775 /var/www && find /var/www -type d -exec  chmod 2775 {} + || true
find /var/www -type f -exec  chmod 0664 {} + || true

if [[ -z $(ls -A ${EFS_MOUNT_POINT}) ]]; then
    yum install -y git

    cd ${EFS_MOUNT_POINT} || exit

    git clone --branch latest ${GIT_REPO}
    cp -r CliXX_Retail_Repository/* ${EFS_MOUNT_POINT}/
    rm -rf ${EFS_MOUNT_POINT}/CliXX_Retail_Repository   
else
    echo "[$(date '+%H:%M:%S')] WordPress files already exist in ${EFS_MOUNT_POINT}, skipping..."
fi

if [[ ! -f ${EFS_MOUNT_POINT}/wp-config.php ]]; then
    echo "[$(date '+%H:%M:%S')] No wp-config found. Creating..."

    cp ${EFS_MOUNT_POINT}/wp-config-sample.php ${EFS_MOUNT_POINT}/wp-config.php
fi

echo "[$(date '+%H:%M:%S')] Updating wp-config and httpd conf..."

CONFIG=${EFS_MOUNT_POINT}/wp-config.php

sed -i "s|define( *'DB_NAME'.*|define( 'DB_NAME', '${DB_NAME}' );|"         "$CONFIG"
sed -i "s|define( *'DB_USER'.*|define( 'DB_USER', '${DB_USER}' );|"         "$CONFIG"
sed -i "s|define( *'DB_PASSWORD'.*|define( 'DB_PASSWORD', '${DB_PASS}' );|" "$CONFIG"
sed -i "s|define( *'DB_HOST'.*|define( 'DB_HOST', '${DB_HOST}' );|"         "$CONFIG"

grep -q "WP_AUTO_UPDATE_CORE" "$CONFIG" || sed -i "/^\/\* That's all, stop editing/i define( 'WP_AUTO_UPDATE_CORE', false );" "$CONFIG"

sed -i '/<Directory "\/var\/www\/html">/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/httpd/conf/httpd.conf

echo "[$(date '+%H:%M:%S')] All fields updated."

cd ${EFS_MOUNT_POINT} || exit

# Install WP CLI
if ! command -v wp >/dev/null 2>&1; then
    echo "[$(date '+%H:%M:%S')] WP CLI not found. Installing..."

    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    mv wp-cli.phar /usr/local/bin/wp
else
    echo "[$(date '+%H:%M:%S')] WP CLI already installed. Skipping..."
fi

if [[ -z "$SITE_ADDR" ]]; then
    PUB_DNS=$(aws ssm get-parameter --name '/stack/clixx/lb_dns' --query 'Parameter.Value' --output text)
    SITE_ADDR="http://${PUB_DNS}"
fi

current_siteurl=$(wp option get siteurl --allow-root)
current_home=$(wp option get home --allow-root)

[[ ${current_home} == "${current_siteurl}" ]] && echo "[$(date '+%H:%M:%S')] DNS info in database: ${current_home}"

if [[ ${current_home} != "${SITE_ADDR}" ]]; then

    echo "[$(date '+%H:%M:%S')] Current siteurl and home does not match current load balancer DNS"
    echo "[$(date '+%H:%M:%S')] Updating..."

    mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" -D "$DB_NAME" <<EOF
UPDATE wp_options SET option_value = '${SITE_ADDR}' WHERE option_name = 'siteurl';
UPDATE wp_options SET option_value = '${SITE_ADDR}' WHERE option_name = 'home';
SELECT option_value FROM wp_options WHERE option_name in ('siteurl','home');
EOF

    wp option update siteurl "${SITE_ADDR}" --allow-root
    wp option update home "${SITE_ADDR}" --allow-root
fi
echo "DNS info: ${SITE_ADDR}"

chown -R apache /var/www
chgrp -R apache /var/www
chmod 2775 /var/www
find /var/www -type d -exec  chmod 2775 {} + || true
find /var/www -type f -exec  chmod 0664 {} + || true

# Force users to login before seeing blog
if ! wp plugin is-installed wp-force-login --allow-root; then
    echo "[$(date '+%H:%M:%S')] Installing wp-force-login plugin..."
    wp plugin install wp-force-login --activate --allow-root --path=${EFS_MOUNT_POINT}
fi

# CREATE USERS
default_users=(
    "mike user1@example.com --role=contributor"
    "enoch user2@example.com --role=contributor"
    # "chichi user3@example.com --role=contributor"
    # "pete user4@example.com --role=contributor"
    # "boss user5@example.com --role=contributor"
)

for user in "${default_users[@]}"; do
    IFS=' ' read -r user_login user_email _ <<< "${user}"

    if wp user get "${user_login}" --allow-root >/dev/null 2>&1; then
        echo "[$(date '+%H:%M:%S')] User ${user_login} already exists, skipping user creation"
    else
        echo "[$(date '+%H:%M:%S')] Creating user ${user_login}"
        wp user create "${user_login}" "${user_email}" --role=contributor --send-email --allow-root
    fi
done

echo "All current users:"
wp user list --allow-root

systemctl restart httpd
systemctl enable httpd

script_end=$(date '+%H:%M:%S')
echo "=== Ending script at ${script_end} ==="