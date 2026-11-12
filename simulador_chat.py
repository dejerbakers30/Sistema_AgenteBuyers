"""
==============================================================================
simulador_chat.py - SIMULADOR DE CHAT EN PYTHON (AUTENTICACIÓN DE WINDOWS)
==============================================================================
Usa la misma conexión de Windows (pyodbc) que dashboard.py:
1. Simula el mensaje del estudiante.
2. Invoca a Grok (xAI API) con Function Calling.
3. Ejecuta verificar_cobertura y registrar_buyer de forma transaccional.
4. Se refleja en tiempo real en dashboard.py.
==============================================================================
Uso:
  python simulador_chat.py "Hola, me llamo Carlos Ramirez, estudio Ingenieria de Sistemas en la Universidad Privada Antenor Orrego y busco ayuda para el informe final de mi tesis." 955112233
==============================================================================
"""

import os
import sys
import json
import pyodbc
from dotenv import load_dotenv
from openai import OpenAI

load_dotenv()

# ------------------------------------------------------------------------------
# 1. CONEXIÓN A SQL SERVER (AUTENTICACIÓN DE WINDOWS)
# ------------------------------------------------------------------------------
def get_db_connection():
    driver = os.getenv("DB_DRIVER", "ODBC Driver 17 for SQL Server")
    server = os.getenv("DB_SERVER", "localhost").strip()
    port = os.getenv("DB_PORT", "1433").strip()
    database = os.getenv("DB_NAME", "INBESTIGA_TESIS").strip()
    
    raw_trust = os.getenv("DB_TRUST_SERVER_CERTIFICATE", "yes").strip().lower()
    trust_cert = "yes" if raw_trust in ["true", "1", "yes", "y"] else "no"

    if port and "\\" not in server and "," not in server:
        server_str = f"{server},{port}"
    else:
        server_str = server

    conn_str = (
        f"DRIVER={{{driver}}};"
        f"SERVER={server_str};"
        f"DATABASE={database};"
        f"Trusted_Connection=yes;"
        f"TrustServerCertificate={trust_cert};"
    )
    return pyodbc.connect(conn_str, timeout=5)

# ------------------------------------------------------------------------------
# 2. HERRAMIENTAS (FUNCTION CALLING)
# ------------------------------------------------------------------------------
def verificar_cobertura(conn, universidad: str, carrera: str):
    print(f"\n🔍 [Tool Call] verificar_cobertura: '{universidad}' | '{carrera}'")
    cursor = conn.cursor()
    query = """
        SELECT TOP 1
            u.universidad_id, u.nombre AS universidad_nombre, u.atendida AS universidad_atendida,
            c.carrera_id, c.nombre AS carrera_nombre, c.atendida AS carrera_atendida
        FROM UNIVERSIDAD u
        INNER JOIN CARRERA c ON c.universidad_id = u.universidad_id
        WHERE u.nombre LIKE ? AND c.nombre LIKE ?;
    """
    cursor.execute(query, (f"%{universidad.strip()}%", f"%{carrera.strip()}%"))
    row = cursor.fetchone()

    if row:
        u_id, u_nom, u_at, c_id, c_nom, c_at = row
        cobertura = bool(u_at and c_at)
        print(f"   Resultado: {'✅ Cobertura ACTIVA' if cobertura else '⚠️ SIN COBERTURA'} ({u_nom} - {c_nom})")
        return {
            "encontrado": True,
            "universidad_id": u_id,
            "universidad_nombre": u_nom,
            "carrera_id": c_id,
            "carrera_nombre": c_nom,
            "cobertura": cobertura
        }
    
    print("   Resultado: ⚠️ No encontrado en catálogo directo -> Sin cobertura.")
    return {"encontrado": False, "carrera_id": 1, "cobertura": False}

def registrar_buyer_transaccional(conn, data: dict):
    print(f"\n📝 [Tool Call] registrar_buyer: Iniciando transacción atómica en SQL Server...")
    cursor = conn.cursor()
    try:
        whatsapp = str(data.get("whatsapp", ""))[:30]
        nombres = str(data.get("nombres", "Estudiante"))[:100]
        apellidos = str(data.get("apellidos"))[:100] if data.get("apellidos") and data.get("apellidos") != "Por Asignar" else None
        correo = str(data.get("correo"))[:150] if data.get("correo") else None
        carrera_id = data.get("carrera_id", 1)
        etapa = str(data.get("etapa_academica", "PREGRADO"))[:40]
        ciclo = str(data.get("ciclo", "X"))[:20]
        sede = str(data.get("sede", "TRUJILLO"))[:80]
        necesidad = str(data.get("necesidad_inicial", "Asesoría de Tesis") or "Asesoría de Tesis")[:150]
        tiene_cobertura = data.get("tiene_cobertura", False)
        estado_buyer = "ACTIVO" if tiene_cobertura else "SIN_COBERTURA"

        # 1. CONTACTO
        cursor.execute("SELECT contacto_id FROM CONTACTO WHERE whatsapp = ?", (whatsapp,))
        contact_row = cursor.fetchone()

        if contact_row:
            contacto_id = contact_row[0]
            cursor.execute(
                "UPDATE CONTACTO SET nombres = ?, apellidos = ?, correo = ISNULL(?, correo) WHERE contacto_id = ?",
                (nombres, apellidos, correo, contacto_id)
            )
        else:
            cursor.execute("""
                INSERT INTO CONTACTO (nombres, apellidos, whatsapp, correo, consentimiento_contacto, fecha_registro, estado)
                OUTPUT INSERTED.contacto_id
                VALUES (?, ?, ?, ?, 1, SYSDATETIME(), 'ACTIVO');
            """, (nombres, apellidos, whatsapp, correo))
            contacto_id = int(cursor.fetchone()[0])

        # 2. PERFIL_ACADEMICO
        cursor.execute("SELECT perfil_academico_id FROM PERFIL_ACADEMICO WHERE contacto_id = ?", (contacto_id,))
        if not cursor.fetchone():
            cursor.execute("""
                INSERT INTO PERFIL_ACADEMICO (contacto_id, carrera_id, etapa_academica, ciclo, sede, tipo_investigacion, avance)
                VALUES (?, ?, ?, ?, ?, 'TESIS', '0-25%');
            """, (contacto_id, carrera_id, etapa, ciclo, sede))

        # 3. BUYER
        cursor.execute("SELECT buyer_id FROM BUYER WHERE contacto_id = ?", (contacto_id,))
        buyer_row = cursor.fetchone()
        if buyer_row:
            buyer_id = buyer_row[0]
            cursor.execute("UPDATE BUYER SET estado = ?, necesidad_inicial = ?, fecha_buyer = SYSDATETIME() WHERE buyer_id = ?",
                           (estado_buyer, necesidad, buyer_id))
        else:
            cursor.execute("""
                INSERT INTO BUYER (contacto_id, canal_captacion_id, campania_id, servicio_interes_id, necesidad_inicial, fecha_buyer, estado)
                OUTPUT INSERTED.buyer_id
                VALUES (?, 1, NULL, 2, ?, SYSDATETIME(), ?);
            """, (contacto_id, necesidad, estado_buyer))
            buyer_id = int(cursor.fetchone()[0])

        # 4. CONVERSACION Y MENSAJE (Trazabilidad)
        cursor.execute("""
            INSERT INTO CONVERSACION (contacto_id, canal_id, campania_id, fecha_inicio, resuelta_sin_humano, estado)
            OUTPUT INSERTED.conversacion_id
            VALUES (?, 1, NULL, SYSDATETIME(), 1, 'CERRADA');
        """, (contacto_id,))
        conv_id = int(cursor.fetchone()[0])

        cursor.execute("""
            INSERT INTO MENSAJE (conversacion_id, fecha_mensaje, emisor, tipo, contenido)
            VALUES (?, SYSDATETIME(), 'CLIENTE', 'TEXTO', ?);
        """, (conv_id, necesidad))

        conn.commit()
        print(f"   ✅ Transacción confirmada: BUYER ID = {buyer_id} [Estado: {estado_buyer}]")
        return {"exito": True, "buyer_id": buyer_id, "estado": estado_buyer}

    except Exception as e:
        conn.rollback()
        print(f"   ❌ Error y Rollback: {e}")
        return {"exito": False, "error": str(e)}

# ------------------------------------------------------------------------------
# 3. FLUJO PRINCIPAL
# ------------------------------------------------------------------------------
def main():
    mensaje_usuario = sys.argv[1] if len(sys.argv) > 1 else (
        "Hola, me llamo Carlos Ramirez, estudio Ingenieria de Sistemas en la Universidad Privada Antenor Orrego y busco ayuda para el informe final de mi tesis."
    )
    telefono_usuario = sys.argv[2] if len(sys.argv) > 2 else "955112233"

    print("=" * 70)
    print("🚀 SIMULADOR DE CHAT - INBESTIGA (AUTENTICACIÓN DE WINDOWS)")
    print("=" * 70)
    print(f"📱 Teléfono simulado: {telefono_usuario}")
    print(f"💬 Mensaje: \"{mensaje_usuario}\"")

    try:
        conn = get_db_connection()
        print("✅ Conectado exitosamente a SQL Server (INBESTIGA_TESIS) con Windows Auth.")
    except Exception as e:
        print(f"❌ Error al conectar a SQL Server: {e}")
        return

    ai_key = os.getenv("GEMINI_API_KEY") or os.getenv("AI_API_KEY") or os.getenv("XAI_API_KEY", "")
    if not ai_key or "tu-api-key" in ai_key:
        print("\n⚠️ AVISO: GEMINI_API_KEY / AI_API_KEY no configurada o es de ejemplo.")
        print("   Ejecutando registro directo de prueba para verificar el Dashboard...")
        verif = verificar_cobertura(conn, "Antenor Orrego", "Ingenieria de Sistemas")
        registrar_buyer_transaccional(conn, {
            "nombres": "Carlos",
            "apellidos": "Ramirez",
            "whatsapp": telefono_usuario,
            "carrera_id": verif.get("carrera_id", 1),
            "etapa_academica": "PREGRADO",
            "necesidad_inicial": "Informe final de tesis - Asesoría Metodológica",
            "tiene_cobertura": verif.get("cobertura", True)
        })
        conn.close()
        print("\n🎉 ¡Registro insertado! Mira tu ventana de Streamlit (dashboard.py) para ver la actualización.")
        return

    # Invocación dinámica: Soporta Google Gemini, Groq o Grok
    is_gemini = bool(os.getenv("GEMINI_API_KEY") or ai_key.startswith("AIza") or ai_key.startswith("AQ."))
    if is_gemini:
        base_url = "https://generativelanguage.googleapis.com/v1beta/openai/"
        default_model = "gemini-2.5-flash"
    elif os.getenv("GROQ_API_KEY") or ai_key.startswith("gsk_"):
        base_url = "https://api.groq.com/openai/v1"
        default_model = "llama-3.3-70b-versatile"
    else:
        base_url = "https://api.x.ai/v1"
        default_model = "grok-2-latest"

    model = os.getenv("AI_MODEL") or os.getenv("GEMINI_MODEL") or os.getenv("XAI_MODEL") or default_model
    client = OpenAI(api_key=ai_key, base_url=base_url)
    print(f"🧠 [IA Config] Proveedor: {base_url} | Modelo: {model}")

    tools = [
        {
            "type": "function",
            "function": {
                "name": "verificar_cobertura",
                "description": "Verifica si la universidad y carrera tienen cobertura activa en INBESTIGA.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "universidad": {"type": "string"},
                        "carrera": {"type": "string"}
                    },
                    "required": ["universidad", "carrera"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "registrar_buyer",
                "description": "Inserta transaccionalmente al estudiante como Buyer en SQL Server.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "nombres": {"type": "string"},
                        "apellidos": {"type": "string"},
                        "whatsapp": {"type": "string"},
                        "correo": {"type": "string"},
                        "carrera_id": {"type": "integer"},
                        "etapa_academica": {"type": "string"},
                        "ciclo": {"type": "string"},
                        "sede": {"type": "string"},
                        "necesidad_inicial": {"type": "string"},
                        "tiene_cobertura": {"type": "boolean"}
                    },
                    "required": ["nombres", "whatsapp", "carrera_id", "tiene_cobertura"]
                }
            }
        }
    ]

    system_instructions = (
        "Eres 'Vicky', la Asistente Virtual de Admisión de INBESTIGA. "
        "Tu tono es 100% humano, empático, cálido y profesional. NUNCA menciones términos técnicos internos como 'KPI', 'KPI B06', 'Data Mart' o 'Fase Buyer'.\n"
        "Regla de mensajes fuera de tema (off-topic): Si el usuario pregunta o comenta algo que no tiene nada que ver con asesoría de tesis o investigación universitaria (ej. bromas, venta de otros productos, colegio, etc.), NO llames a ninguna herramienta y responde amablemente: "
        "'¡Hola! En INBESTIGA nos dedicamos exclusivamente a la asesoría, desarrollo y acompañamiento de tesis y proyectos de grado universitario. 🎓 Si estás realizando tu tesis, cuéntame: ¿en qué universidad estudias y qué carrera cursas? ¡Con gusto te ayudo! 😊'\n"
        "Flujo obligatorio:\n"
        "1. Identifica el nombre, universidad y carrera del estudiante.\n"
        "2. Ejecuta 'verificar_cobertura'.\n"
        "3. Ejecuta 'registrar_buyer'.\n"
        "4. Respuesta final obligatoria:\n"
        "- Si la herramienta verificar_cobertura retorna que SÍ hay cobertura (cobertura=True), responde EXACTAMENTE:\n"
        "'¡Hola [Nombre]! 🎉 Qué gusto saludarte, soy Vicky de INBESTIGA. Te confirmo que SÍ contamos con cobertura activa para tu carrera de [Carrera] en [Universidad]. Tus datos han quedado registrados exitosamente. En breve, un especialista te contactará para coordinar tu diagnóstico gratuito. 😊'\n"
        "- Si la herramienta verificar_cobertura retorna que NO hay cobertura (cobertura=False), responde EXACTAMENTE:\n"
        "'Hola [Nombre], soy Vicky de INBESTIGA. Lamentamos informarte que, por el momento, no contamos con cobertura activa para tu carrera en esa universidad. No obstante, hemos registrado tus datos en nuestra lista de espera preferencial. Apenas aperturemos nuevas vacantes, te notificaremos de inmediato. ¡Muchas gracias por tu interés! 🙏'"
    )

    messages = [
        {"role": "system", "content": system_instructions},
        {"role": "user", "content": mensaje_usuario}
    ]

    print("\n🧠 Consultando a Grok (xAI) con Function Calling...")
    try:
        response = client.chat.completions.create(
            model=model,
            messages=messages,
            tools=tools,
            tool_choice="auto"
        )
        msg = response.choices[0].message

        while msg.tool_calls:
            messages.append(msg)
            for tc in msg.tool_calls:
                fn_name = tc.function.name
                fn_args = json.loads(tc.function.arguments)
                result = None

                if fn_name == "verificar_cobertura":
                    result = verificar_cobertura(conn, fn_args.get("universidad", ""), fn_args.get("carrera", ""))
                elif fn_name == "registrar_buyer":
                    fn_args["whatsapp"] = telefono_usuario
                    result = registrar_buyer_transaccional(conn, fn_args)

                messages.append({
                    "role": "tool",
                    "tool_call_id": tc.id,
                    "name": fn_name,
                    "content": json.dumps(result)
                })

            response = client.chat.completions.create(model=model, messages=messages, tools=tools)
            msg = response.choices[0].message

        print("\n🤖 RESPUESTA FINAL DEL AGENTE IA:")
        print(f"\"{msg.content}\"")
        print("\n✅ ¡La base de datos fue actualizada! Observa el Dashboard en Streamlit.")

    except Exception as e:
        print(f"❌ Error en llamada Grok: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    main()

