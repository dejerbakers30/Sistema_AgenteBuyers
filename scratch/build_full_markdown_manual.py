import os

def build_markdown():
    # Leer archivos del proyecto
    with open('bot.js', 'r', encoding='utf-8') as f:
        bot = f.readlines()
    with open('server_dashboard.js', 'r', encoding='utf-8') as f:
        server = f.readlines()
    with open('dashboard.py', 'r', encoding='utf-8') as f:
        dash = f.readlines()
    with open('diagnostico_sistema.py', 'r', encoding='utf-8') as f:
        diag = f.readlines()
    with open('simulador_chat.js', 'r', encoding='utf-8') as f:
        sim = f.readlines()
    with open('frontend/src/App.jsx', 'r', encoding='utf-8') as f:
        app = f.readlines()
    with open('frontend/src/components/KpiCards.jsx', 'r', encoding='utf-8') as f:
        kpi = f.readlines()
    with open('frontend/src/components/BuyersTable.jsx', 'r', encoding='utf-8') as f:
        buyers = f.readlines()

    sections = [
        # =========================================================================
        # MODULO A
        # =========================================================================
        {
            "modulo": "A) ACCESO, CONFIGURACIÓN Y DIAGNÓSTICO DEL SISTEMA",
            "titulo": "Pantalla de Configuración de Entorno (.env)",
            "marcador": "**Colocar imagen de código del archivo .env y carga de configuración en bot.js**",
            "lenguaje": "ini",
            "codigo": """# ==============================================================================
# ARCHIVO: .env (Parámetros de configuración del sistema)
# ==============================================================================
# Conectividad a Microsoft SQL Server (INBESTIGA_TESIS)
DB_SERVER=(local)
DB_PORT=1433
DB_NAME=INBESTIGA_TESIS
DB_USER=admin
DB_PASSWORD=••••••••
DB_DRIVER=ODBC Driver 17 for SQL Server

# Parámetros del Motor de Inteligencia Artificial (Google Gemini / OpenAI compatible)
GEMINI_API_KEY=•••••••••••••••••••••••••••••••••••••••••••••••••••••
AI_MODEL=gemini-1.5-flash
GEMINI_MODEL=gemini-1.5-flash
AI_BASE_URL=https://generativelanguage.googleapis.com/v1beta/openai/

# Servidores Web y Aplicación
PORT=3000
STREAMLIT_PORT=8501""",
            "descripcion": "Descripción: se muestra el código de configuración de variables de entorno del sistema (.env), definiendo los parámetros de enlace para el protocolo de memoria compartida en SQL Server y las credenciales del motor de inferencia de IA."
        },
        {
            "modulo": None,
            "titulo": "Pantalla de Diagnóstico Pre-Vuelo del Sistema",
            "marcador": "**Colocar imagen de código del archivo diagnostico_sistema.py - función test_sql_connection()**",
            "lenguaje": "python",
            "codigo": "".join(diag[20:75]).strip(),
            "descripcion": "Descripción: se muestra el código para ejecutar el diagnóstico previo del sistema en diagnostico_sistema.py, comprobando los controladores ODBC, la conexión física a SQL Server y la integridad de las 9 tablas requeridas para la Fase Buyer."
        },
        {
            "modulo": None,
            "titulo": "Pantalla de Inicialización de Servicios y Base de Datos",
            "marcador": "**Colocar imagen de código del archivo bot.js - función getDbPool() y arranque**",
            "lenguaje": "javascript",
            "codigo": "".join(bot[108:168]).strip(),
            "descripcion": "Descripción: se muestra el código para inicializar el pool de conexiones a SQL Server con msnodesqlv8 en bot.js, verificando la disponibilidad del motor de base de datos antes de arrancar los servicios de mensajería."
        },

        # =========================================================================
        # MODULO B
        # =========================================================================
        {
            "modulo": "B) AGENTE CONVERSACIONAL WHATSAPP \"VICKY\" (ROL PROSPECTO / ESTUDIANTE)",
            "titulo": "Pantalla de Vinculación WhatsApp Web (Escaneo de Código QR)",
            "marcador": "**Colocar imagen de código del archivo bot.js - eventos client.on('qr') y client.on('ready')**",
            "lenguaje": "javascript",
            "codigo": "".join(bot[838:870]).strip(),
            "descripcion": "Descripción: se muestra el código para gestionar el ciclo de autenticación de WhatsApp Web mediante la biblioteca whatsapp-web.js, renderizando el código QR en terminal y notificando cuando la sesión queda operativa."
        },
        {
            "modulo": None,
            "titulo": "Pantalla de Inicio de Conversación y Saludo Institucional",
            "marcador": "**Colocar imagen de código del archivo bot.js - función asegurarConversacion()**",
            "lenguaje": "javascript",
            "codigo": "".join(bot[431:493]).strip(),
            "descripcion": "Descripción: se muestra el código para registrar automáticamente al prospecto en la tabla CONTACTO y abrir una nueva sesión en CONVERSACION con estado EN_CURSO cuando el estudiante escribe su saludo inicial por WhatsApp."
        },
        {
            "modulo": None,
            "titulo": "Pantalla de Captura Académica: Universidad y Carrera",
            "marcador": "**Colocar imagen de código del archivo bot.js - definición de herramienta verificar_cobertura**",
            "lenguaje": "javascript",
            "codigo": "".join(bot[523:565]).strip(),
            "descripcion": "Descripción: se muestra el código para declarar la herramienta de Function Calling verificar_cobertura en GROK_TOOLS, instruyendo al modelo de IA sobre cómo extraer y estructurar el nombre de la universidad y carrera del estudiante."
        },
        {
            "modulo": None,
            "titulo": "Pantalla de Verificación de Cobertura y Cierre Activo (Caso A)",
            "marcador": "**Colocar imagen de código del archivo bot.js - función verificarCobertura() (Caso A)**",
            "lenguaje": "javascript",
            "codigo": "".join(bot[172:214]).strip(),
            "descripcion": "Descripción: se muestra el código para ejecutar la consulta relacional con INNER JOIN entre UNIVERSIDAD y CARRERA, validando que ambos campos tengan atendida = 1 para emitir la confirmación de cobertura y cierre activo."
        },
        {
            "modulo": None,
            "titulo": "Pantalla de Derivación a Lista de Espera Preferencial (Caso B - B06)",
            "marcador": "**Colocar imagen de código del archivo bot.js - función verificarCobertura() (Caso B sin cobertura)**",
            "lenguaje": "javascript",
            "codigo": "".join(bot[214:265]).strip(),
            "descripcion": "Descripción: se muestra el código para capturar la demanda de carreras no atendidas en verificarCobertura(), asignando cobertura = false y registrando al estudiante en la lista de espera para alimentar el KPI B06."
        },
        {
            "modulo": None,
            "titulo": "Pantalla de Filtro Académico y Mensajes Fuera de Tema (Off-Topic)",
            "marcador": "**Colocar imagen de código del archivo bot.js - System Prompt de Vicky (Contención de Alcance)**",
            "lenguaje": "javascript",
            "codigo": "".join(bot[600:650]).strip(),
            "descripcion": "Descripción: se muestra el código del System Prompt de Vicky en bot.js, delimitando las instrucciones de contención de alcance para que el agente rechace consultas ajenas al servicio de tesis sin alterar la base de datos."
        },
        {
            "modulo": None,
            "titulo": "Pantalla de Monitoreo en Consola y Trazabilidad Transaccional",
            "marcador": "**Colocar imagen de código del archivo bot.js - función registrarBuyerTransaccional()**",
            "lenguaje": "javascript",
            "codigo": "".join(bot[271:325]).strip(),
            "descripcion": "Descripción: se muestra el código para iniciar una transacción ACID en SQL Server con sql.Transaction, garantizando la inserción segura del contacto y la trazabilidad de la auditoría en la consola del servidor."
        },

        # =========================================================================
        # MODULO C
        # =========================================================================
        {
            "modulo": "C) DASHBOARD EJECUTIVO BI EN STREAMLIT (ROL ASESOR / ANALISTA BI)",
            "titulo": "Pantalla de Inicio y Panel de Indicadores Oficiales (B01, B02, B06, B07)",
            "marcador": "**Colocar imagen de código del archivo dashboard.py - función load_kpis()**",
            "lenguaje": "python",
            "codigo": "".join(dash[125:170]).strip(),
            "descripcion": "Descripción: se muestra el código para consultar y calcular en SQL Server los indicadores clave de rendimiento B01, B02, B06 y B07 dentro del tablero analítico desarrollado en Streamlit (dashboard.py)."
        },
        {
            "modulo": None,
            "titulo": "Pantalla de Analítica Gráfica y Distribución Demográfica",
            "marcador": "**Colocar imagen de código del archivo dashboard.py - renderizado de gráficos Plotly**",
            "lenguaje": "python",
            "codigo": "".join(dash[335:395]).strip(),
            "descripcion": "Descripción: se muestra el código para construir y renderizar los gráficos interactivos de barras y pastel con Plotly Express en Streamlit, visualizando la distribución de prospectos por universidad y estado de cobertura."
        },
        {
            "modulo": None,
            "titulo": "Pantalla de Gestión y Listado Maestro de Prospectos (Tabla de Buyers)",
            "marcador": "**Colocar imagen de código del archivo dashboard.py - función load_buyers_data()**",
            "lenguaje": "python",
            "codigo": "".join(dash[170:210]).strip(),
            "descripcion": "Descripción: se muestra el código para consultar la relación consolidada de prospectos en SQL Server con load_buyers_data(), transformando los datos en un DataFrame de Pandas para la tabla maestra del asesor."
        },
        {
            "modulo": None,
            "titulo": "Pantalla de Auditoría Conversacional y Trazabilidad de Diálogos",
            "marcador": "**Colocar imagen de código del archivo dashboard.py - función load_conversations_data()**",
            "lenguaje": "python",
            "codigo": "".join(dash[210:240]).strip(),
            "descripcion": "Descripción: se muestra el código para recuperar los diálogos completos de la tabla MENSAJE en SQL Server, permitiendo inspeccionar las transcripciones cronológicas entre el estudiante y Vicky en Streamlit."
        },
        {
            "modulo": None,
            "titulo": "Pantalla de Barra Lateral de Filtros y Recarga Dinámica",
            "marcador": "**Colocar imagen de código del archivo dashboard.py - controles en st.sidebar**",
            "lenguaje": "python",
            "codigo": "".join(dash[240:295]).strip(),
            "descripcion": "Descripción: se muestra el código para estructurar la barra lateral interactiva con st.sidebar en Streamlit, facilitando la recarga manual de datos y la aplicación de filtros dinámicos por universidad y estado de atención."
        },

        # =========================================================================
        # MODULO D
        # =========================================================================
        {
            "modulo": "D) DASHBOARD WEB MODERNO REACT & API REST (ROL ADMINISTRADOR GENERAL)",
            "titulo": "Pantalla de Estado del Servidor y Conectividad (/api/status)",
            "marcador": "**Colocar imagen de código del archivo server_dashboard.js - endpoint app.get('/api/status')**",
            "lenguaje": "javascript",
            "codigo": "".join(server[83:101]).strip(),
            "descripcion": "Descripción: se muestra el código del endpoint /api/status en Express, exponiendo un servicio REST que verifica en tiempo real la conectividad con SQL Server y el total de registros en la tabla BUYER."
        },
        {
            "modulo": None,
            "titulo": "Pantalla Principal del Portal Web React (Métricas en Tiempo Real)",
            "marcador": "**Colocar imagen de código del archivo frontend/src/App.jsx - sincronización y estado**",
            "lenguaje": "jsx",
            "codigo": "".join(app[20:75]).strip(),
            "descripcion": "Descripción: se muestra el código del componente principal App.jsx en React, implementando el auto-refresco periódico cada 3 segundos contra la API REST para mantener sincronizados los paneles de supervisión."
        },
        {
            "modulo": None,
            "titulo": "Pantalla de Control de Inversión Publicitaria y Costo por Buyer (B07)",
            "marcador": "**Colocar imagen de código del archivo server_dashboard.js - endpoint app.get('/api/kpis')**",
            "lenguaje": "javascript",
            "codigo": "".join(server[101:146]).strip(),
            "descripcion": "Descripción: se muestra el código del endpoint /api/kpis en server_dashboard.js, calculando el costo unitario por Buyer calificado (KPI B07) a partir de la inversión registrada en la tabla CAMPANIA."
        },
        {
            "modulo": None,
            "titulo": "Pantalla de Auditoría del Catálogo de Universidades y Carreras",
            "marcador": "**Colocar imagen de código del archivo server_dashboard.js - endpoint app.get('/api/buyers')**",
            "lenguaje": "javascript",
            "codigo": "".join(server[150:188]).strip(),
            "descripcion": "Descripción: se muestra el código del endpoint /api/buyers en Express, ejecutando una consulta relacional con JOINs cruzados para auditar el catálogo institucional frente a las postulaciones de los estudiantes."
        },

        # =========================================================================
        # MODULO E
        # =========================================================================
        {
            "modulo": "E) CONSOLA DE SIMULACIÓN Y VALIDACIÓN TÉCNICA (ROL TESTER / EVALUADOR)",
            "titulo": "Prueba de Chat en Modo Mensaje Único",
            "marcador": "**Colocar imagen de código del archivo simulador_chat.js - función modoMensajeUnico()**",
            "lenguaje": "javascript",
            "codigo": "".join(sim[439:460]).strip(),
            "descripcion": "Descripción: se muestra el código para ejecutar pruebas de un solo mensaje en simulador_chat.js, procesando la consulta directamente desde la línea de comandos sin requerir el escaneo de WhatsApp."
        },
        {
            "modulo": None,
            "titulo": "Prueba de Chat en Modo Interactivo Multiturno",
            "marcador": "**Colocar imagen de código del archivo simulador_chat.js - función modoInteractivo()**",
            "lenguaje": "javascript",
            "codigo": "".join(sim[459:500]).strip(),
            "descripcion": "Descripción: se muestra el código para iniciar la consola interactiva multiturno mediante readline en simulador_chat.js, evaluando la retención de contexto del agente conversación a conversación."
        },
        {
            "modulo": None,
            "titulo": "Prueba de Verificación de Transacciones Atómicas (Commit y Rollback)",
            "marcador": "**Colocar imagen de código del archivo bot.js - manejo de errores y rollback()**",
            "lenguaje": "javascript",
            "codigo": "".join(bot[395:430]).strip(),
            "descripcion": "Descripción: se muestra el código para garantizar el control transaccional en bot.js, ejecutando transaction.commit() tras el éxito y transaction.rollback() ante fallos para asegurar la consistencia de SQL Server."
        },
        {
            "modulo": None,
            "titulo": "Prueba de Contingencia y Motor Heurístico ante Caídas de API",
            "marcador": "**Colocar imagen de código del archivo bot.js - función procesarMensajeFallbackHeuristico()**",
            "lenguaje": "javascript",
            "codigo": "".join(bot[760:825]).strip(),
            "descripcion": "Descripción: se muestra el código del motor de contingencia procesarMensajeFallbackHeuristico() en bot.js, garantizando la continuidad operativa mediante expresiones regulares en caso de saturación o caída de la API de IA."
        }
    ]

    # Generar Markdown
    md = "# MANUAL DE CÓDIGO FUENTE\n\n"
    md += "## Agente Conversacional con IA para la Atracción, Filtro de Cobertura y Segmentación de Prospectos en Asesoría Académica\n\n"
    md += "---\n\n"

    for s in sections:
        if s["modulo"]:
            md += f"# {s['modulo']}\n\n"
        md += f"## {s['titulo']}\n\n"
        md += f"{s['marcador']}\n\n"
        md += f"```{s['lenguaje']}\n{s['codigo']}\n```\n\n"
        md += f"{s['descripcion']}\n\n---\n\n"

    with open('manual_codigo_fuente.md', 'w', encoding='utf-8') as f:
        f.write(md)

    print(f"manual_codigo_fuente.md generado exitosamente con {len(sections)} pantallas.")

if __name__ == '__main__':
    build_markdown()

