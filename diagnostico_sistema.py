"""
==============================================================================
diagnostico_sistema.py - DIAGNÓSTICO INTEGRAL PRE-VUELO (INBESTIGA BI)
==============================================================================
Verifica la configuración del entorno, conectividad a SQL Server,
existencia de las 9 tablas requeridas para la Fase BUYER y estado de Grok API.
==============================================================================
"""

import os
import sys
import pyodbc
from dotenv import load_dotenv

# Cargar .env
load_dotenv()

print("=" * 70)
print("🔍 INBESTIGA - DIAGNÓSTICO PRE-VUELO DEL SISTEMA (FASE BUYER)")
print("=" * 70)

# 1. Verificar variables de entorno
print("\n[1/4] Verificando variables de entorno en .env...")
required_db_vars = [
    "DB_SERVER", "DB_PORT", "DB_NAME", "DB_USER", "DB_PASSWORD",
    "DB_ODBC_DRIVER"
]

missing_vars = []
for var in required_db_vars:
    val = os.getenv(var)
    if not val:
        missing_vars.append(var)
    else:
        disp = "***" if "PASSWORD" in var else val
        print(f"  ✅ {var}: {disp}")

# Verificar key de IA (Gemini, Groq, xAI o genérica)
ai_key = os.getenv("GEMINI_API_KEY") or os.getenv("AI_API_KEY") or os.getenv("GROQ_API_KEY") or os.getenv("XAI_API_KEY")
if ai_key and "tu-api-key" not in ai_key:
    provider = "Google Gemini" if (os.getenv("GEMINI_API_KEY") or ai_key.startswith("AIza")) else (
               "Groq" if (os.getenv("GROQ_API_KEY") or ai_key.startswith("gsk_")) else "xAI / Grok"
    )
    print(f"  ✅ IA API Key detectada para [{provider}]: *** (Longitud: {len(ai_key)})")
else:
    missing_vars.append("GEMINI_API_KEY (o AI_API_KEY / XAI_API_KEY)")

if missing_vars:
    print(f"  ⚠️ Variables pendientes o con valores por defecto: {', '.join(missing_vars)}")
else:
    print("  ✅ Todas las variables requeridas están definidas.")

# 2. Verificar drivers ODBC disponibles
print("\n[2/4] Verificando drivers ODBC instalados en el sistema...")
drivers = pyodbc.drivers()
selected_driver = os.getenv("DB_ODBC_DRIVER", "ODBC Driver 17 for SQL Server")
if selected_driver in drivers:
    print(f"  ✅ Driver configurado encontrado: '{selected_driver}'")
else:
    print(f"  ❌ Driver '{selected_driver}' NO encontrado.")
    print(f"  ℹ️ Drivers detectados: {drivers}")

# 3. Probar conexión a SQL Server
print("\n[3/4] Probando conexión con SQL Server (INBESTIGA_TESIS)...")
server = os.getenv("DB_SERVER", "localhost")
port = os.getenv("DB_PORT", "1433")
database = os.getenv("DB_NAME", "INBESTIGA_TESIS")
user = os.getenv("DB_USER", "sa")
password = os.getenv("DB_PASSWORD", "")
trust_cert_raw = os.getenv("DB_TRUST_SERVER_CERTIFICATE", "yes").lower()
trust_cert = "yes" if trust_cert_raw in ["true", "yes", "1"] else "no"

conn_str = (
    f"DRIVER={{{selected_driver}}};"
    f"SERVER={server},{port};"
    f"DATABASE={database};"
    f"UID={user};"
    f"PWD={password};"
    f"TrustServerCertificate={trust_cert};"
)

tablas_requeridas = [
    "UNIVERSIDAD", "CARRERA", "CONTACTO", "PERFIL_ACADEMICO",
    "BUYER", "CANAL", "CAMPANIA", "CONVERSACION", "MENSAJE"
]

try:
    try:
        conn = pyodbc.connect(conn_str, timeout=3)
    except Exception:
        # Fallback a Shared Memory / Local sin especificar puerto
        conn_str_local = (
            f"DRIVER={{{selected_driver}}};"
            f"SERVER=(local);"
            f"DATABASE={database};"
            f"UID={user};"
            f"PWD={password};"
            f"TrustServerCertificate={trust_cert};"
        )
        conn = pyodbc.connect(conn_str_local, timeout=4)
    cursor = conn.cursor()
    print("  ✅ Conexión establecida exitosamente con el motor SQL Server.")

    # Verificar presencia de las 9 tablas requeridas
    print("\n[4/4] Verificando las 9 tablas exclusivas de la Fase BUYER...")
    cursor.execute("""
        SELECT TABLE_NAME 
        FROM INFORMATION_SCHEMA.TABLES 
        WHERE TABLE_TYPE = 'BASE TABLE'
    """)
    tablas_existentes = {row[0].upper() for row in cursor.fetchall()}

    todas_existen = True
    for t in tablas_requeridas:
        if t in tablas_existentes:
            cursor.execute(f"SELECT COUNT(*) FROM {t}")
            count = cursor.fetchone()[0]
            print(f"  ✅ Tabla [{t}]: Encontrada ({count} registros)")
        else:
            print(f"  ❌ Tabla [{t}]: NO existe en la base de datos.")
            todas_existen = False

    conn.close()

    if todas_existen:
        print("\n" + "=" * 70)
        print("🎉 ESTADO: TODO LISTO PARA EJECUTAR EL PROTOTIPO")
        print("=" * 70)
    else:
        print("\n" + "=" * 70)
        print("⚠️ ALERTA: Faltan tablas. Ejecuta 01_CREAR_BD_TRANSACCIONAL_DEFINITIVO.sql en SSMS.")
        print("=" * 70)

except Exception as e:
    print(f"  ❌ Error al conectar a SQL Server: {e}")
    print("\n💡 Sugerencias:")
    print("  1. Comprueba que el servicio de SQL Server esté iniciado.")
    print("  2. Si usas instancia nombrada (ej. SQLEXPRESS), coloca DB_SERVER=localhost\\SQLEXPRESS.")
    print("  3. Verifica que la base de datos INBESTIGA_TESIS haya sido creada.")

