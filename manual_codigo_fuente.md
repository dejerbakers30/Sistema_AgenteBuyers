# MANUAL DE CÓDIGO FUENTE

## Agente Conversacional con IA para la Atracción, Filtro de Cobertura y Segmentación de Prospectos en Asesoría Académica

---

# A) ACCESO, CONFIGURACIÓN Y DIAGNÓSTICO DEL SISTEMA

## Pantalla de Configuración de Entorno (.env)

**Colocar imagen de código del archivo .env y carga de configuración en bot.js**

```ini
# ==============================================================================
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
STREAMLIT_PORT=8501
```

Descripción: se muestra el código de configuración de variables de entorno del sistema (.env), definiendo los parámetros de enlace para el protocolo de memoria compartida en SQL Server y las credenciales del motor de inferencia de IA.

---

## Pantalla de Diagnóstico Pre-Vuelo del Sistema

**Colocar imagen de código del archivo diagnostico_sistema.py - función test_sql_connection()**

```python
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
```

Descripción: se muestra el código para ejecutar el diagnóstico previo del sistema en diagnostico_sistema.py, comprobando los controladores ODBC, la conexión física a SQL Server y la integridad de las 9 tablas requeridas para la Fase Buyer.

---

## Pantalla de Inicialización de Servicios y Base de Datos

**Colocar imagen de código del archivo bot.js - función getDbPool() y arranque**

```javascript
async function getDbPool() {
    if (dbPool && dbPool.connected) return dbPool;
    try {
        dbPool = await sql.connect(dbConfig);
        console.log('✅ [SQL Server] Conexión establecida a INBESTIGA_TESIS');
    } catch (err) {
        console.error('❌ [SQL Server] Error al conectar:', err.message);
        throw err;
    }
    return dbPool;
}

/**
 * Configuración dinámica de IA:
 * Soporta Google Gemini, Groq Cloud, Grok (xAI) u OpenAI directamente.
 * Detecta automáticamente el proveedor según el formato de la clave o variables de entorno.
 */
const AI_API_KEY = process.env.AI_API_KEY || process.env.GEMINI_API_KEY || process.env.GROQ_API_KEY || process.env.XAI_API_KEY || 'dummy-key';

const isGoogle = !!process.env.GEMINI_API_KEY || AI_API_KEY.startsWith('AIza') || AI_API_KEY.startsWith('AQ.');

const AI_BASE_URL = process.env.AI_BASE_URL || (
    isGoogle
        ? 'https://generativelanguage.googleapis.com/v1beta/openai/'
        : (process.env.GROQ_API_KEY || AI_API_KEY.startsWith('gsk_'))
            ? 'https://api.groq.com/openai/v1'
            : 'https://api.x.ai/v1'
);

let AI_MODEL = process.env.AI_MODEL || process.env.GEMINI_MODEL;
if (!AI_MODEL || AI_MODEL === 'grok-2-latest' || AI_MODEL === 'gemini-3.8-flash') {
    if (AI_BASE_URL.includes('googleapis.com')) AI_MODEL = 'gemini-2.5-flash';
    else if (AI_BASE_URL.includes('groq.com')) AI_MODEL = 'llama-3.3-70b-versatile';
    else AI_MODEL = 'grok-2-latest';
}

const aiClient = new OpenAI({
    apiKey : AI_API_KEY,
    baseURL: AI_BASE_URL,
});

console.log(`🧠 [IA Config] Proveedor: ${AI_BASE_URL} | Modelo: ${AI_MODEL}`);

/**
 * Historial conversacional por número de WhatsApp.
 * Estructura: Map<string, Array<{role, content}>>
 */
const conversationHistory = new Map();

// ==============================================================================
// 2. HERRAMIENTAS DE BASE DE DATOS (FUNCTION CALLING)
// ==============================================================================

/**
 * Verifica si INBESTIGA atiende la universidad y carrera indicadas.
 * Estrategia de búsqueda en dos fases:
 *   - Fase 1: JOIN directo (nombre universidad LIKE) AND (nombre carrera LIKE).
 *   - Fase 2: Búsquedas independientes si el JOIN no devuelve resultados.
 *
 * @param {object} param0
```

Descripción: se muestra el código para inicializar el pool de conexiones a SQL Server con msnodesqlv8 en bot.js, verificando la disponibilidad del motor de base de datos antes de arrancar los servicios de mensajería.

---

# B) AGENTE CONVERSACIONAL WHATSAPP "VICKY" (ROL PROSPECTO / ESTUDIANTE)

## Pantalla de Vinculación WhatsApp Web (Escaneo de Código QR)

**Colocar imagen de código del archivo bot.js - eventos client.on('qr') y client.on('ready')**

```javascript
client.on('qr', (qr) => {
    console.log('\n╔════════════════════════════════════════════════════════╗');
    console.log('║  📲 ESCANEA ESTE QR CON WHATSAPP EN TU CELULAR         ║');
    console.log('║  (WhatsApp → Dispositivos vinculados → Vincular)        ║');
    console.log('╚════════════════════════════════════════════════════════╝\n');
    qrcode.generate(qr, { small: true });
});

client.on('authenticated', () => {
    console.log('🔑 [WhatsApp] Sesión autenticada correctamente.');
});

client.on('auth_failure', (msg) => {
    console.error('❌ [WhatsApp] Error de autenticación:', msg);
    console.error('   → Borra la carpeta .wwebjs_auth/ y reinicia el bot.');
});

client.on('disconnected', (reason) => {
    console.warn('⚠️  [WhatsApp] Desconectado:', reason);
    console.warn('   → Reiniciando conexión en 10 segundos...');
    setTimeout(() => client.initialize(), 10000);
});

client.on('ready', () => {
    console.log('\n╔════════════════════════════════════════════════════════╗');
    console.log('║  🤖 "VICKY" LISTA Y CONECTADA A WHATSAPP EN VIVO       ║');
    console.log('║     Esperando mensajes de estudiantes...                ║');
    console.log('╚════════════════════════════════════════════════════════╝\n');
});

// ── Evento principal: Mensaje entrante ───────────────────────────────────────
```

Descripción: se muestra el código para gestionar el ciclo de autenticación de WhatsApp Web mediante la biblioteca whatsapp-web.js, renderizando el código QR en terminal y notificando cuando la sesión queda operativa.

---

## Pantalla de Inicio de Conversación y Saludo Institucional

**Colocar imagen de código del archivo bot.js - función asegurarConversacion()**

```javascript
async function asegurarConversacion(whatsappNumber) {
    try {
        const pool = await getDbPool();

        // Buscar o crear CONTACTO temporal
        let ctRes = await pool.request()
            .input('wa', sql.VarChar(30), whatsappNumber)
            .query(`SELECT contacto_id FROM CONTACTO WHERE whatsapp = @wa`);

        let contactoId;
        if (ctRes.recordset.length > 0) {
            contactoId = ctRes.recordset[0].contacto_id;
        } else {
            const insRes = await pool.request()
                .input('wa', sql.VarChar(30), whatsappNumber)
                .query(`
                    INSERT INTO CONTACTO (
                        nombres, whatsapp,
                        consentimiento_contacto, fecha_registro, estado
                    ) VALUES (
                        'Estudiante WhatsApp', @wa,
                        1, SYSDATETIME(), 'ACTIVO'
                    );
                    SELECT SCOPE_IDENTITY() AS contacto_id;
                `);
            contactoId = insRes.recordset[0].contacto_id;
        }

        // Buscar conversación EN_CURSO o crear una nueva
        const convRes = await pool.request()
            .input('cid', sql.Int, contactoId)
            .query(`
                SELECT TOP 1 conversacion_id
                FROM CONVERSACION
                WHERE contacto_id = @cid AND estado = 'EN_CURSO'
                ORDER BY conversacion_id DESC
            `);

        if (convRes.recordset.length > 0) {
            return { contactoId, conversacionId: convRes.recordset[0].conversacion_id };
        }

        const newConv = await pool.request()
            .input('cid', sql.Int, contactoId)
            .query(`
                INSERT INTO CONVERSACION (
                    contacto_id, canal_id, campania_id,
                    fecha_inicio, resuelta_sin_humano, estado
                ) VALUES (
                    @cid, 1, NULL,
                    SYSDATETIME(), 1, 'EN_CURSO'
                );
                SELECT SCOPE_IDENTITY() AS conversacion_id;
            `);

        return { contactoId, conversacionId: newConv.recordset[0].conversacion_id };

    } catch (err) {
        console.error('⚠️  [asegurarConversacion] Error:', err.message);
        return { contactoId: null, conversacionId: null };
    }
}
```

Descripción: se muestra el código para registrar automáticamente al prospecto en la tabla CONTACTO y abrir una nueva sesión en CONVERSACION con estado EN_CURSO cuando el estudiante escribe su saludo inicial por WhatsApp.

---

## Pantalla de Captura Académica: Universidad y Carrera

**Colocar imagen de código del archivo bot.js - definición de herramienta verificar_cobertura**

```javascript
{
        type: 'function',
        function: {
            name       : 'verificar_cobertura',
            description: `Consulta en la base de datos de INBESTIGA si existe cobertura de asesoría
            de tesis para la universidad y carrera que indicó el estudiante (campo atendida = 1).
            Debe llamarse en cuanto el estudiante mencione su universidad y carrera.`,
            parameters: {
                type      : 'object',
                properties: {
                    universidad: {
                        type       : 'string',
                        description: 'Nombre completo o sigla de la universidad (ej. UNT, UPAO, UCV, Universidad Nacional de Trujillo).',
                    },
                    carrera: {
                        type       : 'string',
                        description: 'Nombre de la carrera o programa académico (ej. Ingeniería de Sistemas, Administración, Derecho).',
                    },
                },
                required: ['universidad', 'carrera'],
            },
        },
    },
    {
        type: 'function',
        function: {
            name       : 'registrar_buyer',
            description: `Registra al estudiante como Buyer de INBESTIGA en la base de datos
            (transacción atómica: CONTACTO → PERFIL_ACADEMICO → BUYER).
            Debe llamarse SIEMPRE después de verificar_cobertura, ya sea que haya o no cobertura.
            El campo tiene_cobertura determina si el BUYER se guarda como ACTIVO o SIN_COBERTURA.`,
            parameters: {
                type      : 'object',
                properties: {
                    nombres: {
                        type       : 'string',
                        description: 'Nombre(s) del estudiante.',
                    },
                    apellidos: {
                        type       : 'string',
                        description: 'Apellido(s) del estudiante (si los compartió).',
                    },
```

Descripción: se muestra el código para declarar la herramienta de Function Calling verificar_cobertura en GROK_TOOLS, instruyendo al modelo de IA sobre cómo extraer y estructurar el nombre de la universidad y carrera del estudiante.

---

## Pantalla de Verificación de Cobertura y Cierre Activo (Caso A)

**Colocar imagen de código del archivo bot.js - función verificarCobertura() (Caso A)**

```javascript
async function verificarCobertura({ universidad, carrera }) {
    console.log(`\n🔍 [verificar_cobertura] "${universidad}" | "${carrera}"`);
    try {
        const pool    = await getDbPool();
        const uFiltro = `%${universidad.trim()}%`;
        const cFiltro = `%${carrera.trim()}%`;

        // ── Fase 1: JOIN directo ──────────────────────────────────────────────
        const joinResult = await pool.request()
            .input('uFiltro', sql.VarChar(150), uFiltro)
            .input('cFiltro', sql.VarChar(150), cFiltro)
            .query(`
                SELECT TOP 1
                    u.universidad_id,
                    u.nombre     AS universidad_nombre,
                    u.atendida   AS universidad_atendida,
                    c.carrera_id,
                    c.nombre     AS carrera_nombre,
                    c.atendida   AS carrera_atendida
                FROM UNIVERSIDAD u
                INNER JOIN CARRERA c ON c.universidad_id = u.universidad_id
                WHERE u.nombre LIKE @uFiltro
                  AND c.nombre LIKE @cFiltro;
            `);

        if (joinResult.recordset.length > 0) {
            const row       = joinResult.recordset[0];
            const cobertura = !!(row.universidad_atendida) && !!(row.carrera_atendida);
            console.log(`   → JOIN directo: ${cobertura ? '✅ ACTIVA' : '⚠️ SIN COBERTURA'} (${row.universidad_nombre} - ${row.carrera_nombre})`);
            return {
                encontrado         : true,
                universidad_id     : row.universidad_id,
                universidad_nombre : row.universidad_nombre,
                carrera_id         : row.carrera_id,
                carrera_nombre     : row.carrera_nombre,
                cobertura,
                mensaje: cobertura
                    ? `Cobertura activa para ${row.carrera_nombre} en ${row.universidad_nombre}.`
                    : `La carrera o universidad no está atendida actualmente.`,
            };
        }
```

Descripción: se muestra el código para ejecutar la consulta relacional con INNER JOIN entre UNIVERSIDAD y CARRERA, validando que ambos campos tengan atendida = 1 para emitir la confirmación de cobertura y cierre activo.

---

## Pantalla de Derivación a Lista de Espera Preferencial (Caso B - B06)

**Colocar imagen de código del archivo bot.js - función verificarCobertura() (Caso B sin cobertura)**

```javascript
// ── Fase 2: búsquedas independientes ─────────────────────────────────
        const [uRes, cRes] = await Promise.all([
            pool.request()
                .input('uFiltro', sql.VarChar(150), uFiltro)
                .query(`SELECT TOP 1 universidad_id, nombre, atendida FROM UNIVERSIDAD WHERE nombre LIKE @uFiltro`),
            pool.request()
                .input('cFiltro', sql.VarChar(150), cFiltro)
                .query(`SELECT TOP 1 carrera_id, universidad_id, nombre, atendida FROM CARRERA WHERE nombre LIKE @cFiltro`),
        ]);

        const uFound = uRes.recordset[0] || null;
        const cFound = cRes.recordset[0] || null;

        if (uFound && cFound) {
            const cobertura = !!(uFound.atendida) && !!(cFound.atendida);
            console.log(`   → Búsqueda independiente: ${cobertura ? '✅ ACTIVA' : '⚠️ SIN COBERTURA'}`);
            return {
                encontrado         : true,
                universidad_id     : uFound.universidad_id,
                universidad_nombre : uFound.nombre,
                carrera_id         : cFound.carrera_id,
                carrera_nombre     : cFound.nombre,
                cobertura,
                mensaje: cobertura
                    ? `Cobertura confirmada para ${cFound.nombre} en ${uFound.nombre}.`
                    : `Universidad o carrera sin cobertura activa en este momento.`,
            };
        }

        // ── Sin resultados en catálogo ────────────────────────────────────────
        console.log('   → No encontrado en catálogo → SIN COBERTURA.');
        return {
            encontrado         : false,
            universidad_id     : uFound ? uFound.universidad_id : null,
            universidad_nombre : uFound ? uFound.nombre : universidad,
            carrera_id         : cFound ? cFound.carrera_id : 1, // fallback controlado
            carrera_nombre     : cFound ? cFound.nombre : carrera,
            cobertura          : false,
            mensaje            : 'La universidad o carrera no se encuentra en el catálogo oficial de INBESTIGA.',
        };

    } catch (err) {
        console.error('❌ [verificarCobertura] Error:', err.message);
        return { encontrado: false, cobertura: false, carrera_id: 1, error: err.message };
    }
}

/**
 * Registra transaccionalmente al estudiante como Buyer.
 * Orden garantizado sin violar claves foráneas:
 *   1. CONTACTO        (crea o actualiza)
```

Descripción: se muestra el código para capturar la demanda de carreras no atendidas en verificarCobertura(), asignando cobertura = false y registrando al estudiante en la lista de espera para alimentar el KPI B06.

---

## Pantalla de Filtro Académico y Mensajes Fuera de Tema (Off-Topic)

**Colocar imagen de código del archivo bot.js - System Prompt de Vicky (Contención de Alcance)**

```javascript
},
        },
    },
];

// ==============================================================================
// 5. SYSTEM PROMPT: PERSONALIDAD DE "VICKY"
// ==============================================================================

const SYSTEM_PROMPT = `
Eres "Vicky", la Asistente Virtual de Admisión de INBESTIGA, institución especializada en asesoría y acompañamiento integral de tesis universitarias en Perú.
Tu personalidad es 100% humana, cálida, empática, profesional y resolutiva. Jamás debes sonar como un robot ni revelar aspectos técnicos de la plataforma.

══════════════════════════════════════════════════════════════
REGLAS DE ORO DE COMUNICACIÓN (EXPERIENCIA DE USUARIO - UX):
══════════════════════════════════════════════════════════════
1. 🚫 PROHIBICIÓN TOTAL DE JERGA TÉCNICA E INTERNA:
   NUNCA menciones términos técnicos internos al estudiante (como "KPI", "KPI B06", "KPI B01", "Data Mart", "Fase Buyer", "BUYER ACTIVO", "Sin Cobertura", "Base de datos", "SQL", "Backend", etc.). Para el estudiante, eres una asesora académica humana y cercana que lo atiende por WhatsApp.

2. 💬 FLUJO CONVERSACIONAL Y HERRAMIENTAS:
   - Saludo: Preséntate amablemente como "Vicky de INBESTIGA".
   - Identificación: Solicita cordialmente el nombre del estudiante, su universidad y su carrera. Si el estudiante ya los proporcionó en su mensaje inicial, no los vuelvas a pedir.
   - Herramientas internas: En cuanto conozcas universidad y carrera, ejecuta "verificar_cobertura". Luego, con los datos recopilados, ejecuta "registrar_buyer".

3. 📋 PLANTILLAS EXACTAS DE RESPUESTA FINAL (OBLIGATORIAS):
   Una vez ejecutada la herramienta "registrar_buyer", tu respuesta final al usuario DEBE emplear EXACTAMENTE una de las siguientes dos plantillas, adaptando dinámicamente los campos entre corchetes según corresponda:

   ✅ CUANDO LA HERRAMIENTA verificar_cobertura RETORNE QUE SÍ HAY COBERTURA:
   "¡Hola [Nombre]! 🎉 Qué gusto saludarte, soy Vicky de INBESTIGA. Te confirmo que SÍ contamos con cobertura activa para tu carrera de [Carrera] en [Universidad]. Tus datos han quedado registrados exitosamente. En breve, un especialista te contactará para coordinar tu diagnóstico gratuito. 😊"

   ⚠️ CUANDO LA HERRAMIENTA verificar_cobertura RETORNE QUE NO HAY COBERTURA:
   "Hola [Nombre], soy Vicky de INBESTIGA. Lamentamos informarte que, por el momento, no contamos con cobertura activa para tu carrera en esa universidad. No obstante, hemos registrado tus datos en nuestra lista de espera preferencial. Apenas aperturemos nuevas vacantes, te notificaremos de inmediato. ¡Muchas gracias por tu interés! 🙏"

4. ✨ REGLAS DE ESTILO Y TONO:
   - Mantén el uso de emojis exactamente tal cual está en las plantillas (🎉, 😊, 🙏).
   - NUNCA inventes precios ni tarifas. Si te preguntan por costos, di: "Ese detalle lo coordinará contigo el especialista durante tu sesión de diagnóstico gratuita 😊".
   - Mantén un tono empático, profesional y natural en todo momento.

5. 🛡️ MENSAJES FUERA DE TEMA (OFF-TOPIC):
   Si el usuario pregunta o comenta algo que no tiene relación con asesoría de tesis ni investigación universitaria (por ejemplo: otros servicios, productos ajenos, bromas, tareas de colegio, temas personales o preguntas generales):
   - NO llames a ninguna herramienta ("verificar_cobertura" ni "registrar_buyer").
   - Responde de forma amable, empática y profesional aclarando el alcance de INBESTIGA y redirigiendo la conversación:
   "¡Hola! En INBESTIGA nos dedicamos exclusivamente a la asesoría, desarrollo y acompañamiento de tesis y proyectos de grado universitario. 🎓 Si estás realizando tu tesis o investigación, cuéntame: ¿en qué universidad estudias y qué carrera cursas? ¡Con gusto te ayudo! 😊"
`.trim();

// ==============================================================================
// 6. MOTOR DE PROCESAMIENTO IA (GROK + FUNCTION CALLING)
// ==============================================================================

/**
```

Descripción: se muestra el código del System Prompt de Vicky en bot.js, delimitando las instrucciones de contención de alcance para que el agente rechace consultas ajenas al servicio de tesis sin alterar la base de datos.

---

## Pantalla de Monitoreo en Consola y Trazabilidad Transaccional

**Colocar imagen de código del archivo bot.js - función registrarBuyerTransaccional()**

```javascript
async function registrarBuyerTransaccional(data) {
    console.log(`\n📝 [registrar_buyer] Iniciando transacción para: ${data.nombres} (${data.whatsapp})`);
    const pool        = await getDbPool();
    const transaction = new sql.Transaction(pool);

    try {
        await transaction.begin();

        // ── 1. CONTACTO ───────────────────────────────────────────────────────
        const checkContacto = await new sql.Request(transaction)
            .input('whatsapp', sql.VarChar(30), data.whatsapp)
            .query(`SELECT contacto_id FROM CONTACTO WHERE whatsapp = @whatsapp`);

        let contactoId;

        if (checkContacto.recordset.length > 0) {
            // Ya existe: actualizar nombre si se conoce más información
            contactoId = checkContacto.recordset[0].contacto_id;
            await new sql.Request(transaction)
                .input('contacto_id', sql.Int,       contactoId)
                .input('nombres',     sql.VarChar(100), data.nombres || 'Estudiante')
                .input('apellidos',   sql.VarChar(100), data.apellidos || null)
                .input('correo',      sql.VarChar(150), data.correo   || null)
                .query(`
                    UPDATE CONTACTO
                    SET  nombres   = @nombres,
                         apellidos = @apellidos,
                         correo    = ISNULL(@correo, correo)
                    WHERE contacto_id = @contacto_id
                `);
            console.log(`   ♻️  CONTACTO existente actualizado: ID ${contactoId}`);
        } else {
            // Nuevo contacto
            const insContacto = await new sql.Request(transaction)
                .input('nombres',   sql.VarChar(100),  data.nombres   || 'Estudiante WhatsApp')
                .input('apellidos', sql.VarChar(100),  data.apellidos || null)
                .input('whatsapp',  sql.VarChar(30),   data.whatsapp)
                .input('correo',    sql.VarChar(150),  data.correo    || null)
                .query(`
                    INSERT INTO CONTACTO (
                        nombres, apellidos, whatsapp, correo,
                        consentimiento_contacto, fecha_consentimiento,
                        no_contactar, fecha_registro, estado
                    ) VALUES (
                        @nombres, @apellidos, @whatsapp, @correo,
                        1, SYSDATETIME(),
                        0, SYSDATETIME(), 'ACTIVO'
                    );
                    SELECT SCOPE_IDENTITY() AS contacto_id;
                `);
            contactoId = insContacto.recordset[0].contacto_id;
            console.log(`   ✅ CONTACTO nuevo creado: ID ${contactoId}`);
        }
```

Descripción: se muestra el código para iniciar una transacción ACID en SQL Server con sql.Transaction, garantizando la inserción segura del contacto y la trazabilidad de la auditoría en la consola del servidor.

---

# C) DASHBOARD EJECUTIVO BI EN STREAMLIT (ROL ASESOR / ANALISTA BI)

## Pantalla de Inicio y Panel de Indicadores Oficiales (B01, B02, B06, B07)

**Colocar imagen de código del archivo dashboard.py - función load_kpis()**

```python
def load_kpis():
    """Calcula los indicadores oficiales B01, B02, B06 y B07 de la Fase BUYER."""
    conn = get_db_connection()
    if conn is None:
        return None
    try:
        query = """
        SELECT
            total_buyers = (SELECT COUNT(*) FROM BUYER),
            total_leads  = (SELECT COUNT(*) FROM LEAD),
            interacciones_valor = (SELECT COUNT(*) FROM INTERACCION_CAPTACION WHERE es_valor = 1),
            demanda_sin_cobertura = (SELECT COUNT(*) FROM BUYER WHERE estado = 'SIN_COBERTURA'),
            total_inversion = (SELECT ISNULL(SUM(inversion), 0) FROM CAMPANIA);
        """
        df = pd.read_sql(query, conn)
    finally:
        conn.close()

    total_buyers = int(df['total_buyers'].iloc[0])
    total_leads = int(df['total_leads'].iloc[0])
    interacciones_valor = int(df['interacciones_valor'].iloc[0])
    demanda_sin_cobertura = int(df['demanda_sin_cobertura'].iloc[0])
    total_inversion = float(df['total_inversion'].iloc[0])

    # B01: Tasa de Conversión BUYER -> LEAD (%)
    kpi_b01 = (total_leads / total_buyers * 100.0) if total_buyers > 0 else 0.0
    # B02: Tasa de Interacción de Valor (%)
    kpi_b02 = (interacciones_valor / total_buyers * 100.0) if total_buyers > 0 else 0.0
    # B06: Demanda Fuera de Cobertura (cantidad)
    kpi_b06 = demanda_sin_cobertura
    # B07: Costo por Buyer (S/)
    kpi_b07 = (total_inversion / total_buyers) if total_buyers > 0 else 0.0

    return {
        "b01": kpi_b01,
        "b02": kpi_b02,
        "b06": kpi_b06,
        "b07": kpi_b07,
        "total_buyers": total_buyers,
        "total_leads": total_leads,
        "interacciones_valor": interacciones_valor,
        "total_inversion": total_inversion
    }

@st.cache_data(ttl=2)
```

Descripción: se muestra el código para consultar y calcular en SQL Server los indicadores clave de rendimiento B01, B02, B06 y B07 dentro del tablero analítico desarrollado en Streamlit (dashboard.py).

---

## Pantalla de Analítica Gráfica y Distribución Demográfica

**Colocar imagen de código del archivo dashboard.py - renderizado de gráficos Plotly**

```python
color_discrete_map={'ACTIVO': '#10b981', 'SIN_COBERTURA': '#ef4444'},
            labels={'universidad': 'Universidad', 'cantidad': 'Total Buyers', 'estado_buyer': 'Estado'}
        )
        fig_u.update_layout(
            margin=dict(l=10, r=20, t=40, b=20),
            height=320,
            yaxis={'categoryorder': 'total ascending'},
            legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1)
        )
        st.plotly_chart(fig_u, use_container_width=True)
    else:
        st.info("No hay datos suficientes para graficar por universidad.")

with graf_col2:
    # Gráfico 2: Dona - Distribución de Estado de Buyers
    if not df_buyers.empty:
        df_pie = df_buyers['estado_buyer'].value_counts().reset_index()
        df_pie.columns = ['estado_buyer', 'total']
        fig_pie = px.pie(
            df_pie,
            names='estado_buyer',
            values='total',
            hole=0.55,
            title="Distribución de Estado de Buyers",
            color='estado_buyer',
            color_discrete_map={'ACTIVO': '#10b981', 'SIN_COBERTURA': '#ef4444'}
        )
        fig_pie.update_layout(
            margin=dict(l=10, r=10, t=40, b=20),
            height=320,
            legend=dict(orientation="h", yanchor="bottom", y=-0.1, xanchor="center", x=0.5)
        )
        st.plotly_chart(fig_pie, use_container_width=True)
    else:
        st.info("Sin datos para distribución de estado.")

# Gráfico 3: Línea de tiempo - Buyers registrados por día (últimos 30 días)
if not df_buyers.empty:
    df_line = df_buyers.copy()
    df_line['fecha_dia'] = pd.to_datetime(df_line['fecha_buyer']).dt.date
    fecha_limite = (datetime.now() - timedelta(days=30)).date()
    df_line = df_line[df_line['fecha_dia'] >= fecha_limite]

    df_dias = df_line.groupby('fecha_dia').size().reset_index(name='buyers_registrados')
    df_dias['fecha_dia'] = pd.to_datetime(df_dias['fecha_dia'])
    df_dias = df_dias.sort_values('fecha_dia')

    fig_line = px.line(
        df_dias,
        x='fecha_dia',
        y='buyers_registrados',
        markers=True,
        title="Evolución de Buyers Registrados por Día (Últimos 30 días)",
        labels={'fecha_dia': 'Fecha', 'buyers_registrados': 'N° de Buyers'},
        line_shape='linear'
    )
    fig_line.update_traces(line_color='#2563eb', line_width=3, marker=dict(size=8, color='#1d4ed8'))
    fig_line.update_layout(margin=dict(l=20, r=20, t=40, b=20), height=260)
    st.plotly_chart(fig_line, use_container_width=True)
```

Descripción: se muestra el código para construir y renderizar los gráficos interactivos de barras y pastel con Plotly Express en Streamlit, visualizando la distribución de prospectos por universidad y estado de cobertura.

---

## Pantalla de Gestión y Listado Maestro de Prospectos (Tabla de Buyers)

**Colocar imagen de código del archivo dashboard.py - función load_buyers_data()**

```python
def load_buyers_data():
    """Consulta los registros de la tabla BUYER y sus relaciones académicas."""
    conn = get_db_connection()
    if conn is None:
        return None
    try:
        query = """
        SELECT 
            b.buyer_id,
            b.fecha_buyer,
            b.estado AS estado_buyer,
            b.necesidad_inicial,
            c.contacto_id,
            c.nombres,
            c.apellidos,
            CONCAT(c.nombres, CASE WHEN c.apellidos IS NOT NULL AND c.apellidos NOT IN ('', 'Por Asignar') THEN ' ' + c.apellidos ELSE '' END) AS nombre_completo,
            c.whatsapp,
            c.correo,
            pa.etapa_academica,
            pa.ciclo,
            pa.sede,
            cr.carrera_id,
            cr.nombre AS carrera,
            cr.atendida AS carrera_atendida,
            u.universidad_id,
            u.nombre AS universidad,
            u.atendida AS universidad_atendida
        FROM BUYER b
        INNER JOIN CONTACTO c ON c.contacto_id = b.contacto_id
        LEFT JOIN PERFIL_ACADEMICO pa ON pa.contacto_id = c.contacto_id
        LEFT JOIN CARRERA cr ON cr.carrera_id = pa.carrera_id
        LEFT JOIN UNIVERSIDAD u ON u.universidad_id = cr.universidad_id
        ORDER BY b.buyer_id DESC;
        """
        df = pd.read_sql(query, conn)
        return df
    finally:
        conn.close()

@st.cache_data(ttl=2)
```

Descripción: se muestra el código para consultar la relación consolidada de prospectos en SQL Server con load_buyers_data(), transformando los datos en un DataFrame de Pandas para la tabla maestra del asesor.

---

## Pantalla de Auditoría Conversacional y Trazabilidad de Diálogos

**Colocar imagen de código del archivo dashboard.py - función load_conversations_data()**

```python
def load_conversations_data():
    """Consulta los mensajes registrados en la tabla MENSAJE para auditoría."""
    conn = get_db_connection()
    if conn is None:
        return None
    try:
        query = """
        SELECT 
            m.mensaje_id,
            m.conversacion_id,
            m.fecha_mensaje,
            m.emisor,
            m.tipo AS tipo_mensaje,
            m.contenido,
            c.whatsapp,
            CONCAT(c.nombres, ' ', ISNULL(c.apellidos, '')) AS nombre_completo
        FROM MENSAJE m
        INNER JOIN CONVERSACION conv ON conv.conversacion_id = m.conversacion_id
        INNER JOIN CONTACTO c ON c.contacto_id = conv.contacto_id
        ORDER BY m.mensaje_id DESC;
        """
        df = pd.read_sql(query, conn)
        return df
    finally:
        conn.close()

# ------------------------------------------------------------------------------
# 3. SIDEBAR Y AUTO-REFRESCO
# ------------------------------------------------------------------------------
with st.sidebar:
```

Descripción: se muestra el código para recuperar los diálogos completos de la tabla MENSAJE en SQL Server, permitiendo inspeccionar las transcripciones cronológicas entre el estudiante y Vicky en Streamlit.

---

## Pantalla de Barra Lateral de Filtros y Recarga Dinámica

**Colocar imagen de código del archivo dashboard.py - controles en st.sidebar**

```python
st.title("🎓 INBESTIGA BI")
    st.caption("Fase BUYER - Monitoreo en Vivo")
    st.markdown("---")

    if st.button("🔄 Refrescar Datos Ahora", use_container_width=True):
        st.cache_data.clear()
        st.rerun()

    auto_refresh = st.checkbox("🔄 Auto-refresco en vivo", value=True)
    st.caption("Intervalo: 3 segundos")

    st.markdown("---")
    timestamp_lectura = datetime.now().strftime("%d/%m/%Y %H:%M:%S")
    st.markdown(f"**Última lectura:**  \n`{timestamp_lectura}`")

# ------------------------------------------------------------------------------
# 4. CARGA DE DATOS CON CONTROL ROBUSTO DE ERRORES
# ------------------------------------------------------------------------------
kpi_data = load_kpis()
df_buyers = load_buyers_data()
df_chat = load_conversations_data()

if kpi_data is None or df_buyers is None or df_chat is None:
    st.stop()

# Encabezado Principal
st.title("📊 Panel de Inteligencia de Negocios - Fase BUYER")
st.markdown("Supervisión de captación de prospectos por WhatsApp, evaluación de cobertura académica y conversión a LEAD.")

# ------------------------------------------------------------------------------
# 5. PARTE SUPERIOR: KPIs EN 4 TARJETAS CON CSS PERSONALIZADO
# ------------------------------------------------------------------------------
col1, col2, col3, col4 = st.columns(4)

with col1:
    st.markdown(f"""
    <div class="kpi-card kpi-card-green">
        <div class="kpi-code kpi-code-green">KPI B01</div>
        <div class="kpi-label">Tasa Conversión BUYER → LEAD</div>
        <div class="kpi-value kpi-value-green">{kpi_data['b01']:.1f}%</div>
        <div class="kpi-desc">{kpi_data['total_leads']} leads de {kpi_data['total_buyers']} buyers</div>
    </div>
    """, unsafe_allow_html=True)

with col2:
    st.markdown(f"""
    <div class="kpi-card kpi-card-green">
        <div class="kpi-code kpi-code-green">KPI B02</div>
        <div class="kpi-label">Tasa Interacción de Valor</div>
        <div class="kpi-value kpi-value-green">{kpi_data['b02']:.1f}%</div>
        <div class="kpi-desc">{kpi_data['interacciones_valor']} interacciones de valor</div>
    </div>
    """, unsafe_allow_html=True)

with col3:
```

Descripción: se muestra el código para estructurar la barra lateral interactiva con st.sidebar en Streamlit, facilitando la recarga manual de datos y la aplicación de filtros dinámicos por universidad y estado de atención.

---

# D) DASHBOARD WEB MODERNO REACT & API REST (ROL ADMINISTRADOR GENERAL)

## Pantalla de Estado del Servidor y Conectividad (/api/status)

**Colocar imagen de código del archivo server_dashboard.js - endpoint app.get('/api/status')**

```javascript
app.get('/api/status', async (req, res) => {
    try {
        const p = await getPool();
        const result = await p.request().query('SELECT SYSDATETIME() AS server_time, DB_NAME() AS db_name');
        res.json({
            status: 'online',
            db_connected: true,
            db_name: result.recordset[0].db_name,
            server_time: result.recordset[0].server_time
        });
    } catch (err) {
        res.status(500).json({ status: 'error', message: err.message });
    }
});

/**
 * GET /api/kpis - Cálculo de indicadores oficiales B01, B02, B06, B07
 */
```

Descripción: se muestra el código del endpoint /api/status en Express, exponiendo un servicio REST que verifica en tiempo real la conectividad con SQL Server y el total de registros en la tabla BUYER.

---

## Pantalla Principal del Portal Web React (Métricas en Tiempo Real)

**Colocar imagen de código del archivo frontend/src/App.jsx - sincronización y estado**

```jsx
const [searchTerm, setSearchTerm] = useState('');
  const [filterStatus, setFilterStatus] = useState('ALL');
  const [selectedPhone, setSelectedPhone] = useState(null);

  // Sincronización con el backend REST API
  const fetchData = async (showSpinner = false) => {
    if (showSpinner) setIsRefreshing(true);
    try {
      const [kpiRes, buyersRes, convRes] = await Promise.all([
        fetch('/api/kpis').then(r => r.json()),
        fetch('/api/buyers').then(r => r.json()),
        fetch('/api/conversaciones').then(r => r.json())
      ]);

      setKpis(kpiRes);
      setBuyers(buyersRes || []);
      setConversaciones(convRes || []);
      setLastUpdated(new Date().toLocaleTimeString());
    } catch (err) {
      console.error('Error al sincronizar con SQL Server:', err);
    } finally {
      setLoading(false);
      if (showSpinner) setTimeout(() => setIsRefreshing(false), 500);
    }
  };

  useEffect(() => {
    fetchData(false);
    let interval = null;
    if (autoRefresh) {
      interval = setInterval(() => {
        fetchData(false);
      }, 3000);
    }
    return () => {
      if (interval) clearInterval(interval);
    };
  }, [autoRefresh]);

  if (loading && !kpis) {
    return (
      <div className="min-h-screen flex flex-col items-center justify-center bg-slate-50">
        <div className="w-16 h-16 border-4 border-indigo-200 border-t-indigo-600 rounded-full animate-spin"></div>
        <p className="mt-4 text-slate-600 font-semibold text-lg">Cargando métricas de SQL Server...</p>
        <p className="text-sm text-slate-400">INBESTIGA_TESIS · Fase BUYER</p>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex flex-col bg-slate-50">
      <Header
        lastUpdated={lastUpdated}
        autoRefresh={autoRefresh}
        setAutoRefresh={setAutoRefresh}
```

Descripción: se muestra el código del componente principal App.jsx en React, implementando el auto-refresco periódico cada 3 segundos contra la API REST para mantener sincronizados los paneles de supervisión.

---

## Pantalla de Control de Inversión Publicitaria y Costo por Buyer (B07)

**Colocar imagen de código del archivo server_dashboard.js - endpoint app.get('/api/kpis')**

```javascript
app.get('/api/kpis', async (req, res) => {
    try {
        const p = await getPool();
        const query = `
            SELECT
                total_buyers = (SELECT COUNT(*) FROM BUYER),
                total_leads  = (SELECT COUNT(*) FROM LEAD),
                interacciones_valor = (SELECT COUNT(*) FROM INTERACCION_CAPTACION WHERE es_valor = 1),
                demanda_sin_cobertura = (SELECT COUNT(*) FROM BUYER WHERE estado = 'SIN_COBERTURA'),
                total_inversion = (SELECT ISNULL(SUM(inversion), 0) FROM CAMPANIA);
        `;
        const result = await p.request().query(query);
        const row = result.recordset[0];

        const total_buyers = parseInt(row.total_buyers, 10) || 0;
        const total_leads = parseInt(row.total_leads, 10) || 0;
        const interacciones_valor = parseInt(row.interacciones_valor, 10) || 0;
        const demanda_sin_cobertura = parseInt(row.demanda_sin_cobertura, 10) || 0;
        const total_inversion = parseFloat(row.total_inversion) || 0.0;

        const b01 = total_buyers > 0 ? (total_leads / total_buyers * 100.0) : 0.0;
        const b02 = total_buyers > 0 ? (interacciones_valor / total_buyers * 100.0) : 0.0;
        const b06 = demanda_sin_cobertura;
        const b07 = total_buyers > 0 ? (total_inversion / total_buyers) : 0.0;
        const buyers_activos = total_buyers - demanda_sin_cobertura;
        const tasa_cobertura = total_buyers > 0 ? (buyers_activos / total_buyers * 100.0) : 0.0;

        res.json({
            b01: Number(b01.toFixed(1)),
            b02: Number(b02.toFixed(1)),
            b06: b06,
            b07: Number(b07.toFixed(2)),
            total_buyers,
            total_leads,
            interacciones_valor,
            demanda_sin_cobertura,
            buyers_activos,
            tasa_cobertura: Number(tasa_cobertura.toFixed(1)),
            total_inversion: Number(total_inversion.toFixed(2))
        });
    } catch (err) {
        console.error('❌ [API /kpis] Error:', err.message);
        res.status(500).json({ error: err.message });
    }
});
```

Descripción: se muestra el código del endpoint /api/kpis en server_dashboard.js, calculando el costo unitario por Buyer calificado (KPI B07) a partir de la inversión registrada en la tabla CAMPANIA.

---

## Pantalla de Auditoría del Catálogo de Universidades y Carreras

**Colocar imagen de código del archivo server_dashboard.js - endpoint app.get('/api/buyers')**

```javascript
app.get('/api/buyers', async (req, res) => {
    try {
        const p = await getPool();
        const query = `
            SELECT 
                b.buyer_id,
                b.fecha_buyer,
                b.estado AS estado_buyer,
                b.necesidad_inicial,
                c.contacto_id,
                c.nombres,
                c.apellidos,
                CONCAT(c.nombres, CASE WHEN c.apellidos IS NOT NULL AND c.apellidos NOT IN ('', 'Por Asignar') THEN ' ' + c.apellidos ELSE '' END) AS nombre_completo,
                c.whatsapp,
                c.correo,
                pa.etapa_academica,
                pa.ciclo,
                pa.sede,
                cr.carrera_id,
                cr.nombre AS carrera,
                cr.atendida AS carrera_atendida,
                u.universidad_id,
                u.nombre AS universidad,
                u.atendida AS universidad_atendida
            FROM BUYER b
            INNER JOIN CONTACTO c ON c.contacto_id = b.contacto_id
            LEFT JOIN PERFIL_ACADEMICO pa ON pa.contacto_id = c.contacto_id
            LEFT JOIN CARRERA cr ON cr.carrera_id = pa.carrera_id
            LEFT JOIN UNIVERSIDAD u ON u.universidad_id = cr.universidad_id
            ORDER BY b.buyer_id DESC;
        `;
        const result = await p.request().query(query);
        res.json(result.recordset);
    } catch (err) {
        console.error('❌ [API /buyers] Error:', err.message);
        res.status(500).json({ error: err.message });
    }
});
```

Descripción: se muestra el código del endpoint /api/buyers en Express, ejecutando una consulta relacional con JOINs cruzados para auditar el catálogo institucional frente a las postulaciones de los estudiantes.

---

# E) CONSOLA DE SIMULACIÓN Y VALIDACIÓN TÉCNICA (ROL TESTER / EVALUADOR)

## Prueba de Chat en Modo Mensaje Único

**Colocar imagen de código del archivo simulador_chat.js - función modoMensajeUnico()**

```javascript
async function modoMensajeUnico(pool, mensaje, telefono) {
    console.log(`\n${'═'.repeat(65)}`);
    console.log('  🚀 SIMULADOR INBESTIGA · Modo: Mensaje Único');
    console.log(`${'═'.repeat(65)}`);
    console.log(`📱 Remitente : ${telefono}`);
    console.log(`💬 Mensaje   : "${mensaje}"`);
    console.log(SEP);

    const messages = [{ role: 'system', content: SYSTEM_PROMPT_SIMULADOR }];

    console.log('\n🧠 Procesando con Grok (xAI) + Function Calling...');
    const reply = await procesarTurno(pool, messages, mensaje, telefono);

    console.log(`\n${SEP}`);
    console.log('🤖 RESPUESTA FINAL DE VICKY:');
    console.log(`\n   "${reply}"`);
    console.log(`\n${SEP}`);
    console.log('✅ Verifica el nuevo registro en el Dashboard de Streamlit.');
}

async function modoInteractivo(pool, telefono) {
```

Descripción: se muestra el código para ejecutar pruebas de un solo mensaje en simulador_chat.js, procesando la consulta directamente desde la línea de comandos sin requerir el escaneo de WhatsApp.

---

## Prueba de Chat en Modo Interactivo Multiturno

**Colocar imagen de código del archivo simulador_chat.js - función modoInteractivo()**

```javascript
async function modoInteractivo(pool, telefono) {
    console.log(`\n${'═'.repeat(65)}`);
    console.log('  💬 SIMULADOR INBESTIGA · Modo: Conversación Interactiva');
    console.log(`${'═'.repeat(65)}`);
    console.log(`📱 Simulando número: ${telefono}`);
    console.log('   (Escribe "salir" para terminar)\n');

    const messages = [{ role: 'system', content: SYSTEM_PROMPT_SIMULADOR }];
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });

    // Mensaje inicial de Vicky
    const bienvenida = await procesarTurno(pool, messages, '¡Hola!', telefono);
    console.log(`\n🤖 Vicky: ${bienvenida}\n`);

    const preguntar = () => {
        rl.question('👤 Tú: ', async (input) => {
            const texto = input.trim();
            if (!texto || texto.toLowerCase() === 'salir') {
                console.log('\n👋 Sesión finalizada. ¡Hasta pronto!');
                rl.close();
                return;
            }
            try {
                console.log('\n⏳ Vicky está escribiendo...');
                const reply = await procesarTurno(pool, messages, texto, telefono);
                console.log(`\n🤖 Vicky: ${reply}\n`);
            } catch (err) {
                console.error('❌ Error:', err.message);
            }
            preguntar(); // siguiente turno
        });
    };

    preguntar();
}

// ==============================================================================
// Entrada principal
// ==============================================================================

(async () => {
```

Descripción: se muestra el código para iniciar la consola interactiva multiturno mediante readline en simulador_chat.js, evaluando la retención de contexto del agente conversación a conversación.

---

## Prueba de Verificación de Transacciones Atómicas (Commit y Rollback)

**Colocar imagen de código del archivo bot.js - manejo de errores y rollback()**

```javascript
SELECT SCOPE_IDENTITY() AS buyer_id;
                `);
            buyerId = insBuyer.recordset[0].buyer_id;
            console.log(`   ✅ BUYER nuevo: ID ${buyerId} → ${estadoBuyer}`);
        }

        // ── COMMIT atómico ────────────────────────────────────────────────────
        await transaction.commit();
        console.log(`   🎉 Transacción COMMIT OK · BUYER ${buyerId} [${estadoBuyer}]`);

        return {
            exito       : true,
            contacto_id : contactoId,
            buyer_id    : buyerId,
            estado      : estadoBuyer,
            mensaje     : `Registro completado con estado ${estadoBuyer}.`,
        };

    } catch (err) {
        try { await transaction.rollback(); } catch (_) { /* ya cerrada */ }
        console.error('❌ [registrarBuyer] ROLLBACK:', err.message);
        return { exito: false, error: err.message };
    }
}

// ==============================================================================
// 3. AUDITORÍA: CONVERSACION Y MENSAJE
// ==============================================================================

/**
 * Garantiza que exista un CONTACTO y una CONVERSACION activa para el número.
 * Reutiliza conversación EN_CURSO si ya hay una abierta.
 *
 * @param {string} whatsappNumber - Número limpio (sin @c.us, sin +51).
 * @returns {Promise<{contactoId: number|null, conversacionId: number|null}>}
```

Descripción: se muestra el código para garantizar el control transaccional en bot.js, ejecutando transaction.commit() tras el éxito y transaction.rollback() ante fallos para asegurar la consistencia de SQL Server.

---

## Prueba de Contingencia y Motor Heurístico ante Caídas de API

**Colocar imagen de código del archivo bot.js - función procesarMensajeFallbackHeuristico()**

```javascript
async function procesarMensajeFallbackHeuristico(userPhone, userMessage) {
    // Si el mensaje es ajeno a temas académicos o un simple saludo sin datos
    const tieneTerminoAcademico = /tesis|proyecto|grado|universidad|carrera|unt|upao|ucv|upn|uct|asesor|estudi|bachiller/i.test(userMessage);
    if (!tieneTerminoAcademico && !/sistemas|derecho|administra|psicolog|contab/i.test(userMessage)) {
        return '¡Hola! En INBESTIGA nos dedicamos exclusivamente a la asesoría, desarrollo y acompañamiento de tesis y proyectos de grado universitario. 🎓 Si estás realizando tu tesis o investigación, cuéntame: ¿en qué universidad estudias y qué carrera cursas? ¡Con gusto te ayudo! 😊';
    }

    let uni = 'UNT';
    if (/upao|antenor/i.test(userMessage)) uni = 'Universidad Privada Antenor Orrego';
    else if (/ucv|vallejo/i.test(userMessage)) uni = 'Universidad Cesar Vallejo';
    else if (/upn|norte/i.test(userMessage)) uni = 'Universidad Privada del Norte';
    else if (/uct|catolica/i.test(userMessage)) uni = 'Universidad Catolica de Trujillo';
    else if (/unt|nacional.*trujillo/i.test(userMessage)) uni = 'Universidad Nacional de Trujillo';
    else if (/lima|san\s*marcos|unmsm|pucp|uni\b/i.test(userMessage)) uni = 'Universidad de Lima';

    let car = 'Ingenieria de Sistemas';
    if (/administra/i.test(userMessage)) car = 'Administracion';
    else if (/sistemas|software|comput/i.test(userMessage)) car = 'Ingenieria de Sistemas';
    else if (/derecho|aboga/i.test(userMessage)) car = 'Derecho';
    else if (/diseño|grafic/i.test(userMessage)) car = 'Diseño Grafico';
    else if (/psicolog/i.test(userMessage)) car = 'Psicologia';
    else if (/contab/i.test(userMessage)) car = 'Contabilidad';

    let nom = 'Estudiante';
    const mNom = userMessage.match(/(?:me llamo|soy|mi nombre es)\s+([A-ZÁÉÍÓÚa-záéíóúñ]+(?:\s+[A-ZÁÉÍÓÚa-záéíóúñ]+)?)/i);
    if (mNom && mNom[1]) {
        nom = mNom[1].trim();
    }

    // 1. Verificar cobertura
    const cov = await verificarCobertura({ universidad: uni, carrera: car });

    // 2. Registrar buyer transaccional
    await registrarBuyerTransaccional({
        nombres: nom,
        whatsapp: userPhone,
        carrera_id: cov.carrera_id || 1,
        tiene_cobertura: cov.cobertura,
        necesidad_inicial: 'Asesoría Integral de Tesis'
    });

    // 3. Respuesta de Vicky
    if (cov.cobertura) {
        return `¡Hola ${nom}! 🎉 Qué gusto saludarte, soy Vicky de INBESTIGA. Te confirmo que SÍ contamos con cobertura activa para tu carrera de ${cov.carrera_nombre || car} en ${cov.universidad_nombre || uni}. Tus datos han quedado registrados exitosamente. En breve, un especialista te contactará para coordinar tu diagnóstico gratuito. 😊`;
    } else {
        return `Hola ${nom}, soy Vicky de INBESTIGA. Lamentamos informarte que, por el momento, no contamos con cobertura activa para tu carrera en esa universidad. No obstante, hemos registrado tus datos en nuestra lista de espera preferencial. Apenas aperturemos nuevas vacantes, te notificaremos de inmediato. ¡Muchas gracias por tu interés! 🙏`;
    }
}

// ==============================================================================
// 7. INICIALIZACIÓN DEL CLIENTE WHATSAPP
// ==============================================================================

console.log('\n🚀 ═══════════════════════════════════════════════════');
console.log('   INBESTIGA · Agente IA WhatsApp "Vicky" · Iniciando');
console.log('═══════════════════════════════════════════════════════\n');

/** Cliente de WhatsApp con persistencia de sesión LocalAuth. */
const client = new Client({
    authStrategy: new LocalAuth({
        dataPath: './.wwebjs_auth',
    }),
    puppeteer: {
        headless: true,
        args    : [
```

Descripción: se muestra el código del motor de contingencia procesarMensajeFallbackHeuristico() en bot.js, garantizando la continuidad operativa mediante expresiones regulares en caso de saturación o caída de la API de IA.

---

