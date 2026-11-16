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
    ) -> None:
        self.pool = pooling.MySQLConnectionPool(
            pool_name="agenda_pool",
            pool_size=10,
            host=host,
            port=port,
            user=user,
            password=password,
            database=database,
            autocommit=True,
        )

    def get_connection(self):
        return self.pool.get_connection()