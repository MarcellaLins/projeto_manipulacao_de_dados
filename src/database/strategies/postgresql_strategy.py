# Estrategia de conexao concreta para o PostgreSQL (via psycopg2).

import os

from src.database.strategies.base_strategy import DatabaseConnectionStrategy


class PostgreSQLStrategy(DatabaseConnectionStrategy):

    def __init__(self):
        self.server = os.getenv("POSTGRES_HOST")
        self.port = os.getenv("POSTGRES_PORT")
        self.database = os.getenv("POSTGRES_DB")
        self.user = os.getenv("POSTGRES_USER")
        self.password = os.getenv("POSTGRES_PASSWORD")

    def build_connection_url(self) -> str:
        return (
            f"postgresql+psycopg2://{self.user}:{self.password}"
            f"@{self.server}:{self.port}/{self.database}"
        )
