/**
 * ==============================================================================
 * simulador_chat.js  –  SIMULADOR DE CHAT CLI · INBESTIGA · FASE BUYER
 * ==============================================================================
 * Permite probar el flujo completo del bot SIN necesitar un teléfono físico.
 * Ejecuta exactamente la misma lógica de Grok + SQL Server que usa bot.js.
 *
 * Uso (un mensaje directo):
 *   node simulador_chat.js "Hola, soy Mario de la UNT, Administración" 987654321
 *
 * Uso interactivo (conversación multi-turno):
 *   node simulador_chat.js --interactivo 987654321
 *
 * El registro impactará al Dashboard de Streamlit en tiempo real.
 * ==============================================================================
 */

'use strict';
require('dotenv').config();

const OpenAI  = require('openai');
const readline = require('readline');

// ── Configuración DB (Autenticación de Windows vs SQL Server) ────────────────
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
            connectionString: `Driver={${driver}};Server=${server};Database=${database};Trusted_Connection=yes;TrustServerCertificate=yes;`
        };
    } catch (err) {
        sql = require('mssql');
        dbConfig = {
            server  : process.env.DB_SERVER   || 'localhost',
            port    : parseInt(process.env.DB_PORT, 10) || 1433,
            database: process.env.DB_NAME     || 'INBESTIGA_TESIS',
            user    : process.env.DB_USER     || 'sa',
            password: process.env.DB_PASSWORD || '',
            options : {
                encrypt               : false,
                trustServerCertificate: true,
                enableArithAbort      : true,
            },
        };
    }
} else {
    sql = require('mssql');
    dbConfig = {
        server  : process.env.DB_SERVER   || 'localhost',
        port    : parseInt(process.env.DB_PORT, 10) || 1433,
        database: process.env.DB_NAME     || 'INBESTIGA_TESIS',
        user    : process.env.DB_USER     || 'sa',
        password: process.env.DB_PASSWORD || '',
        options : {
            encrypt               : false,
            trustServerCertificate: true,
            enableArithAbort      : true,
        },
    };
}

// ── Configuración dinámica del cliente IA (Gemini, Groq, Grok, OpenAI) ────────
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

// ── Separador visual ──────────────────────────────────────────────────────────
const SEP = '─'.repeat(65);

// ==============================================================================
// Funciones de base de datos (idénticas al bot.js)
// ==============================================================================

async function verificarCobertura(pool, { universidad, carrera }) {
    console.log(`\n🔍 [verificar_cobertura] "${universidad}" | "${carrera}"`);
    const uFiltro = `%${universidad.trim()}%`;
    const cFiltro = `%${carrera.trim()}%`;

    const res = await pool.request()
        .input('uFiltro', sql.VarChar(150), uFiltro)
        .input('cFiltro', sql.VarChar(150), cFiltro)
        .query(`
            SELECT TOP 1
                u.universidad_id, u.nombre AS universidad_nombre, u.atendida AS universidad_atendida,
                c.carrera_id,     c.nombre AS carrera_nombre,     c.atendida AS carrera_atendida
            FROM UNIVERSIDAD u
            INNER JOIN CARRERA c ON c.universidad_id = u.universidad_id
            WHERE u.nombre LIKE @uFiltro AND c.nombre LIKE @cFiltro;
        `);

    if (res.recordset.length > 0) {
        const row       = res.recordset[0];
        const cobertura = !!(row.universidad_atendida) && !!(row.carrera_atendida);
        console.log(`   → ${cobertura ? '✅ ACTIVA' : '⚠️  SIN COBERTURA'} (${row.universidad_nombre} – ${row.carrera_nombre})`);
        return {
            encontrado         : true,
            universidad_id     : row.universidad_id,
            universidad_nombre : row.universidad_nombre,
            carrera_id         : row.carrera_id,
            carrera_nombre     : row.carrera_nombre,
            cobertura,
            mensaje: cobertura
                ? `Cobertura activa para ${row.carrera_nombre} en ${row.universidad_nombre}.`
                : 'Sin cobertura activa en este momento.',
        };
    }

    // Búsqueda independiente como fallback
    const [uRes, cRes] = await Promise.all([
        pool.request().input('uFiltro', sql.VarChar(150), uFiltro)
            .query(`SELECT TOP 1 universidad_id, nombre, atendida FROM UNIVERSIDAD WHERE nombre LIKE @uFiltro`),
        pool.request().input('cFiltro', sql.VarChar(150), cFiltro)
            .query(`SELECT TOP 1 carrera_id, nombre, atendida FROM CARRERA WHERE nombre LIKE @cFiltro`),
    ]);
    const uFound = uRes.recordset[0] || null;
    const cFound = cRes.recordset[0] || null;

    if (uFound && cFound) {
        const cobertura = !!(uFound.atendida) && !!(cFound.atendida);
        console.log(`   → Fallback independiente: ${cobertura ? '✅ ACTIVA' : '⚠️  SIN COBERTURA'}`);
        return {
            encontrado         : true,
            universidad_id     : uFound.universidad_id,
            universidad_nombre : uFound.nombre,
            carrera_id         : cFound.carrera_id,
            carrera_nombre     : cFound.nombre,
            cobertura,
            mensaje            : cobertura ? 'Cobertura confirmada.' : 'Sin cobertura.',
        };
    }

    console.log('   → No encontrado en catálogo → SIN COBERTURA.');
    return { encontrado: false, carrera_id: 1, cobertura: false, mensaje: 'No encontrado en catálogo.' };
}

async function registrarBuyerTransaccional(pool, data) {
    console.log(`\n📝 [registrar_buyer] Transacción atómica para: ${data.nombres} (${data.whatsapp})`);
    const transaction = new sql.Transaction(pool);
    try {
        await transaction.begin();

        // 1. CONTACTO
        const cCheck = await new sql.Request(transaction)
            .input('wa', sql.VarChar(30), data.whatsapp)
            .query(`SELECT contacto_id FROM CONTACTO WHERE whatsapp = @wa`);

        let contactoId;
        if (cCheck.recordset.length > 0) {
            contactoId = cCheck.recordset[0].contacto_id;
            await new sql.Request(transaction)
                .input('cid', sql.Int,        contactoId)
                .input('nom', sql.VarChar(100), data.nombres || 'Estudiante')
                .input('ape', sql.VarChar(100), data.apellidos || null)
                .query(`UPDATE CONTACTO SET nombres = @nom, apellidos = @ape WHERE contacto_id = @cid`);
            console.log(`   ♻️  CONTACTO actualizado: ID ${contactoId}`);
        } else {
            const ins = await new sql.Request(transaction)
                .input('nom', sql.VarChar(100), data.nombres   || 'Estudiante WhatsApp')
                .input('ape', sql.VarChar(100), data.apellidos || null)
                .input('wa',  sql.VarChar(30),  data.whatsapp)
                .query(`
                    INSERT INTO CONTACTO (nombres, apellidos, whatsapp, consentimiento_contacto, fecha_registro, estado)
                    VALUES (@nom, @ape, @wa, 1, SYSDATETIME(), 'ACTIVO');
                    SELECT SCOPE_IDENTITY() AS contacto_id;
                `);
            contactoId = ins.recordset[0].contacto_id;
            console.log(`   ✅ CONTACTO creado: ID ${contactoId}`);
        }

        // 2. PERFIL_ACADEMICO
        const carreraId = data.carrera_id || 1;
        const pCheck = await new sql.Request(transaction)
            .input('cid', sql.Int, contactoId)
            .query(`SELECT perfil_academico_id FROM PERFIL_ACADEMICO WHERE contacto_id = @cid`);

        if (pCheck.recordset.length === 0) {
            await new sql.Request(transaction)
                .input('cid',   sql.Int,       contactoId)
                .input('carr',  sql.Int,       carreraId)
                .input('etapa', sql.VarChar(40), data.etapa_academica || 'PREGRADO')
                .input('ciclo', sql.VarChar(20), data.ciclo || 'X')
                .input('sede',  sql.VarChar(80), data.sede  || 'TRUJILLO')
                .query(`
                    INSERT INTO PERFIL_ACADEMICO (contacto_id, carrera_id, etapa_academica, ciclo, sede, tipo_investigacion, avance)
                    VALUES (@cid, @carr, @etapa, @ciclo, @sede, 'TESIS', '0-25%');
                `);
            console.log(`   ✅ PERFIL_ACADEMICO creado (carrera_id=${carreraId})`);
        } else {
            console.log('   ♻️  PERFIL_ACADEMICO ya existe.');
        }

        // 3. BUYER
        const estadoBuyer = data.tiene_cobertura ? 'ACTIVO' : 'SIN_COBERTURA';
        const bCheck = await new sql.Request(transaction)
            .input('cid', sql.Int, contactoId)
            .query(`SELECT buyer_id FROM BUYER WHERE contacto_id = @cid`);

        let buyerId;
        if (bCheck.recordset.length > 0) {
            buyerId = bCheck.recordset[0].buyer_id;
            await new sql.Request(transaction)
                .input('bid', sql.Int,        buyerId)
                .input('est', sql.VarChar(30), estadoBuyer)
                .query(`UPDATE BUYER SET estado = @est WHERE buyer_id = @bid`);
            console.log(`   ♻️  BUYER actualizado: ID ${buyerId} → ${estadoBuyer}`);
        } else {
            const ibRes = await new sql.Request(transaction)
                .input('cid', sql.Int,         contactoId)
                .input('nec', sql.VarChar(150), data.necesidad_inicial || 'Asesoría Integral de Tesis')
                .input('est', sql.VarChar(30),  estadoBuyer)
                .query(`
                    INSERT INTO BUYER (contacto_id, canal_captacion_id, campania_id, servicio_interes_id, necesidad_inicial, fecha_buyer, estado)
                    VALUES (@cid, 1, NULL, 2, @nec, SYSDATETIME(), @est);
                    SELECT SCOPE_IDENTITY() AS buyer_id;
                `);
            buyerId = ibRes.recordset[0].buyer_id;
            console.log(`   ✅ BUYER creado: ID ${buyerId} → ${estadoBuyer}`);
        }

        await transaction.commit();
        console.log(`   🎉 COMMIT OK · Buyer ${buyerId} [${estadoBuyer}]`);
        return { exito: true, buyer_id: buyerId, contacto_id: contactoId, estado: estadoBuyer };

    } catch (err) {
        try { await transaction.rollback(); } catch (_) {}
        console.error('   ❌ ROLLBACK:', err.message);
        return { exito: false, error: err.message };
    }
}

// ==============================================================================
// Tools (idénticas a bot.js)
// ==============================================================================

const GROK_TOOLS = [
    {
        type: 'function',
        function: {
            name: 'verificar_cobertura',
            description: 'Verifica si INBESTIGA atiende la universidad y carrera indicadas (atendida = 1).',
            parameters: {
                type: 'object',
                properties: {
                    universidad: { type: 'string' },
                    carrera    : { type: 'string' },
                },
                required: ['universidad', 'carrera'],
            },
        },
    },
    {
        type: 'function',
        function: {
            name: 'registrar_buyer',
            description: 'Registra transaccionalmente al estudiante como Buyer (CONTACTO → PERFIL_ACADEMICO → BUYER).',
            parameters: {
                type: 'object',
                properties: {
                    nombres        : { type: 'string' },
                    apellidos      : { type: 'string' },
                    whatsapp       : { type: 'string' },
                    carrera_id     : { type: 'integer' },
                    etapa_academica: { type: 'string' },
                    ciclo          : { type: 'string' },
                    sede           : { type: 'string' },
                    necesidad_inicial: { type: 'string' },
                    tiene_cobertura: { type: 'boolean' },
                },
                required: ['nombres', 'whatsapp', 'carrera_id', 'tiene_cobertura'],
            },
        },
    },
];

const SYSTEM_PROMPT_SIMULADOR = `
Eres "Vicky", la Asistente Virtual de Admisión de INBESTIGA, institución especializada en asesoría de tesis universitarias en Perú.
Tu personalidad es 100% humana, empática, profesional y cercana. NUNCA menciones términos técnicos internos como "KPI", "KPI B06", "Data Mart", "Fase Buyer" ni "Base de datos".

Regla de mensajes fuera de tema (off-topic):
Si el usuario pregunta o comenta algo ajeno a asesoría de tesis o investigación universitaria (ej. bromas, venta de otros productos, colegio, etc.), NO llames a ninguna herramienta y responde amablemente:
"¡Hola! En INBESTIGA nos dedicamos exclusivamente a la asesoría, desarrollo y acompañamiento de tesis y proyectos de grado universitario. 🎓 Si estás realizando tu tesis, cuéntame: ¿en qué universidad estudias y qué carrera cursas? ¡Con gusto te ayudo! 😊"

Flujo obligatorio:
1. Identifica el nombre, universidad y carrera del estudiante.
2. Ejecuta "verificar_cobertura" inmediatamente.
3. Ejecuta "registrar_buyer" con los datos recopilados.
4. Respuesta final obligatoria (según cobertura):
   - Con cobertura (cobertura = true):
     "¡Hola [Nombre]! 🎉 Qué gusto saludarte, soy Vicky de INBESTIGA. Te confirmo que SÍ contamos con cobertura activa para tu carrera de [Carrera] en [Universidad]. Tus datos han quedado registrados exitosamente. En breve, un especialista te contactará para coordinar tu diagnóstico gratuito. 😊"
   - Sin cobertura (cobertura = false):
     "Hola [Nombre], soy Vicky de INBESTIGA. Lamentamos informarte que, por el momento, no contamos con cobertura activa para tu carrera en esa universidad. No obstante, hemos registrado tus datos en nuestra lista de espera preferencial. Apenas aperturemos nuevas vacantes, te notificaremos de inmediato. ¡Muchas gracias por tu interés! 🙏"
`.trim();

// ==============================================================================
// Motor de procesamiento (multi-turno, reutilizable)
// ==============================================================================

async function procesarTurno(pool, messages, userMessage, userPhone) {
    messages.push({ role: 'user', content: userMessage });

    try {
        let response = await aiClient.chat.completions.create({
            model      : AI_MODEL,
            messages,
            tools      : GROK_TOOLS,
            tool_choice: 'auto',
            temperature: 0.3,
        });

        let responseMsg = response.choices[0].message;
        let iteraciones = 0;

        while (responseMsg.tool_calls && responseMsg.tool_calls.length > 0) {
            iteraciones++;
            if (iteraciones > 5) break;
            messages.push(responseMsg);

            for (const tool of responseMsg.tool_calls) {
                const name = tool.function.name;
                const args = JSON.parse(tool.function.arguments || '{}');
                let   result;

                if (name === 'verificar_cobertura') {
                    result = await verificarCobertura(pool, args);
                } else if (name === 'registrar_buyer') {
                    args.whatsapp  = args.whatsapp || userPhone;
                    args.carrera_id = args.carrera_id || 1;
                    result = await registrarBuyerTransaccional(pool, args);
                } else {
                    result = { error: `Función desconocida: ${name}` };
                }

                messages.push({
                    role        : 'tool',
                    tool_call_id: tool.id,
                    name,
                    content     : JSON.stringify(result),
                });
            }

            response    = await aiClient.chat.completions.create({
                model  : AI_MODEL,
                messages,
                tools  : GROK_TOOLS,
                temperature: 0.3,
            });
            responseMsg = response.choices[0].message;
        }

        const reply = responseMsg.content || '¡Gracias por comunicarte con INBESTIGA!';
        messages.push({ role: 'assistant', content: reply });
        return reply;

    } catch (grokError) {
        console.warn(`⚠️ [Grok API] Aviso: ${grokError.message}`);
        console.log('⚡ [Modo Contingencia] Activando motor heurístico de Vicky para asegurar la transacción...');
        const fallbackReply = await procesarTurnoFallbackHeuristico(pool, userMessage, userPhone);
        messages.push({ role: 'assistant', content: fallbackReply });
        return fallbackReply;
    }
}

async function procesarTurnoFallbackHeuristico(pool, userMessage, userPhone) {
    // 1. Extraer Universidad
    let uni = 'UNT';
    if (/upao|antenor/i.test(userMessage)) uni = 'Universidad Privada Antenor Orrego';
    else if (/ucv|vallejo/i.test(userMessage)) uni = 'Universidad Cesar Vallejo';
    else if (/upn|norte/i.test(userMessage)) uni = 'Universidad Privada del Norte';
    else if (/uct|catolica/i.test(userMessage)) uni = 'Universidad Catolica de Trujillo';
    else if (/unt|nacional.*trujillo/i.test(userMessage)) uni = 'Universidad Nacional de Trujillo';
    else if (/lima|san\s*marcos|unmsm|pucp|uni\b/i.test(userMessage)) uni = 'Universidad de Lima';

    // 2. Extraer Carrera
    let car = 'Ingenieria de Sistemas';
    if (/administra/i.test(userMessage)) car = 'Administracion';
    else if (/sistemas|software|comput/i.test(userMessage)) car = 'Ingenieria de Sistemas';
    else if (/derecho|aboga/i.test(userMessage)) car = 'Derecho';
    else if (/diseño|grafic/i.test(userMessage)) car = 'Diseño Grafico';
    else if (/psicolog/i.test(userMessage)) car = 'Psicologia';
    else if (/contab/i.test(userMessage)) car = 'Contabilidad';

    // 3. Extraer Nombre
    let nom = 'Estudiante';
    const mNom = userMessage.match(/(?:me llamo|soy|mi nombre es)\s+([A-ZÁÉÍÓÚa-záéíóúñ]+(?:\s+[A-ZÁÉÍÓÚa-záéíóúñ]+)?)/i);
    if (mNom && mNom[1]) {
        nom = mNom[1].trim();
    }

    // 4. Verificar cobertura en SQL Server
    const cov = await verificarCobertura(pool, { universidad: uni, carrera: car });

    // 5. Registrar Buyer transaccional
    await registrarBuyerTransaccional(pool, {
        nombres: nom,
        whatsapp: userPhone,
        carrera_id: cov.carrera_id || 1,
        tiene_cobertura: cov.cobertura,
        necesidad_inicial: 'Asesoría Integral de Tesis'
    });

    // 6. Generar respuesta
    if (cov.cobertura) {
        return `¡Hola ${nom}! 🎉 Qué gusto saludarte. Te confirmo que en INBESTIGA SÍ contamos con cobertura activa para ${cov.carrera_nombre || car} en ${cov.universidad_nombre || uni}. Tus datos han quedado registrados exitosamente como BUYER ACTIVO. En breve te contactaremos para coordinar tu diagnóstico gratuito. 😊`;
    } else {
        return `Hola ${nom}. Lamentamos informarte que por el momento no contamos con cobertura activa para tu carrera/universidad consultada. No obstante, hemos registrado tus datos en nuestra lista de espera preferencial (Demanda Fuera de Cobertura - KPI B06). Apenas aperturemos nuevas vacantes te notificaremos. ¡Gracias por tu interés en INBESTIGA! 🙏`;
    }
}

// ==============================================================================
// Modos de ejecución
// ==============================================================================

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
    const args   = process.argv.slice(2);
    const modo   = args[0] === '--interactivo' ? 'interactivo' : 'unico';
    const telIdx = modo === 'interactivo' ? 1 : 1;
    const telefono = args[telIdx] || `9${Math.floor(Math.random() * 90000000 + 10000000)}`;

    let pool;
    try {
        pool = await sql.connect(dbConfig);
        console.log('✅ Conexión establecida con SQL Server (INBESTIGA_TESIS).');
    } catch (err) {
        console.error('❌ No se pudo conectar a SQL Server:', err.message);
        console.error('   → Verifica DB_SERVER, DB_USER y DB_PASSWORD en el archivo .env');
        process.exit(1);
    }

    try {
        if (modo === 'interactivo') {
            await modoInteractivo(pool, telefono);
        } else {
            const mensaje = args[0] || 'Hola, soy María López, estudio Administración en la UPAO y necesito ayuda con mi tesis.';
            await modoMensajeUnico(pool, mensaje, telefono);
            await pool.close();
        }
    } catch (err) {
        console.error('❌ Error en la simulación:', err.message);
        await pool.close();
        process.exit(1);
    }
})();
