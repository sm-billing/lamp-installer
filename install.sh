#!/bin/bash

# Color codes for output
RED='\e[31m'
GREEN='\e[32m'
RESET='\e[0m'

echo -e "${GREEN}"
echo "####################################################################"
echo "#                                                                  #"
echo "#  Welcome to the LAMP and FreeRADIUS installation                 #"
echo "#                                                                  #"
echo "#  This script will guide you through the installation and         #"
echo "#  configuration of the following components:                      #"
echo "#                                                                  #"
echo "#  - Apache2                                                       #"
echo "#  - PHP                                                           #"
echo "#  - FreeRADIUS (3.0 stable version)                               #"
echo "#  - MySQL or MariaDB                                              #"
echo "#  - phpMyAdmin                                                    #"
echo "#  - OpenSSH Server                                                #"
echo "#                                                                  #"
echo "#  After the installation, the script will restart services to     #"
echo "#  ensure all changes take effect.                                 #"
echo "#                                                                  #"
echo "#  Contact: https://t.me/smbilling                                 #"
echo "#  Donate: RedotPay ID: 1691723832                                 #"
echo "#                                                                  #"
echo "####################################################################"
echo -e "${RESET}"
sleep 5

# Check if the script is run with sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root or use sudo.${RESET}"
    exit 1
fi

# Update & Upgrade
read -r -p "Do you want to update the system? [Y/n]: " update
update=${update:-Y}
if [[ $update =~ ^[Yy]$ ]]; then
    apt-get update -y || { echo -e "${RED}Failed to update packages.${RESET}"; exit 1; }
    read -r -p "Do you want to upgrade the system? [Y/n]: " upgrade
    upgrade=${upgrade:-Y}
    if [[ $upgrade =~ ^[Yy]$ ]]; then
        apt-get upgrade -y || { echo -e "${RED}Failed to upgrade packages.${RESET}"; exit 1; }
    fi
fi

# Install additional utilities
read -r -p "Do you want to install wget, curl, git, zip, unzip? [Y/n]: " modules
modules=${modules:-Y}
if [[ $modules =~ ^[Yy]$ ]]; then
    apt-get install -y wget curl git zip unzip || { echo -e "${RED}Failed to install utilities.${RESET}"; exit 1; }
fi

# Install Database
read -r -p "Do you want to install a Database? [Y/n]: " sql
sql=${sql:-Y}
if [[ $sql =~ ^[Yy]$ ]]; then
    echo "Choose your database server (recommended: MySQL):"
    select db_server in "MySQL" "MariaDB"; do
        case $db_server in
        "MySQL")
            read -r -p "Do you want to install MySQL? [Y/n]: " install_mysql
            install_mysql=${install_mysql:-Y}
            if [[ $install_mysql =~ ^[Yy]$ ]]; then
                apt-get install -y mysql-server mysql-client || { echo -e "${RED}Failed to install MySQL.${RESET}"; exit 1; }
            fi
            ;;
        "MariaDB")
            read -r -p "Do you want to install MariaDB? [Y/n]: " install_mariadb
            install_mariadb=${install_mariadb:-Y}
            if [[ $install_mariadb =~ ^[Yy]$ ]]; then
                apt-get install -y mariadb-server mariadb-client || { echo -e "${RED}Failed to install MariaDB.${RESET}"; exit 1; }
            fi
            ;;
        *)
            echo -e "${RED}Invalid option. Please try again.${RESET}"
            continue
            ;;
        esac

        # Create a new user 'mahmud' with all privileges
        mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "CREATE USER 'hotspot'@'localhost' IDENTIFIED BY 'mahmud@#6677';"
        mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "GRANT ALL PRIVILEGES ON *.* TO 'hotspot'@'localhost' WITH GRANT OPTION;"
        mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "FLUSH PRIVILEGES;"

        # Create the database for FreeRADIUS
        DB_NAME="hotspot"

        if ! mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "USE $DB_NAME;" 2>/dev/null; then
            mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE $DB_NAME;" 2>/dev/null
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Database '$DB_NAME' created successfully.${RESET}"
            else
                echo -e "${RED}Failed to create database '$DB_NAME'. It may already exist.${RESET}"
            fi
        else
            echo -e "${GREEN}Database '$DB_NAME' already exists.${RESET}"
        fi

        break
    done
fi

# Install Apache2 and PHP
read -r -p "Do you want to install Apache2 and PHP? [Y/n]: " webserver
webserver=${webserver:-Y}
if [[ $webserver =~ ^[Yy]$ ]]; then
    echo ">>> Installing Apache2 and PHP <<<"
    apt-get install -y apache2 php libapache2-mod-php php-mysql || { echo -e "${RED}Failed to install Apache2 and PHP.${RESET}"; exit 1; }
    echo -e "${GREEN}>>> Finished Installing Apache2 and PHP <<<${RESET}"
fi

# Install FreeRADIUS (3.0 stable version)
read -r -p "Do you want to install FreeRADIUS? [Y/n]: " install_freeradius
install_freeradius=${install_freeradius:-Y}
if [[ $install_freeradius =~ ^[Yy]$ ]]; then
    echo ">>> Installing FreeRADIUS Server <<<"
    apt-get install -y freeradius freeradius-mysql || { echo -e "${RED}Failed to install FreeRADIUS.${RESET}"; exit 1; }
    echo -e "${GREEN}>>> Finished Installing FreeRADIUS Server <<<${RESET}"
fi

# Configure FreeRADIUS to use MySQL
echo ">>> Configuring FreeRADIUS to use MySQL <<<"
SQL_CONF="/etc/freeradius/3.0/mods-available/sql"

# Create or update the SQL configuration file
cat <<EOL | sudo tee $SQL_CONF
sql {
    driver = "rlm_sql_mysql"
    dialect = "mysql"
    server = "localhost"
    login = "hotspot"  # MySQL user
    password = "mahmud@#6677"  # MySQL password
    radius_db = "hotspot"  # Your database name
}
EOL

# Enable the SQL module
sudo ln -s /etc/freeradius/3.0/mods-available/sql /etc/freeradius/3.0/mods-enabled/

# Restart FreeRADIUS to apply changes
systemctl restart freeradius || { echo -e "${RED}Failed to restart FreeRADIUS.${RESET}"; exit 1; }
echo -e "${GREEN}>>> FreeRADIUS has been configured to use MySQL with database '$DB_NAME' <<<${RESET}"

# Install phpMyAdmin
read -r -p "Do you want to install phpMyAdmin? [Y/n]: " install_phpmyadmin
install_phpmyadmin=${install_phpmyadmin:-Y}
if [[ $install_phpmyadmin =~ ^[Yy]$ ]]; then
    apt-get install -y phpmyadmin || { echo -e "${RED}Failed to install phpMyAdmin.${RESET}"; exit 1; }
    
    echo -e "${GREEN}phpMyAdmin installed successfully!${RESET}"
else
    echo -e "${RED}phpMyAdmin installation skipped.${RESET}"
fi

# Install OpenSSH Server
read -r -p "Do you want to install OpenSSH Server? [Y/n]: " install_ssh
install_ssh=${install_ssh:-Y}
if [[ $install_ssh =~ ^[Yy]$ ]]; then
    apt-get install -y openssh-server || { echo -e "${RED}Failed to install OpenSSH Server.${RESET}"; exit 1; }
    echo -e "${GREEN}OpenSSH Server has been installed successfully.${RESET}"
fi

# Enable and start services
echo ">>> Enabling and starting services <<<"
systemctl enable apache2
systemctl start apache2
systemctl enable freeradius
systemctl start freeradius

# Display IP Address and Database Information
echo -e "
Your server's IP address is: $(hostname -I | awk '{print $1}')

- To access the web server, visit:
- http://$(hostname -I | awk '{print $1}')
"
echo -e "${GREEN}Apache2, PHP, FreeRADIUS, phpMyAdmin, and OpenSSH Server have been installed successfully!${RESET}"

# Print all installed packages
echo -e "${GREEN}All packages have been installed successfully!${RESET}"