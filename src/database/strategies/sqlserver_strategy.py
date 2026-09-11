# Estrategia de conexao concreta para o SQL Server (via pyodbc).

import os

from src.database.strategies.base_strategy import DatabaseConnectionStrategy


class SQLServerStrategy(DatabaseConnectionStrategy):

    def __init__(self):
        self.server = os.getenv("SQLSERVER_HOST")
        self.port = os.getenv("SQLSERVER_PORT")
        self.database = os.getenv("SQLSERVER_DB")
        self.user = os.getenv("SQLSERVER_USER")
        self.password = os.getenv("SQLSERVER_PASSWORD")
        self.driver = os.getenv("SQLSERVER_DRIVER")

    def build_connection_url(self) -> str:
        driver_formatado = self.driver.replace(" ", "+")
        return (
            f"mssql+pyodbc://{self.user}:{self.password}"
            f"@{self.server}:{self.port}/{self.database}"
            f"?driver={driver_formatado}&TrustServerCertificate=yes"
        )
