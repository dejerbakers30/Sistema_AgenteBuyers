/**
 * ==============================================================================
 * bot.js - AGENTE IA DE WHATSAPP PARA LA FASE BUYER (INBESTIGA)
 * ==============================================================================
 * Responsabilidades:
 * 1. Conexión a WhatsApp real mediante whatsapp-web.js (persistencia LocalAuth).
 * 2. Orquestación conversacional con Grok (xAI API) mediante Function Calling.
 * 3. Ejecución de herramientas:
 *    - verificar_cobertura: consulta en UNIVERSIDAD y CARRERA (flag atendida).
 *    - registrar_buyer: transacción atómica (CONTACTO -> PERFIL_ACADEMICO -> BUYER).
 * 4. Registro y auditoría en CONVERSACION y MENSAJE.
 * ==============================================================================
 */

require('dotenv').config();
const { Client, LocalAuth } = require('whatsapp-web.js');
const qrcode = require('qrcode-terminal');
const sql = require('mssql');
const OpenAI = require('openai');

// ------------------------------------------------------------------------------
// 1. CONFIGURACIÓN DE CONEXIONES
// ------------------------------------------------------------------------------

// Configuración de SQL Server
const dbConfig = {
    server: process.env.DB_SERVER || 'localhost',
    port: parseInt(process.env.DB_PORT, 10) || 1433,
    database: process.env.DB_NAME || 'INBESTIGA_TESIS',
    user: process.env.DB_USER || 'sa',
    password: process.env.DB_PASSWORD || '',
    options: {
        encrypt: false,
        trustServerCertificate: (process.env.DB_TRUST_SERVER_CERTIFICATE || 'true') === 'true',
        enableArithAbort: true
    },
    pool: {
        max: 10,
        min: 0,
        idleTimeoutMillis: 30000
    }
};

let dbPool = null;

async function getDbPool() {
    if (!dbPool) {
        try {
            dbPool = await sql.connect(dbConfig);
            console.log('✅ [SQL Server] Conexión establecida a INBESTIGA_TESIS');
        } catch (err) {
            console.error('❌ [SQL Server] Error al conectar:', err.message);
            throw err;
        }
    }
    return dbPool;
}

// Configuración de Cliente xAI (Grok API compatible con OpenAI)
const xaiClient = new OpenAI({
    apiKey: process.env.XAI_API_KEY || 'dummy-key',
    baseURL: 'https://api.x.ai/v1'
});

const GROK_MODEL = process.env.XAI_MODEL || 'grok-2-latest';

// Historial en memoria por número de WhatsApp para mantener el contexto
const conversationHistory = new Map();

// ------------------------------------------------------------------------------
// 2. HERRAMIENTAS DE BASE DE DATOS (FUNCTION CALLING)
// ------------------------------------------------------------------------------

/**
 * Consulta la cobertura académica para la universidad y carrera indicadas.
 */
async function verificarCobertura({ universidad, carrera }) {
    console.log(`🔍 [Tool: verificar_cobertura] Verificando: "${universidad}" - "${carrera}"`);
    try {
        const pool = await getDbPool();
        
        // Búsqueda flexible con comodines LIKE para tolerar variaciones
        const query = `
            SELECT TOP 1
                u.universidad_id,
                u.nombre AS universidad_nombre,
                u.atendida AS universidad_atendida,
                c.carrera_id,
                c.nombre AS carrera_nombre,
                c.atendida AS carrera_atendida
            FROM UNIVERSIDAD u
            INNER JOIN CARRERA c ON c.universidad_id = u.universidad_id
            WHERE u.nombre LIKE @uFiltro
              AND c.nombre LIKE @cFiltro;
        `;

        const request = pool.request();
        request.input('uFiltro', sql.VarChar, `%${universidad.trim()}%`);
        request.input('cFiltro', sql.VarChar, `%${carrera.trim()}%`);

        const result = await request.query(query);

        if (result.recordset.length > 0) {
            const row = result.recordset[0];
            const cobertura = (row.universidad_atendida === true || row.universidad_atendida === 1) &&
                              (row.carrera_atendida === true || row.carrera_atendida === 1);
            return {
                encontrado: true,
                universidad_id: row.universidad_id,
                universidad_nombre: row.universidad_nombre,
                carrera_id: row.carrera_id,
                carrera_nombre: row.carrera_nombre,
                cobertura: cobertura,
                mensaje: cobertura 
                    ? `Tenemos cobertura completa para ${row.carrera_nombre} en ${row.universidad_nombre}.`
                    : `No atendemos actualmente la carrera o universidad consultada.`
            };
        }

        // Búsqueda parcial si no coincide en el JOIN directo
        const uReq = pool.request();
        uReq.input('uFiltro', sql.VarChar, `%${universidad.trim()}%`);
        const uRes = await uReq.query(`SELECT TOP 1 universidad_id, nombre, atendida FROM UNIVERSIDAD WHERE nombre LIKE @uFiltro`);

        const cReq = pool.request();
        cReq.input('cFiltro', sql.VarChar, `%${carrera.trim()}%`);
        const cRes = await cReq.query(`SELECT TOP 1 carrera_id, universidad_id, nombre, atendida FROM CARRERA WHERE nombre LIKE @cFiltro`);

        const uFound = uRes.recordset[0] || null;
        const cFound = cRes.recordset[0] || null;

        if (uFound && cFound) {
            const cobertura = (uFound.atendida && cFound.atendida);
            return {
                encontrado: true,
                universidad_id: uFound.universidad_id,
                universidad_nombre: uFound.nombre,
                carrera_id: cFound.carrera_id,
                carrera_nombre: cFound.nombre,
                cobertura: Boolean(cobertura),
                mensaje: cobertura 
                    ? `Cobertura confirmada para ${cFound.nombre} en ${uFound.nombre}.`
                    : `Universidad o carrera sin cobertura activa en este momento.`
            };
        }

        // Si no existe registro en la base de datos
        return {
            encontrado: false,
            universidad_id: uFound ? uFound.universidad_id : null,
            carrera_id: cFound ? cFound.carrera_id : 1, // Fallback controlado
            cobertura: false,
            mensaje: `La universidad o carrera indicada no se encuentra en el catálogo oficial de INBESTIGA.`
        };

    } catch (err) {
        console.error('❌ Error en verificarCobertura:', err.message);
        return { encontrado: false, cobertura: false, error: err.message };
    }
}

/**
 * Realiza la inserción transaccional atómica:
 * CONTACTO -> PERFIL_ACADEMICO -> BUYER
 */
async function registrarBuyerTransaccional(data) {
    console.log(`📝 [Tool: registrar_buyer] Iniciando registro transaccional para: ${data.nombres} (${data.whatsapp})`);
    const pool = await getDbPool();
    const transaction = new sql.Transaction(pool);

    try {
        await transaction.begin();

        // 1. GESTIÓN DE CONTACTO
        const contactReq = new sql.Request(transaction);
        contactReq.input('whatsapp', sql.VarChar(30), data.whatsapp);
        const contactCheck = await contactReq.query(`
            SELECT contacto_id FROM CONTACTO WHERE whatsapp = @whatsapp
        `);

        let contactoId = null;

        if (contactCheck.recordset.length > 0) {
            contactoId = contactCheck.recordset[0].contacto_id;
            const updateReq = new sql.Request(transaction);
            updateReq.input('contacto_id', sql.Int, contactoId);
            updateReq.input('nombres', sql.VarChar(100), data.nombres);
            updateReq.input('apellidos', sql.VarChar(100), data.apellidos || 'Por Asignar');
            updateReq.input('correo', sql.VarChar(150), data.correo || null);
            await updateReq.query(`
                UPDATE CONTACTO 
                SET nombres = @nombres, 
                    apellidos = @apellidos, 
                    correo = ISNULL(@correo, correo)
                WHERE contacto_id = @contacto_id
            `);
        } else {
            const insertReq = new sql.Request(transaction);
            insertReq.input('nombres', sql.VarChar(100), data.nombres);
            insertReq.input('apellidos', sql.VarChar(100), data.apellidos || 'Por Asignar');
            insertReq.input('whatsapp', sql.VarChar(30), data.whatsapp);
            insertReq.input('correo', sql.VarChar(150), data.correo || null);
            const insertRes = await insertReq.query(`
                INSERT INTO CONTACTO (
                    nombres, apellidos, whatsapp, correo, 
                    consentimiento_contacto, fecha_consentimiento, no_contactar, 
                    fecha_registro, estado
                )
                VALUES (
                    @nombres, @apellidos, @whatsapp, @correo, 
                    1, SYSDATETIME(), 0, 
                    SYSDATETIME(), 'ACTIVO'
                );
                SELECT SCOPE_IDENTITY() AS contacto_id;
            `);
            contactoId = insertRes.recordset[0].contacto_id;
        }

        // 2. GESTIÓN DE PERFIL_ACADEMICO
        const perfilReq = new sql.Request(transaction);
        perfilReq.input('contacto_id', sql.Int, contactoId);
        const perfilCheck = await perfilReq.query(`
            SELECT perfil_academico_id FROM PERFIL_ACADEMICO WHERE contacto_id = @contacto_id
        `);

        let carreraId = data.carrera_id;
        if (!carreraId) {
            // Asigna la primera carrera atendida por defecto si no se especificó ID válido
            carreraId = 1;
        }

        if (perfilCheck.recordset.length === 0) {
            const insertPerfil = new sql.Request(transaction);
            insertPerfil.input('contacto_id', sql.Int, contactoId);
            insertPerfil.input('carrera_id', sql.Int, carreraId);
            insertPerfil.input('etapa_academica', sql.VarChar(40), data.etapa_academica || 'PREGRADO');
            insertPerfil.input('ciclo', sql.VarChar(20), data.ciclo || 'X');
            insertPerfil.input('sede', sql.VarChar(80), data.sede || 'TRUJILLO');
            insertPerfil.input('tipo_investigacion', sql.VarChar(60), 'TESIS');
            insertPerfil.input('avance', sql.VarChar(30), '0-25%');

            await insertPerfil.query(`
                INSERT INTO PERFIL_ACADEMICO (
                    contacto_id, carrera_id, etapa_academica, ciclo, sede, tipo_investigacion, avance
                )
                VALUES (
                    @contacto_id, @carrera_id, @etapa_academica, @ciclo, @sede, @tipo_investigacion, @avance
                )
            `);
        }

        // 3. GESTIÓN DE BUYER
        const buyerReq = new sql.Request(transaction);
        buyerReq.input('contacto_id', sql.Int, contactoId);
        const buyerCheck = await buyerReq.query(`
            SELECT buyer_id, estado FROM BUYER WHERE contacto_id = @contacto_id
        `);

        const estadoBuyer = data.tiene_cobertura ? 'ACTIVO' : 'SIN_COBERTURA';
        let buyerId = null;

        if (buyerCheck.recordset.length > 0) {
            buyerId = buyerCheck.recordset[0].buyer_id;
            const updateBuyer = new sql.Request(transaction);
            updateBuyer.input('buyer_id', sql.Int, buyerId);
            updateBuyer.input('estado', sql.VarChar(30), estadoBuyer);
            updateBuyer.input('necesidad', sql.VarChar(150), data.necesidad_inicial || 'Asesoría de Tesis');
            await updateBuyer.query(`
                UPDATE BUYER 
                SET estado = @estado, 
                    necesidad_inicial = @necesidad 
                WHERE buyer_id = @buyer_id
            `);
        } else {
            const insertBuyer = new sql.Request(transaction);
            insertBuyer.input('contacto_id', sql.Int, contactoId);
            insertBuyer.input('canal_captacion_id', sql.Int, 1); // WhatsApp orgánico por defecto
            insertBuyer.input('servicio_interes_id', sql.Int, 2); // Asesoría Proyecto de Tesis
            insertBuyer.input('necesidad_inicial', sql.VarChar(150), data.necesidad_inicial || 'Asesoría Integral de Tesis');
            insertBuyer.input('estado', sql.VarChar(30), estadoBuyer);

            const buyerRes = await insertBuyer.query(`
                INSERT INTO BUYER (
                    contacto_id, canal_captacion_id, campania_id, 
                    servicio_interes_id, necesidad_inicial, fecha_buyer, estado
                )
                VALUES (
                    @contacto_id, @canal_captacion_id, NULL, 
                    @servicio_interes_id, @necesidad_inicial, SYSDATETIME(), @estado
                );
                SELECT SCOPE_IDENTITY() AS buyer_id;
            `);
            buyerId = buyerRes.recordset[0].buyer_id;
        }

        // Commit atómico de la transacción
        await transaction.commit();
        console.log(`✅ [Transacción Exitosa] BUYER registrado ID: ${buyerId} | Estado: ${estadoBuyer}`);

        return {
            exito: true,
            contacto_id: contactoId,
            buyer_id: buyerId,
            estado: estadoBuyer,
            mensaje: `Registro completado exitosamente en estado ${estadoBuyer}.`
        };

    } catch (err) {
        await transaction.rollback();
        console.error('❌ [Rollback Transaccional] Error al registrar buyer:', err.message);
        return { exito: false, error: err.message };
    }
}

// ------------------------------------------------------------------------------
// 3. REGISTRO DE AUDITORÍA (CONVERSACION Y MENSAJE)
// ------------------------------------------------------------------------------

async function asegurarConversacion(whatsappNumber) {
    try {
        const pool = await getDbPool();

        // 1. Buscar o registrar contacto inicial
        let contactRes = await pool.request()
            .input('wa', sql.VarChar(30), whatsappNumber)
            .query(`SELECT contacto_id FROM CONTACTO WHERE whatsapp = @wa`);

        let contactoId = null;
        if (contactRes.recordset.length > 0) {
            contactoId = contactRes.recordset[0].contacto_id;
        } else {
            let newContact = await pool.request()
                .input('wa', sql.VarChar(30), whatsappNumber)
                .query(`
                    INSERT INTO CONTACTO (nombres, whatsapp, consentimiento_contacto, fecha_registro, estado)
                    VALUES ('Estudiante WhatsApp', @wa, 1, SYSDATETIME(), 'ACTIVO');
                    SELECT SCOPE_IDENTITY() AS contacto_id;
                `);
            contactoId = newContact.recordset[0].contacto_id;
        }

        // 2. Buscar conversación activa o crear una nueva
        let convRes = await pool.request()
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

        let newConv = await pool.request()
            .input('cid', sql.Int, contactoId)
            .query(`
                INSERT INTO CONVERSACION (contacto_id, canal_id, campania_id, fecha_inicio, resuelta_sin_humano, estado)
                VALUES (@cid, 1, NULL, SYSDATETIME(), 1, 'EN_CURSO');
                SELECT SCOPE_IDENTITY() AS conversacion_id;
            `);

        return { contactoId, conversacionId: newConv.recordset[0].conversacion_id };

    } catch (err) {
        console.error('⚠️ Error al asegurar conversación:', err.message);
        return { contactoId: null, conversacionId: null };
    }
}

async function registrarMensajeEnBD(conversacionId, emisor, contenido) {
    if (!conversacionId) return;
    try {
        const pool = await getDbPool();
        await pool.request()
            .input('convId', sql.Int, conversacionId)
            .input('emisor', sql.VarChar(20), emisor)
            .input('contenido', sql.VarChar(1000), contenido ? contenido.substring(0, 1000) : '')
            .query(`
                INSERT INTO MENSAJE (conversacion_id, fecha_mensaje, emisor, tipo, contenido)
                VALUES (@convId, SYSDATETIME(), @emisor, 'TEXTO', @contenido);
            `);
    } catch (err) {
        console.error('⚠️ Error al registrar mensaje:', err.message);
    }
}

// ------------------------------------------------------------------------------
// 4. DEFINICIÓN DE TOOLS PARA GROK FUNCTION CALLING
// ------------------------------------------------------------------------------

const GROK_TOOLS = [
    {
        type: 'function',
        function: {
            name: 'verificar_cobertura',
            description: 'Verifica en la base de datos oficial de INBESTIGA si la universidad y la carrera del estudiante cuentan con cobertura de asesoría académica activa (campo atendida = 1).',
            parameters: {
                type: 'object',
                properties: {
                    universidad: {
                        type: 'string',
                        description: 'Nombre o acrónimo de la universidad (ej. Universidad Nacional de Trujillo, UNT, UPAO, UCV).'
                    },
                    carrera: {
                        type: 'string',
                        description: 'Nombre de la carrera o escuela profesional (ej. Ingenieria de Sistemas, Administracion, Derecho).'
                    }
                },
                required: ['universidad', 'carrera']
            }
        }
    },
    {
        type: 'function',
        function: {
            name: 'registrar_buyer',
            description: 'Registra transaccionalmente al estudiante como Buyer en la base de datos (CONTACTO -> PERFIL_ACADEMICO -> BUYER). Debe llamarse una vez que se conozca el nombre, universidad, carrera y se haya validado la cobertura.',
            parameters: {
                type: 'object',
                properties: {
                    nombres: {
                        type: 'string',
                        description: 'Nombres del estudiante.'
                    },
                    apellidos: {
                        type: 'string',
                        description: 'Apellidos del estudiante (opcional).'
                    },
                    whatsapp: {
                        type: 'string',
                        description: 'Número de WhatsApp del estudiante (ej. 987654321).'
                    },
                    correo: {
                        type: 'string',
                        description: 'Correo electrónico del estudiante si lo compartió (opcional).'
                    },
                    carrera_id: {
                        type: 'integer',
                        description: 'ID de la carrera retornado previamente por verificar_cobertura.'
                    },
                    etapa_academica: {
                        type: 'string',
                        enum: ['X CICLO', 'PREGRADO', 'EGRESADO', 'BACHILLER', 'TITULANDO'],
                        description: 'Etapa académica actual del estudiante.'
                    },
                    ciclo: {
                        type: 'string',
                        description: 'Ciclo cursado (ej. X, IX, o EGRESADO).'
                    },
                    sede: {
                        type: 'string',
                        description: 'Ciudad o sede universitaria (ej. TRUJILLO, LIMA).'
                    },
                    necesidad_inicial: {
                        type: 'string',
                        description: 'Breve descripción de lo que necesita para su tesis (ej. Proyecto de tesis, Elección de tema, Metodología).'
                    },
                    tiene_cobertura: {
                        type: 'boolean',
                        description: 'true si la universidad y carrera están atendidas; false si no tienen cobertura.'
                    }
                },
                required: ['nombres', 'whatsapp', 'carrera_id', 'tiene_cobertura']
            }
        }
    }
];

const SYSTEM_PROMPT = `
Eres el Agente de Admisión y Asesoría de Tesis de "INBESTIGA" para WhatsApp.
Tu objetivo en esta etapa (Fase BUYER) es interactuar con calidez, empatía y profesionalismo con los estudiantes que escriben, recopilando sus datos académicos para validar si tenemos cobertura en su Universidad y Carrera.

REGLAS DE CONVERSACIÓN:
1. Saluda cordialmente y preséntate como el asistente inteligente de INBESTIGA.
2. Solicita de forma conversacional y amigable:
   - Su nombre completo.
   - Su Universidad y Carrera profesional.
   - En qué etapa de su tesis se encuentra o qué dificultad tiene (tema, proyecto, informe final).
3. En cuanto el usuario mencione su Universidad y Carrera, DEBES invocar la herramienta "verificar_cobertura".
4. Una vez obtenida la respuesta de cobertura:
   - Invoca la herramienta "registrar_buyer" con los datos recopilados para guardarlo en la base de datos.
   - Si tiene cobertura (cobertura = true): Felicítalo, infórmale con entusiasmo que INBESTIGA cubre su programa y cuéntale que nuestro equipo de especialistas le ayudará a culminar su tesis con éxito.
   - Si NO tiene cobertura (cobertura = false): Infórmale cordialmente que por el momento su carrera o universidad no está dentro de nuestra cobertura activa inmediata, pero que sus datos han quedado registrados en nuestra lista de espera preferencial.
5. Mantén respuestas concisas, dinámicas y fáciles de leer en WhatsApp (párrafos breves, emojis moderados y profesionales).
`;

// ------------------------------------------------------------------------------
// 5. MOTOR DE PROCESAMIENTO IA (GROK + FUNCTION CALLING)
// ------------------------------------------------------------------------------

async function procesarMensajeConGrok(userPhone, userMessage) {
    // Inicializar o recuperar historial
    if (!conversationHistory.has(userPhone)) {
        conversationHistory.set(userPhone, [
            { role: 'system', content: SYSTEM_PROMPT }
        ]);
    }

    const messages = conversationHistory.get(userPhone);
    messages.push({ role: 'user', content: userMessage });

    try {
        let response = await xaiClient.chat.completions.create({
            model: GROK_MODEL,
            messages: messages,
            tools: GROK_TOOLS,
            tool_choice: 'auto',
            temperature: 0.3
        });

        let responseMessage = response.choices[0].message;

        // Bucle de manejo de Tool Calls (Function Calling)
        while (responseMessage.tool_calls && responseMessage.tool_calls.length > 0) {
            messages.push(responseMessage); // Agregar la solicitud de tool al historial

            for (const toolCall of responseMessage.tool_calls) {
                const functionName = toolCall.function.name;
                const functionArgs = JSON.parse(toolCall.function.arguments);
                let functionResult = null;

                if (functionName === 'verificar_cobertura') {
                    functionResult = await verificarCobertura(functionArgs);
                } else if (functionName === 'registrar_buyer') {
                    // Asegurar que el número de WhatsApp coincida con el remitente
                    functionArgs.whatsapp = functionArgs.whatsapp || userPhone;
                    functionResult = await registrarBuyerTransaccional(functionArgs);
                }

                messages.push({
                    role: 'tool',
                    tool_call_id: toolCall.id,
                    name: functionName,
                    content: JSON.stringify(functionResult)
                });
            }

            // Segunda llamada a Grok con los resultados de las funciones
            response = await xaiClient.chat.completions.create({
                model: GROK_MODEL,
                messages: messages,
                tools: GROK_TOOLS,
                temperature: 0.3
            });

            responseMessage = response.choices[0].message;
        }

        const replyText = responseMessage.content || '¡Gracias por comunicarte con INBESTIGA!';
        messages.push({ role: 'assistant', content: replyText });

        // Limitar longitud del historial para no saturar memoria
        if (messages.length > 20) {
            const trimmed = [messages[0], ...messages.slice(-12)];
            conversationHistory.set(userPhone, trimmed);
        }

        return replyText;

    } catch (err) {
        console.error('❌ Error llamando a Grok API:', err.message);
        return 'Hola, en este momento estamos actualizando nuestro sistema de admisiones. Por favor déjanos tu nombre, universidad y carrera para contactarte en breve.';
    }
}

// ------------------------------------------------------------------------------
// 6. INICIALIZACIÓN DEL CLIENTE WHATSAPP
// ------------------------------------------------------------------------------

console.log('🚀 Iniciando Agente WhatsApp de INBESTIGA...');

const client = new Client({
    authStrategy: new LocalAuth({
        dataPath: './.wwebjs_auth'
    }),
    puppeteer: {
        headless: true,
        args: [
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-dev-shm-usage',
            '--disable-accelerated-2d-canvas',
            '--no-first-run',
            '--no-zygote',
            '--disable-gpu'
        ]
    }
});

// Evento: Código QR para escanear en terminal
client.on('qr', (qr) => {
    console.log('\n======================================================');
    console.log('📲 ESCANEA ESTE CÓDIGO QR CON WHATSAPP EN TU CELULAR:');
    console.log('======================================================\n');
    qrcode.generate(qr, { small: true });
    console.log('\n(Dispositivos vinculados -> Vincular un dispositivo)\n');
});

client.on('authenticated', () => {
    console.log('🔑 [WhatsApp] Sesión autenticada correctamente.');
});

client.on('auth_failure', (msg) => {
    console.error('❌ [WhatsApp] Fallo de autenticación:', msg);
});

client.on('ready', () => {
    console.log('\n======================================================');
    console.log('🤖 AGENTE BUYER LISTO Y CONECTADO A WHATSAPP REAL');
    console.log('======================================================\n');
});

// Evento: Mensaje entrante de WhatsApp
client.on('message', async (msg) => {
    // Ignorar mensajes de grupos, estados o emitidos por el propio bot
    if (msg.from.includes('@g.us') || msg.isStatus || msg.fromMe) {
        return;
    }

    const rawPhone = msg.from.replace('@c.us', '');
    // Extraer número sin código de país si es Perú (+51) para alinearse con la BD
    const userPhone = rawPhone.startsWith('51') ? rawPhone.substring(2) : rawPhone;
    const userText = msg.body ? msg.body.trim() : '';

    if (!userText) return;

    console.log(`\n📩 [Mensaje Entrante] De: ${userPhone} | Texto: "${userText}"`);

    // 1. Trazabilidad: Registrar conversación y mensaje del cliente
    const { contactoId, conversacionId } = await asegurarConversacion(userPhone);
    await registrarMensajeEnBD(conversacionId, 'CLIENTE', userText);

    // 2. Procesar con Grok (xAI) y Function Calling
    const botReply = await procesarMensajeConGrok(userPhone, userText);

    // 3. Responder por WhatsApp
    await client.sendMessage(msg.from, botReply);
    console.log(`📤 [Respuesta Enviada] A: ${userPhone} | Respuesta: "${botReply}"`);

    // 4. Registrar mensaje del bot en auditoría
    await registrarMensajeEnBD(conversacionId, 'BOT', botReply);
});

// Iniciar conexión con base de datos y WhatsApp
getDbPool().then(() => {
    client.initialize();
}).catch((err) => {
    console.error('❌ Error crítico en inicio:', err.message);
});

