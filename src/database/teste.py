# TEMPORARIO
# Testa isoladamente a conexao com o banco PostgreSQL usando psycopg2, para verificar se o erro de UnicodeDecodeError persiste.

import psycopg2
import os
from dotenv import load_dotenv

load_dotenv()

try:
    psycopg2.connect(
        host=os.getenv("POSTGRES_HOST"),
        port=os.getenv("POSTGRES_PORT"),
        dbname=os.getenv("POSTGRES_DB"),
        user=os.getenv("POSTGRES_USER"),
        password=os.getenv("POSTGRES_PASSWORD"),
    )
except UnicodeDecodeError as e:
    print("Mensagem real (latin-1):", e.object.decode("latin-1"))
except Exception as e:
    print("Erro:", e)