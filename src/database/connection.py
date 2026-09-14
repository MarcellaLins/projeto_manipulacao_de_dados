"""
Modulo central de conexoes com banco de dados do projeto.

Para adicionar um novo banco de dados no futuro (ex: MySQL, SQLite):
1. Crie uma nova estrategia em src/database/strategies/, herdando de
   DatabaseConnectionStrategy;
2. Registre-a no dicionario _STRATEGIES logo abaixo;
"""

from dotenv import load_dotenv
from sqlalchemy import text

from src.database.strategies.base_strategy import DatabaseConnectionStrategy
from src.database.strategies.sqlserver_strategy import SQLServerStrategy
from src.database.strategies.postgresql_strategy import PostgreSQLStrategy

load_dotenv()


class DatabaseConnection:
    """
    Contexto do padrao Strategy: recebe qualquer estrategia de conexao e
    delega a ela a responsabilidade de montar a URL/engine. O resto do
    codigo so interage com esta classe, nunca diretamente com as
    estrategias concretas.
    """

    # Query de versao muda de banco para banco
    _QUERIES_VERSAO = {
        SQLServerStrategy: "SELECT @@VERSION",
        PostgreSQLStrategy: "SELECT version()",
    }

    def __init__(self, strategy: DatabaseConnectionStrategy, nome: str = ""):
        self._strategy = strategy
        self.nome = nome or strategy.__class__.__name__
        self._engine = None

    @property
    def engine(self):
        # Cria o engine na primeira utilizacao (lazy) e reaproveita depois.
        if self._engine is None:
            self._engine = self._strategy.create_engine()
        return self._engine

    def test_connection(self) -> None:
        # Testa a conexao executando uma query simples de versao do banco.
        query_versao = self._QUERIES_VERSAO.get(type(self._strategy), "SELECT 1")
        try:
            with self.engine.connect() as connection:
                versao = connection.execute(text(query_versao)).scalar()
                print(f"[{self.nome}] Conexao bem-sucedida!")
                print(f"[{self.nome}] Versao: {versao}")
        except Exception as e:
            print(f"[{self.nome}] Erro ao conectar: {e}")


# ---------------------------------------------------------------------------
# Fabrica de estrategias. Este e o UNICO ponto do projeto que precisa ser
# tocado quando um novo banco de dados for adicionado.
# ---------------------------------------------------------------------------
_STRATEGIES = {
    "sqlserver": SQLServerStrategy,
    "postgresql": PostgreSQLStrategy,
}


def get_connection(db_type: str) -> DatabaseConnection:
    """Fabrica que retorna uma DatabaseConnection ja configurada para o tipo pedido."""
    db_type_normalizado = db_type.lower()
    if db_type_normalizado not in _STRATEGIES:
        raise ValueError(
            f"Banco de dados '{db_type}' nao suportado. "
            f"Opcoes disponiveis: {list(_STRATEGIES.keys())}"
        )
    strategy_class = _STRATEGIES[db_type_normalizado]
    return DatabaseConnection(strategy_class(), nome=db_type_normalizado)


# Instancias prontas para uso direto em notebooks/scripts
sqlserver_connection = get_connection("sqlserver")
postgres_connection = get_connection("postgresql")

if __name__ == "__main__":
    # Testando as duas conexoes
    sqlserver_connection.test_connection()
    postgres_connection.test_connection()