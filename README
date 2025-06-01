# CP&F client software

## Introduction

This software acts as a client to CP&F purchasing services.

## Database

An example database schema is located in `share/payment.sql`

## Example Apache configuration with SSL authentication

```apacheconf
<VirtualHost cpf.ctrlo.com:443>
    ServerName me.example.com
    DocumentRoot /srv/CPF

    <Directory "/srv/CPF/public">
        <RequireAll>
            <RequireAny>
                Require ip xxx
            </RequireAny>
            Require all granted
        </RequireAll>
        AllowOverride None
        Options +ExecCGI -MultiViews +SymLinksIfOwnerMatch
        AddHandler cgi-script .cgi
    </Directory>

    ScriptAlias / /srv/CPF/public/dispatch.cgi/

    # Client certificate authentication
    SSLCACertificateFile /etc/ssl/certs/Entrust_Root_Certification_Authority_-_G2.pem
    SSLVerifyDepth 5
    SSLSessionCacheTimeout  300
    SSLCompression          off
    SSLOptions +StdEnvVars +ExportCertData +FakeBasicAuth -OptRenegotiate
    # change to "optional" to not mandate certificate
    SSLVerifyClient require

    SSLEngine on
    SSLProtocol all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite          ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256

    SSLCertificateFile    /etc/ssl/certs/xxx.pem
    SSLCertificateKeyFile /etc/ssl/private/xxx.key

    <FilesMatch "\.(cgi|shtml|phtml|php)$">
            SSLOptions +StdEnvVars
    </FilesMatch>
</VirtualHost>
```

## Usage

```bash
# View an incoming order
cat /var/lib/cpf/D2h_YRph8n|bin/msgload.pl
# Send an acknowledge message
cat /var/lib/cpf/D2h_YRph8n|/srv/CPF/bin/msgload.pl --type=AcknowledgePurchaseOrder
Send an invoice
cat /var/lib/cpf/D2h_YRph8n|/srv/CPF/bin/msgload.pl --type=Invoice \
    --invoice-number=1001 --invoice-description="Invoice for package of widgets"
```
