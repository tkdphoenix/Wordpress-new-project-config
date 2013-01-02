#!/bin/sh

# --------------------
# Variables declaration
# --------------------

# If you left current directory blank, it will take the current directory 
DIRECTORY=""

# wordpress url must be a zip to download
WORDPRESS_URL="http://wordpress.org/latest.zip"

# Theme must be a git repository
THEME_URL="https://github.com/jeremycastelli/Jelli.git"

# Local database with MAMP
DB_USER='root'
DB_PASSWORD='root'
DB_HOST='localhost'

# Local URL
LOCAL_URL='http://localhost:8888/'

# --------------------
# Set directory
# --------------------
if [[ $FTP_HOST == "" ]]; then
	DIRECTORY=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
fi
cd $DIRECTORY

# --------------------
# Set project name
# --------------------
echo "What is the project name ?"
read PROJECT_NAME

# --------------------
# Create database
# --------------------
echo "For local database configuration, I will use project name as database name, I just need table prefix (default : wp_)"
read table_prefix
if [[ $TABLE_PREFIX == "" ]]; then
	TABLE_PREFIX="wp_"
fi
/Applications/MAMP/Library/bin/mysql -u $DB_USER -p$DB_PASSWORD -e "create database "$PROJECT_NAME

# --------------------
# Set FTP parmmeters for sublime SFTP mapping
# --------------------
echo "If you want to configure sFTP now, please enter FTP host, else leave blank"
read FTP_HOST
if [[ $FTP_HOST != "" ]]; then
	echo "FTP user ?"
	read FTP_USER

	echo "FTP password ?"
	read FTP_PASS

	echo "FTP remote path ?"
	read FTP_ROOT
fi

# --------------------
# Create project directory
# --------------------
mkdir $PROJECT_NAME
PROJECT_DIR=$DIRECTORY"/"$PROJECT_NAME
cd $PROJECT_NAME

# --------------------
# Fetch Wordpress latest build
# --------------------
echo 'Download Wordpress...'
curl -o wordpress.zip $WORDPRESS_URL
echo 'Unzip Wordpress...'
unzip -q wordpress.zip && cp -R wordpress/* .
rm wordpress.zip && rm -rf wordpress && rm readme.html && rm license.txt


# --------------------
# Fetch H5BP server-config .htaccess
# --------------------
git clone https://github.com/h5bp/server-configs.git
cp server-configs/apache/.htaccess .htaccess
rm -rf server-configs

# --------------------
# Fetch base theme & remove default themes
# --------------------
echo 'Remove themes and plugins...'
cd wp-content/themes/
git clone $THEME_URL $PROJECT_NAME
rm -r twentyten
rm -r twentyeleven
rm -r twentytwelve

# --------------------
# Remove Hello Dolly plugin
# --------------------
rm ../plugins/hello.php

# --------------------
# Create Wordpress wp-config.php
# --------------------
echo 'Create wp-config...'
cd $PROJECT_DIR
touch wp-config-local.php
echo "<?php
define( 'DB_NAME', '"$PROJECT_NAME"' );
define( 'DB_USER', '"$DB_USER"' );
define( 'DB_PASSWORD', '"$DB_PASSWORD"' );
define( 'DB_HOST', '"$DB_HOST"' );" >wp-config-local.php
touch db.txt
echo "if ( file_exists( dirname( __FILE__ ) . '/wp-config-local.php' ) ) {
	include( dirname( __FILE__ ) . '/wp-config-local.php' );
} else {
	define( 'DB_NAME', '' );
	define( 'DB_USER', '' );
	define( 'DB_PASSWORD', '' );
	define( 'DB_HOST', '' ); // Probably 'localhost'
}" > db.txt

sed -e'
/DB_NAME/,/localhost/ c\
hello
' \
<wp-config-sample.php >wp-config-temp.php

sed '/hello/ {
r db.txt
d
}'<wp-config-temp.php >wp-config.php
mv wp-config.php wp-config-temp.php

curl -o salt.txt https://api.wordpress.org/secret-key/1.1/salt/

sed '/#@-/r salt.txt' <wp-config-temp.php >wp-config.php
mv wp-config.php wp-config-temp.php

sed "/#@+/,/#@-/d" <wp-config-temp.php >wp-config.php

rm wp-config-temp.php
rm db.txt
rm salt.txt

# --------------------
# Create Sublime Project config file
# --------------------
echo 'Create Sublime text 2 project file...'
SUBLIME_PROJECT_FILE=$PROJECT_NAME".sublime-project"
touch $SUBLIME_PROJECT_FILE
echo '{
	"folders":
	[
		{
			"path": ".",
			"file_exclude_patterns":[
				"._*",
				"*.sublime-project",
				"*.sublime-workspace"
			]
		},
		{
			"path": "./wp-content/themes/'$PROJECT_NAME'",
			"name": "template",
			"file_exclude_patterns":[
				"._*"
			]
		},
		{
			"path": "./wp-content/plugins",
			"file_exclude_patterns":[
				"._*"
			]
		}
	]
}' > $SUBLIME_PROJECT_FILE

# --------------------
# Create sFTP config files
# --------------------
echo 'Create FTP files...'
function create_FTP_file()
{
	touch sftp-config.json
	echo '{
	    // The tab key will cycle through the settings when first created
	    // Visit http://wbond.net/sublime_packages/sftp/settings for help
	    
	    // sftp, ftp or ftps
	    "type": "ftp",

	    "save_before_upload": true,
	    "upload_on_save": false,
	    "sync_down_on_open": false,
	    "sync_skip_deletes": false,
	    "confirm_downloads": false,
	    "confirm_sync": true,
	    "confirm_overwrite_newer": false,
	    
	    "host": "'$FTP_HOST'",
	    "user": "'$FTP_USER'",
	    "password": "'$FTP_PASS'",
	    //"port": "22",
	    
	    "remote_path": "'$1'",
	    "ignore_regexes": [
	        "\\\\.sublime-(project|workspace)", "sftp-config(-alt\\\\d?)?\\\\.json",
	        "sftp-settings\\\\.json", "/venv/", "\\\\.svn", "\\\\.hg", "\\\\.git",
	        "\\\\.bzr", "_darcs", "CVS", "\\\\.DS_Store", "Thumbs\\\\.db", "desktop\\\\.ini","wp-config-local.php"
	    ],
	    //"file_permissions": "664",
	    //"dir_permissions": "775",
	    
	    //"extra_list_connections": 0,

	    "connect_timeout": 30,
	    //"keepalive": 120,
	    //"FTP_PASSive_mode": true,
	    //"ssh_key_file": "~/.ssh/id_rsa",
	    //"sftp_flags": ["-F", "/path/to/ssh_config"],
	    
	    //"preserve_modification_times": false,
	    //"remote_time_offset_in_hours": 0,
	    //"remote_encoding": "utf-8",
	    //"remote_locale": "C",
	}' > sftp-config.json
}
if [[ $FTP_HOST != "" ]]; then
	create_FTP_file $FTP_ROOT
	cd "wp-content/themes/"$PROJECT_NAME
	create_FTP_file $FTP_ROOT"/wp-content/themes/"$PROJECT_NAME
	cd ../
	cd plugins
	create_FTP_file $FTP_ROOT"/wp-content/plugins"
fi

# --------------------
# Launch sublime project
# --------------------
echo 'Launch Sublime text 2'
cd $PROJECT_DIR
sublime $SUBLIME_PROJECT_FILE

# --------------------
# Create a new project in CodeKit
# --------------------
echo 'Create codekit project'
open -a /Applications/CodeKit.app $PROJECT_DIR"/wp-content/themes/"$PROJECT_NAME

# --------------------
# git init
# --------------------
echo 'git init'
git init
echo ".DS_Store
wp-config-local.php" > .gitignore

# --------------------
# Launch default browser
# --------------------
echo 'Launch browser'
open 'http://macbook-pro-de-pitch.local/'$PROJECT_NAME

echo 'Installation Complete, press enter to quit'
read
