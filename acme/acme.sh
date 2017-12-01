#!/bin/bash
#---------------------------------------------------------------------
# ssl certificate generate tool,  
# ssl certificate is issued from Let's Encrypt https://letsencrypt.org
#
# 每個月更新憑證。 Let's Encrypt 提供的 SSL 憑證是3個月效期。
#---------------------------------------------------------------------
PATH=usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/usr/bin

# Global variables
# private key algorithm and key size
DEFAULT_KEY_ALG="rsa"
DEFAULT_KEY_ZIE="4096"

# Checking required input arguments
# config file is requried.
CONFIG_FILE="${1}"
echo "configuration file: ${CONFIG_FILE}"
checkArgs() {
	if [ -z $CONFIG_FILE ]; then
		echo "acme.conf must be specify, ex: acme.sh ./acme.conf" >&2
		exit 1
	fi
}

# reading configuration
param=""
msg=""
config() {
	echo "Reading ${CONFIG_FILE}...." >&2
  if [ -f "${CONFIG_FILE}" ]; then
  		echo "Got ${CONFIG_FILE}" >&2
    source $CONFIG_FILE
  else
   	echo "${CONFIG_FILE} not found." >&2
    exit 1
  fi
   
	# check required parameters
	checkParams "DNS" "${DNS}"
	checkParams "ACME_HOME" "${ACME_HOME}" "$pwd"
	
	if [ ! -d "$ACME_HOME" ]; then
		mkdir -p $ACME_HOME
	fi
}

# exit program if required parameter is missing
# param: parameter name
# val: parameter value
# default: default value for param if val not supply
# msg: error message 
checkParams() {
	param="${1}"
	val="${2}"
	default="${3}"
	msg="${4}"
	
	if [ -z "$val" ]; then
		if [ -z "$default" ]; then
			echo "${param} parameter is required, value: ${val}, default: ${default}, check it in acme.conf." >&2
			exit 1
		else
			export "$param"="$default"
			echo "$param used default $default". >&2
		fi
	else
		echo "${param} is ${val}." >&2
	fi
}

#---------------------------------------------------------------------
# 
#---------------------------------------------------------------------

# create a private key for ACME account.
makeACMEAccountKey() {
	echo "makeACMEAccountKey" >&2
	checkParams "ACME_KEY_NAME" "$ACME_KEY_NAME" "$DNS-acme.key"
	checkParams "ACME_KEY_SIZE" "$ACME_KEY_SIZE" "$DEFAULT_KEY_ZIE"
	checkParams "ACME_KET_ALG" "$ACME_KET_ALG" "$DEFAULT_KEY_ALG"
	makePrivateKey "$ACME_HOME/$ACME_KEY_NAME" "$ACME_KEY_SIZE"
}

# create a private key for SSL domain
makeSSLCertificate() {
	echo "makeSSLCertificate" >&2
	checkParams "DOMAIN_KEY_NAME" "$DOMAIN_KEY_NAME" "$DNS-ssl.key"
	checkParams "DOMAIN_KEY_SZIE" "$DOMAIN_KEY_SZIE" "$DEFAULT_KEY_ZIE"
	checkParams "DOMAIN_KEY_ALG" "$DOMAIN_KEY_ALG" "$DEFAULT_KEY_ALG"
	
	# create ssl private eky		
	makePrivateKey "$ACME_HOME/$DOMAIN_KEY_NAME" "$DOMAIN_KEY_SZIE"
  # create csr
  makeCSR
  
	# Request ACME to issue SSL certificate
	/usr/bin/python $ACME_HOME/acme_tiny.py --account-key "$ACME_HOME/$ACME_KEY_NAME" --csr "$ACME_HOME/$DNS.csr" --acme-dir "$ACME_CHALLENGES_DIR" > /var/tmp/$DNS.crt
	if [ -e "/var/tmp/${DNS}.crt" ]; then
		mv -f /var/tmp/$DNS.crt $SSL_CERT_STORE_LOCATION/$DNS.crt
		# update Let's Encrypt 中間憑證
		wget -O - https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem > /var/tmp/intermediate.pem
		if [ -e "/var/tmp/intermediate.pem" ]; then
			# Chain Let's Encrypt 中間憑證與伺服器憑證
			cat $SSL_CERT_STORE_LOCATION/$DNS.crt /var/tmp/intermediate.pem > $SSL_CERT_STORE_LOCATION/$DNS-chained.pem
		else
			echo "Can't download https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem, existing." >%2
			exit 1
		fi
	else
		echo "/var/tmp/${DNS}.crt not exist, it should be generated by acme_tiny.py, exiting." >&2
		exit 1
	fi

	# remove temp files
	rm -f /var/tmp/intermediate.pem /var/tmp/$DNS.crt	
}

# create Certificate Signing Request for your doamin
makeCSR() {
	echo "makeCSR" >&2
	
	checkParams "DOMAIN_CSR_SUB" "$DOMAIN_CSR_SUB"
	openssl req -new -sha256 -key "$ACME_HOME/$DOMAIN_KEY_NAME" -subj "$DOMAIN_CSR_SUB" -out "$ACME_HOME/$DNS.csr"
if [ -r "$ACME_HOME/$DNS.csr" ]; then
		echo "$ACME_HOME/$DNS.csr generated." >&2
	else
		echo "Failed to generate $ACME_HOME/$DNS.csr. existing" >&2
		exit 1
	fi	
}

# Using openssl to generate key
# {1}: key file name with full path
# {2}: key length
makePrivateKey() {
	echo "makePrivateKey" >&2
  keyFilePath="${1}"
  keyLength="${2}"
  
  if [[ ( -z "$keyFilePath" ) || ( -z "$keyLength" ) ]]; then
  		echo "keyFilePath, keyLength must be specified. existing" >&2
  		exit 1
  fi
  
  openssl genrsa $keyLength > $keyFilePath
	if [ -r "$keyFilePath" ]; then
		echo "Private key generated at ${keyFilePath}" >&2
	else
		echo "Can't generate private key for ${keyFilePath}. existing" >&2
		exit 1
	fi  
}

# download acme_tiny.py
getACMETiny() {
	echo "getACMETiny" >&2
	if [ ! -e "$ACME_HOME/acme_tiny.py" ]; then
		wget -P "$ACME_HOME" https://raw.githubusercontent.com/diafygi/acme-tiny/master/acme_tiny.py
		if [ ! -e "$ACME_HOME/acme_tiny.py" ]; then
			echo "Can't download https://raw.githubusercontent.com/diafygi/acme-tiny/master/acme_tiny.py, existing." >&2
			exit 1
		fi
	fi
}

# main 
main() {
	checkArgs
	config
	getACMETiny
	makeACMEAccountKey
	makeSSLCertificate
}

# entry program
main