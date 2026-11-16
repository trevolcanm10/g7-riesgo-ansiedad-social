import ssl
from pathlib import Path

import mysql.connector
from mysql.connector import pooling


class MySQLDatabase:
    """Pool de conexiones MySQL."""

    def __init__(
        self,
        host: str,
        port: int,
        user: str,
        password: str,
        database: str,
        ssl_enabled: bool = False,
        ssl_ca: str | None = None,
    ) -> None:
        options = dict(
            pool_name="agenda_pool",
            pool_size=10,
            host=host,
            port=port,
            user=user,
            password=password,
            database=database,
            autocommit=True,
            connection_timeout=10,
        )
        if ssl_enabled:
            ca_path = ssl_ca or ssl.get_default_verify_paths().cafile
            if not ca_path or not Path(ca_path).is_file():
                raise ValueError("No hay un certificado CA válido para DB_SSL")
            options.update(
                ssl_disabled=False,
                ssl_ca=ca_path,
                ssl_verify_cert=True,
                ssl_verify_identity=True,
            )
        else:
            options["ssl_disabled"] = True
        self.pool = pooling.MySQLConnectionPool(**options)

    def get_connection(self):
        return self.pool.get_connection()
