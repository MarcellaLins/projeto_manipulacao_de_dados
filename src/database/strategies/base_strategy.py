"""
Define a interface (Strategy) comum a todas as estrategias de conexao
com banco de dados: cada banco de dados suportado (SQL Server, PostgreSQL,
e futuramente outros) vira uma classe concreta que sabe montar sua propria
URL de conexao. O restante do projeto nunca precisa saber qual banco esta
sendo usado por tras da abstracao, ele so enxerga um objeto DatabaseConnection
com um .engine pronto para uso.

Para adicionar suporte a um novo banco de dados no futuro, basta:
1. Criar uma nova classe que herde de DatabaseConnectionStrategy;
2. Implementar build_connection_url;
3. Registrar essa classe no dicionario _STRATEGIES em connection.py.

Nenhum codigo ja existente precisa ser alterado, apenas estendido.
"""

from abc import ABC, abstractmethod

from sqlalchemy import create_engine
from sqlalchemy.engine import Engine


class DatabaseConnectionStrategy(ABC):

    @abstractmethod
    def build_connection_url(self) -> str:
        # Monta a string de conexao (URL) especifica do banco de dados.
        raise NotImplementedError

    def create_engine(self) -> Engine:
        # Cria o Engine do SQLAlchemy a partir da URL e dos argumentos definidos pela estrategia concreta.
        url = self.build_connection_url()
        return create_engine(url)
