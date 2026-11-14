/**
 * ==============================================================================
 * bot.js  –  AGENTE IA WHATSAPP "VICKY" · INBESTIGA · FASE BUYER
 * ==============================================================================
 * Responsable : D'Alessandro (Arquitecto del Bot y la IA – Backend)
 * Stack       : Node.js v18+ | whatsapp-web.js | xAI Grok API | mssql
 *
 * Flujo conversacional garantizado:
 *   1. Saludo → Presenta a "Vicky" la asistente virtual de INBESTIGA.
 *   2. Pide Universidad y Carrera.
 *   3. Llama a [verificar_cobertura] → consulta UNIVERSIDAD ⨝ CARRERA.
 *   4a. Con cobertura  → Pide Nombre + registra en BD (ACTIVO).
 *   4b. Sin cobertura  → Deriva a lista de espera (SIN_COBERTURA).
 *   5. Registra CONTACTO → PERFIL_ACADEMICO → BUYER (transacción atómica).
 *   6. Auditoría completa en CONVERSACION y MENSAJE.
 *
 * Notas técnicas:
 *   - Conexión SQL Server mediante pool persistente (mssql).
 *   - Function Calling con xAI Grok (compatible con OpenAI SDK v4).
 *   - Sesión WhatsApp persistida con LocalAuth (.wwebjs_auth/).
 *   - Historial conversacional en memoria, limitado a 20 turnos.
 *   - Manejo robusto de errores con ROLLBACK automático.
 * ==============================================================================
 */

'use strict';
require('dotenv').config();

const { Client, LocalAuth } = require('whatsapp-web.js');
const qrcode               = require('qrcode-terminal');
const OpenAI               = require('openai');

// ==============================================================================
// 1. CONFIGURACIÓN DE CONEXIONES (Autenticación de Windows vs SQL Server)
// ==============================================================================

const useWindowsAuth = !process.env.DB_USER;
let sql;
let dbConfig;

if (useWindowsAuth) {
    try {
        sql = require('mssql/msnodesqlv8');
        const driver = process.env.DB_DRIVER || 'ODBC Driver 17 for SQL Server';
        const server = (process.env.DB_SERVER || 'localhost').trim();
        const database = (process.env.DB_NAME || 'INBESTIGA_TESIS').trim();
        dbConfig = {
            connectionString: `Driver={${driver}};Server=${server};Database=${database};Trusted_Connection=yes;TrustServerCertificate=yes;`,
            pool: {
                max: 10,
                min: 0,
                idleTimeoutMillis: 30000
            }
        };
    } catch (err) {
        sql = require('mssql');
        dbConfig = {
            server  : process.env.DB_SERVER || 'localhost',
            port    : parseInt(process.env.DB_PORT, 10) || 1433,
            database: process.env.DB_NAME   || 'INBESTIGA_TESIS',
            user    : process.env.DB_USER   || 'sa',
            password: process.env.DB_PASSWORD || '',
            options : {
                encrypt                : false,
                trustServerCertificate : true,
                enableArithAbort       : true,
                connectTimeout         : 15000,
                requestTimeout         : 30000,
            },
            pool: {
                max              : 10,
                min              : 0,
                idleTimeoutMillis: 30000,
                acquireTimeoutMillis: 30000,
            },
        };
    }
} else {
    sql = require('mssql');
    dbConfig = {
        server  : process.env.DB_SERVER || 'localhost',
        port    : parseInt(process.env.DB_PORT, 10) || 1433,
        database: process.env.DB_NAME   || 'INBESTIGA_TESIS',
        user    : process.env.DB_USER   || 'sa',
        password: process.env.DB_PASSWORD || '',
        options : {
            encrypt                : false,
            trustServerCertificate : true,
            enableArithAbort       : true,
            connectTimeout         : 15000,
            requestTimeout         : 30000,
        },
        pool: {
            max              : 10,
            min              : 0,
            idleTimeoutMillis: 30000,
            acquireTimeoutMillis: 30000,
        },
    };
}

/** Instancia del pool de conexión (singleton). */
let dbPool = null;

/**
 * Devuelve el pool de conexión activo, creándolo si no existe.
 * @returns {Promise<sql.ConnectionPool>}
 */
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
 * @param {string} param0.universidad - Nombre o sigla de la universidad.
 * @param {string} param0.carrera     - Nombre de la carrera.
 * @returns {Promise<object>} Resultado con {encontrado, universidad_id, carrera_id, cobertura, mensaje}.
 */
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
 *   2. PERFIL_ACADEMICO (crea si no existe)
 *   3. BUYER           (crea o actualiza estado)
 *
 * @param {object} data - Datos del estudiante recopilados por Vicky.
 * @returns {Promise<object>} Resultado con {exito, contacto_id, buyer_id, estado}.
 */
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

        // ── 2. PERFIL_ACADEMICO ───────────────────────────────────────────────
        const carreraId = data.carrera_id || 1;

        const checkPerfil = await new sql.Request(transaction)
            .input('contacto_id', sql.Int, contactoId)
            .query(`SELECT perfil_academico_id FROM PERFIL_ACADEMICO WHERE contacto_id = @contacto_id`);

        if (checkPerfil.recordset.length === 0) {
            await new sql.Request(transaction)
                .input('contacto_id',       sql.Int,       contactoId)
                .input('carrera_id',        sql.Int,       carreraId)
                .input('etapa_academica',   sql.VarChar(40), data.etapa_academica   || 'PREGRADO')
                .input('ciclo',             sql.VarChar(20), data.ciclo             || 'X')
                .input('sede',              sql.VarChar(80), data.sede              || 'TRUJILLO')
                .input('tipo_investigacion',sql.VarChar(60), 'TESIS')
                .input('avance',            sql.VarChar(30), '0-25%')
                .query(`
                    INSERT INTO PERFIL_ACADEMICO (
                        contacto_id, carrera_id, etapa_academica,
                        ciclo, sede, tipo_investigacion, avance
                    ) VALUES (
                        @contacto_id, @carrera_id, @etapa_academica,
                        @ciclo, @sede, @tipo_investigacion, @avance
                    )
                `);
            console.log(`   ✅ PERFIL_ACADEMICO creado para contacto_id=${contactoId}, carrera_id=${carreraId}`);
        } else {
            console.log(`   ♻️  PERFIL_ACADEMICO ya existe para contacto_id=${contactoId}`);
        }

        // ── 3. BUYER ──────────────────────────────────────────────────────────
        const estadoBuyer = data.tiene_cobertura ? 'ACTIVO' : 'SIN_COBERTURA';

        const checkBuyer = await new sql.Request(transaction)
            .input('contacto_id', sql.Int, contactoId)
            .query(`SELECT buyer_id, estado FROM BUYER WHERE contacto_id = @contacto_id`);

        let buyerId;

        if (checkBuyer.recordset.length > 0) {
            buyerId = checkBuyer.recordset[0].buyer_id;
            await new sql.Request(transaction)
                .input('buyer_id',  sql.Int,        buyerId)
                .input('estado',    sql.VarChar(30), estadoBuyer)
                .input('necesidad', sql.VarChar(150), (data.necesidad_inicial || 'Asesoría de Tesis').substring(0, 150))
                .query(`
                    UPDATE BUYER
                    SET  estado            = @estado,
                         necesidad_inicial = @necesidad,
                         fecha_buyer       = SYSDATETIME()
                    WHERE buyer_id = @buyer_id
                `);
            console.log(`   ♻️  BUYER actualizado: ID ${buyerId} → ${estadoBuyer}`);
        } else {
            const insBuyer = await new sql.Request(transaction)
                .input('contacto_id',       sql.Int,        contactoId)
                .input('canal_captacion_id', sql.Int,       1)   // WhatsApp orgánico
                .input('servicio_interes_id',sql.Int,       2)   // Proyecto de Tesis
                .input('necesidad_inicial',  sql.VarChar(150), (data.necesidad_inicial || 'Asesoría Integral de Tesis').substring(0, 150))
                .input('estado',             sql.VarChar(30),  estadoBuyer)
                .query(`
                    INSERT INTO BUYER (
                        contacto_id, canal_captacion_id, campania_id,
                        servicio_interes_id, necesidad_inicial,
                        fecha_buyer, estado
                    ) VALUES (
                        @contacto_id, @canal_captacion_id, NULL,
                        @servicio_interes_id, @necesidad_inicial,
                        SYSDATETIME(), @estado
                    );
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
 */
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

/**
 * Inserta un registro en la tabla MENSAJE para trazabilidad.
 *
 * @param {number|null} conversacionId
 * @param {'CLIENTE'|'BOT'} emisor
 * @param {string} contenido
 */
async function registrarMensajeEnBD(conversacionId, emisor, contenido) {
    if (!conversacionId) return;
    try {
        const pool = await getDbPool();
        await pool.request()
            .input('convId',   sql.Int,       conversacionId)
            .input('emisor',   sql.VarChar(20), emisor)
            .input('contenido',sql.VarChar(1000), (contenido || '').substring(0, 1000))
            .query(`
                INSERT INTO MENSAJE (conversacion_id, fecha_mensaje, emisor, tipo, contenido)
                VALUES (@convId, SYSDATETIME(), @emisor, 'TEXTO', @contenido);
            `);
    } catch (err) {
        console.error('⚠️  [registrarMensaje] Error:', err.message);
    }
}

// ==============================================================================
// 4. DEFINICIÓN DE TOOLS PARA GROK (FUNCTION CALLING)
// ==============================================================================

const GROK_TOOLS = [
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
                    whatsapp: {
                        type       : 'string',
                        description: 'Número de WhatsApp del estudiante (ej. 987654321). Se asigna automáticamente si no lo proporciona.',
                    },
                    correo: {
                        type       : 'string',
                        description: 'Correo electrónico (opcional).',
                    },
                    carrera_id: {
                        type       : 'integer',
                        description: 'ID de la carrera retornado por verificar_cobertura.',
                    },
                    etapa_academica: {
                        type       : 'string',
                        enum       : ['PREGRADO', 'X CICLO', 'EGRESADO', 'BACHILLER', 'TITULANDO'],
                        description: 'Etapa académica actual del estudiante.',
                    },
                    ciclo: {
                        type       : 'string',
                        description: 'Ciclo cursado (ej. X, IX, EGRESADO).',
                    },
                    sede: {
                        type       : 'string',
                        description: 'Ciudad o sede (ej. TRUJILLO, LIMA).',
                    },
                    necesidad_inicial: {
                        type       : 'string',
                        description: 'Resumen de la necesidad del estudiante (ej. Proyecto de tesis, Tema, Metodología).',
                    },
                    tiene_cobertura: {
                        type       : 'boolean',
                        description: 'true si la carrera y universidad están atendidas; false si no hay cobertura.',
                    },
                },
                required: ['nombres', 'whatsapp', 'carrera_id', 'tiene_cobertura'],
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
 * Procesa un mensaje de usuario con Grok y ejecuta las funciones que solicite.
 * Mantiene el historial de conversación por número de WhatsApp.
 *
 * @param {string} userPhone   - Número limpio del remitente.
 * @param {string} userMessage - Texto del mensaje entrante.
 * @returns {Promise<string>}  - Texto de respuesta para enviar al usuario.
 */
async function procesarMensajeConGrok(userPhone, userMessage) {
    // Inicializar historial con system prompt si es un chat nuevo
    if (!conversationHistory.has(userPhone)) {
        conversationHistory.set(userPhone, [
            { role: 'system', content: SYSTEM_PROMPT },
        ]);
    }

    const messages = conversationHistory.get(userPhone);
    messages.push({ role: 'user', content: userMessage });

    try {
        // ── Primera llamada a Grok ────────────────────────────────────────────
        let response = await aiClient.chat.completions.create({
            model      : AI_MODEL,
            messages,
            tools      : GROK_TOOLS,
            tool_choice: 'auto',
            temperature: 0.3,
            max_tokens : 800,
        });

        let responseMessage = response.choices[0].message;

        // ── Bucle de Function Calling ─────────────────────────────────────────
        let iteraciones = 0;
        while (responseMessage.tool_calls && responseMessage.tool_calls.length > 0) {
            iteraciones++;
            if (iteraciones > 5) {
                console.warn('⚠️  Límite de iteraciones de Function Calling alcanzado.');
                break;
            }

            messages.push(responseMessage); // Agregar petición de tool al historial

            for (const toolCall of responseMessage.tool_calls) {
                const fnName = toolCall.function.name;
                const fnArgs = JSON.parse(toolCall.function.arguments || '{}');
                let   result = null;

                console.log(`\n⚙️  [Function Calling] Ejecutando: ${fnName}`);
                console.log(`   Args:`, JSON.stringify(fnArgs, null, 2));

                if (fnName === 'verificar_cobertura') {
                    result = await verificarCobertura(fnArgs);

                } else if (fnName === 'registrar_buyer') {
                    // Garantizar que el whatsapp del buyer coincida con el remitente real
                    fnArgs.whatsapp = fnArgs.whatsapp || userPhone;
                    // Fallback seguro si Grok no incluyó carrera_id
                    if (!fnArgs.carrera_id) fnArgs.carrera_id = 1;
                    result = await registrarBuyerTransaccional(fnArgs);

                } else {
                    result = { error: `Función desconocida: ${fnName}` };
                }

                messages.push({
                    role       : 'tool',
                    tool_call_id: toolCall.id,
                    name       : fnName,
                    content    : JSON.stringify(result),
                });
            }

            // ── Segunda llamada a Grok con resultados de las funciones ────────
            response = await aiClient.chat.completions.create({
                model      : AI_MODEL,
                messages,
                tools      : GROK_TOOLS,
                temperature: 0.3,
                max_tokens : 800,
            });
            responseMessage = response.choices[0].message;
        }

        const replyText = responseMessage.content
            || '¡Gracias por comunicarte con INBESTIGA! Pronto te contactaremos. 😊';

        messages.push({ role: 'assistant', content: replyText });

        // Limitar historial a system + últimos 18 turnos para no saturar memoria/tokens
        if (messages.length > 20) {
            conversationHistory.set(userPhone, [
                messages[0],
                ...messages.slice(-18),
            ]);
        }

        return replyText;

    } catch (err) {
        console.warn(`⚠️  [Grok API] Aviso: ${err.message}`);
        console.log('⚡ [Modo Contingencia] Activando motor heurístico de Vicky para asegurar la transacción...');
        return await procesarMensajeFallbackHeuristico(userPhone, userMessage);
    }
}

/**
 * Motor heurístico de contingencia: procesa el mensaje de manera determinista
 * si la API de Grok está caída o rechaza la clave, asegurando que el estudiante
 * se registre en SQL Server y no se pierda la transacción.
 */
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
    webVersionCache: {
        type: 'remote',
        remotePath: 'https://raw.githubusercontent.com/wppconnect-team/wa-version/main/html/2.2412.54.html',
    },
    puppeteer: {
        headless: true,
        args    : [
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-dev-shm-usage',
            '--disable-accelerated-2d-canvas',
            '--no-first-run',
            '--no-zygote',
            '--disable-gpu',
        ],
    },
});

// ── Eventos del cliente WhatsApp ─────────────────────────────────────────────

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

client.on('message', async (msg) => {
    // Filtrar: grupos, estados, mensajes propios del bot
    if (msg.from.includes('@g.us') || msg.isStatus || msg.fromMe) return;

    const rawPhone  = msg.from.replace('@c.us', '');
    // Eliminar código de país Perú (+51) si está presente para alinear con la BD
    const userPhone = rawPhone.startsWith('51') ? rawPhone.substring(2) : rawPhone;
    const userText  = (msg.body || '').trim();

    if (!userText) return;

    console.log(`\n${'─'.repeat(60)}`);
    console.log(`📩 Entrante → ${userPhone}: "${userText}"`);

    try {
        // 1. Garantizar CONVERSACION activa y registrar mensaje del cliente
        const { conversacionId } = await asegurarConversacion(userPhone);
        await registrarMensajeEnBD(conversacionId, 'CLIENTE', userText);

        // 2. Procesar con Grok + Function Calling
        const botReply = await procesarMensajeConGrok(userPhone, userText);

        // 3. Enviar respuesta por WhatsApp
        await client.sendMessage(msg.from, botReply);
        console.log(`📤 Enviado → ${userPhone}: "${botReply.substring(0, 100)}..."`);

        // 4. Registrar respuesta del bot en auditoría
        await registrarMensajeEnBD(conversacionId, 'BOT', botReply);

    } catch (err) {
        console.error('❌ [message handler] Error inesperado:', err.message);
        try {
            await client.sendMessage(
                msg.from,
                'Disculpa, tuve un inconveniente. Por favor escríbenos en un momento. 🙏'
            );
        } catch (_) { /* no podemos hacer nada más */ }
    }
});

// ── Arranque: conectar BD primero, luego WhatsApp ────────────────────────────

(async () => {
    try {
        await getDbPool();
        console.log('⏳ Iniciando cliente de WhatsApp...\n');
        client.initialize();
    } catch (err) {
        console.error('\n❌ ERROR CRÍTICO al iniciar el bot:', err.message);
        console.error('   Verifica que SQL Server esté corriendo y que las credenciales en .env sean correctas.');
        process.exit(1);
    }
})();
