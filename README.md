# shopware5-database-dump
Dump einer Shopware 5 Datenbank für lokale Entwicklungsumgebungen (mit GDPR-Datenfilterung).

## Disclaimer
Wir unterstützen eine Standard-Shopware-5-Datenbank. 

Bitte beachten Sie, dass wir keine Garantie für die DSGVO-Konformität des resultierenden Dumps geben können.

## Anforderungen
Sie benötigen `gzip` und `mysqldump`, die über Ihre `PATH`-Variable verfügbar sein müssen.
MySQL wird über IP-Verbindung angesprochen, Socket-Verbindungen werden derzeit nicht unterstützt.

## Verwendung
Führen Sie `./shopware5-database-dump.sh` aus, um die verfügbaren Optionen zu sehen:

```
Dumps a Shopware 5 database with a bit of cleanup and a GDPR mode ignoring sensitive data.

Usage:
  shopware5-database-dump.sh [filename.sql] --database db_name --user username [--host 127.0.0.1] [--port 3306] [--gdpr]
  shopware5-database-dump.sh [filename.sql] -d db_name -u username [-H 127.0.0.1] [-p 3306] [--gdpr]
  shopware5-database-dump.sh -h | --help

Arguments:
  filename.sql   Set output filename, will be gzipped, dump.sql by default

Options:
  -h --help      Display this help information.
  -d --database  Set database name
  -u --user      Set database user name
  -H --host      Set hostname for database server (default: 127.0.0.1)
  -p --port      Set database server port (default: 3306)
  --gdpr         Enable GDPR data filtering
```

Ihr Dump wird als `dump.sql.gz` (oder mit dem von Ihnen angegebenen Dateinamen) gespeichert.