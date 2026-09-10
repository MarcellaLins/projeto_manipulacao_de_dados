import os
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

load_dotenv()

server = os.getenv("DB_SERVER")
port = os.getenv("DB_PORT")
database = os.getenv("DB_NAME")
user = os.getenv("DB_USER")
password = os.getenv("DB_PASSWORD")
driver = os.getenv("DB_DRIVER")

engine = create_engine(
    f"mssql+pyodbc://{user}:{password}@{server}:{port}/{database}"
    f"?driver={driver.replace(' ', '+')}"
    "&TrustServerCertificate=yes"
)


# Testando a conexão
try:
    with engine.connect() as connection:
        result = connection.execute(text("SELECT @@VERSION"))
        print("Conexão bem-sucedida! Versão do SQL Server:")
        print(result.scalar())
except Exception as e:
    print(f"Erro ao conectar: {e}")
