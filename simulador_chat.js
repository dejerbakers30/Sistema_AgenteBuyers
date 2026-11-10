/**
 * ==============================================================================
 * simulador_chat.js - SIMULADOR DE CHAT PARA PRUEBAS (SIN DEPENDER DEL CELULAR)
 * ==============================================================================
 * Permite probar el ciclo completo:
 * 1. Simulación de mensaje de un estudiante.
 * 2. Invocación a Grok (xAI API) con Function Calling.
 * 3. Ejecución de verificar_cobertura y registrar_buyer en SQL Server.
 * 4. Actualización en tiempo real visible en el Dashboard de Streamlit.
 * ==============================================================================
 * Uso:
 *   node simulador_chat.js "Hola, soy Mariana Diaz de la UPAO, estudio Administracion y necesito ayuda con mi proyecto de tesis" 987654321
 * ==============================================================================
 */

require('dotenv').config();
const sql = require('mssql');
const OpenAI = require('openai');

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
    }
};

const xaiClient = new OpenAI({
    apiKey: process.env.XAI_API_KEY || 'dummy-key',
    baseURL: 'https://api.x.ai/v1'
});
const GROK_MODEL = process.env.XAI_MODEL || 'grok-2-latest';

async function verificarCobertura(pool, { universidad, carrera }) {
    console.log(`\n🔍 [Tool Call] verificar_cobertura: "${universidad}" | "${carrera}"`);
    const req = pool.request();
    req.input('uFiltro', sql.VarChar, `%${universidad.trim()}%`);
    req.input('cFiltro', sql.VarChar, `%${carrera.trim()}%`);

    const query = `
        SELECT TOP 1
            u.universidad_id, u.nombre AS universidad_nombre, u.atendida AS universidad_atendida,
            c.carrera_id, c.nombre AS carrera_nombre, c.atendida AS carrera_atendida
        FROM UNIVERSIDAD u
        INNER JOIN CARRERA c ON c.universidad_id = u.universidad_id
        WHERE u.nombre LIKE @uFiltro AND c.nombre LIKE @cFiltro;
    `;
    const res = await req.query(query);

    if (res.recordset.length > 0) {
        const row = res.recordset[0];
        const cobertura = (row.universidad_atendida === true || row.universidad_atendida === 1) &&
                          (row.carrera_atendida === true || row.carrera_atendida === 1);
        console.log(`   Resultado: ${cobertura ? '✅ Cobertura ACTIVA' : '⚠️ SIN COBERTURA'} (${row.universidad_nombre} - ${row.carrera_nombre})`);
        return {
            encontrado: true,
            universidad_id: row.universidad_id,
            universidad_nombre: row.universidad_nombre,
            carrera_id: row.carrera_id,
            carrera_nombre: row.carrera_nombre,
            cobertura: cobertura
        };
    }
    console.log(`   Resultado: ⚠️ No encontrado en catálogo directo -> Sin cobertura.`);
    return { encontrado: false, carrera_id: 1, cobertura: false };
}

async function registrarBuyerTransaccional(pool, data) {
    console.log(`\n📝 [Tool Call] registrar_buyer: Transacción atómica iniciada...`);
    const transaction = new sql.Transaction(pool);
    try {
        await transaction.begin();

        // 1. CONTACTO
        let cReq = new sql.Request(transaction);
        cReq.input('wa', sql.VarChar(30), data.whatsapp);
        let cRes = await cReq.query(`SELECT contacto_id FROM CONTACTO WHERE whatsapp = @wa`);
        let contactoId = null;

        if (cRes.recordset.length > 0) {
            contactoId = cRes.recordset[0].contacto_id;
            let uReq = new sql.Request(transaction);
            uReq.input('cid', sql.Int, contactoId);
            uReq.input('nom', sql.VarChar(100), data.nombres);
            uReq.input('ape', sql.VarChar(100), data.apellidos || 'Por Asignar');
            await uReq.query(`UPDATE CONTACTO SET nombres = @nom, apellidos = @ape WHERE contacto_id = @cid`);
        } else {
            let iReq = new sql.Request(transaction);
            iReq.input('nom', sql.VarChar(100), data.nombres);
            iReq.input('ape', sql.VarChar(100), data.apellidos || 'Por Asignar');
            iReq.input('wa', sql.VarChar(30), data.whatsapp);
            let iRes = await iReq.query(`
                INSERT INTO CONTACTO (nombres, apellidos, whatsapp, consentimiento_contacto, fecha_registro, estado)
                VALUES (@nom, @ape, @wa, 1, SYSDATETIME(), 'ACTIVO');
                SELECT SCOPE_IDENTITY() AS contacto_id;
            `);
            contactoId = iRes.recordset[0].contacto_id;
        }

        // 2. PERFIL_ACADEMICO
        let pReq = new sql.Request(transaction);
        pReq.input('cid', sql.Int, contactoId);
        let pRes = await pReq.query(`SELECT perfil_academico_id FROM PERFIL_ACADEMICO WHERE contacto_id = @cid`);
        let carreraId = data.carrera_id || 1;

        if (pRes.recordset.length === 0) {
            let ipReq = new sql.Request(transaction);
            ipReq.input('cid', sql.Int, contactoId);
            ipReq.input('carr', sql.Int, carreraId);
            ipReq.input('etapa', sql.VarChar(40), data.etapa_academica || 'PREGRADO');
            ipReq.input('ciclo', sql.VarChar(20), data.ciclo || 'X');
            ipReq.input('sede', sql.VarChar(80), data.sede || 'TRUJILLO');
            await ipReq.query(`
                INSERT INTO PERFIL_ACADEMICO (contacto_id, carrera_id, etapa_academica, ciclo, sede, tipo_investigacion, avance)
                VALUES (@cid, @carr, @etapa, @ciclo, @sede, 'TESIS', '0-25%');
            `);
        }

        // 3. BUYER
        let estadoBuyer = data.tiene_cobertura ? 'ACTIVO' : 'SIN_COBERTURA';
        let bReq = new sql.Request(transaction);
        bReq.input('cid', sql.Int, contactoId);
        let bRes = await bReq.query(`SELECT buyer_id FROM BUYER WHERE contacto_id = @cid`);
        let buyerId = null;

        if (bRes.recordset.length > 0) {
            buyerId = bRes.recordset[0].buyer_id;
            let ubReq = new sql.Request(transaction);
            ubReq.input('bid', sql.Int, buyerId);
            ubReq.input('est', sql.VarChar(30), estadoBuyer);
            await ubReq.query(`UPDATE BUYER SET estado = @est WHERE buyer_id = @bid`);
        } else {
            let ibReq = new sql.Request(transaction);
            ibReq.input('cid', sql.Int, contactoId);
            ibReq.input('nec', sql.VarChar(150), data.necesidad_inicial || 'Asesoría Integral de Tesis');
            ibReq.input('est', sql.VarChar(30), estadoBuyer);
            let ibRes = await ibReq.query(`
                INSERT INTO BUYER (contacto_id, canal_captacion_id, campania_id, servicio_interes_id, necesidad_inicial, fecha_buyer, estado)
                VALUES (@cid, 1, NULL, 2, @nec, SYSDATETIME(), @est);
                SELECT SCOPE_IDENTITY() AS buyer_id;
            `);
            buyerId = ibRes.recordset[0].buyer_id;
        }

        await transaction.commit();
        console.log(`   ✅ Transacción completada: BUYER ID = ${buyerId} [${estadoBuyer}]`);
        return { exito: true, buyer_id: buyerId, estado: estadoBuyer };
    } catch (err) {
        await transaction.rollback();
        console.error(`   ❌ Error en transacción: ${err.message}`);
        return { exito: false, error: err.message };
    }
}

async function simular() {
    const userMessage = process.argv[2] || "Hola, me llamo Carlos Ramirez, estudio Ingenieria de Sistemas en la Universidad Privada Antenor Orrego y busco ayuda para el informe final de mi tesis.";
    const userPhone = process.argv[3] || "955112233";

    console.log("=" * 70);
    console.log("🚀 SIMULADOR DE CHAT - INBESTIGA (FASE BUYER)");
    console.log("=" * 70);
    console.log(`📱 Remitente (Simulado): ${userPhone}`);
    console.log(`💬 Mensaje: "${userMessage}"`);

    let pool;
    try {
        pool = await sql.connect(dbConfig);
        console.log("✅ Conexión establecida con SQL Server.");
    } catch (e) {
        console.error("❌ No se pudo conectar a SQL Server:", e.message);
        return;
    }

    const GROK_TOOLS = [
        {
            type: 'function',
            function: {
                name: 'verificar_cobertura',
                description: 'Verifica si la universidad y carrera tienen cobertura de asesoría en INBESTIGA.',
                parameters: {
                    type: 'object',
                    properties: {
                        universidad: { type: 'string' },
                        carrera: { type: 'string' }
                    },
                    required: ['universidad', 'carrera']
                }
            }
        },
        {
            type: 'function',
            function: {
                name: 'registrar_buyer',
                description: 'Inserta transaccionalmente al estudiante como Buyer en la BD de INBESTIGA.',
                parameters: {
                    type: 'object',
                    properties: {
                        nombres: { type: 'string' },
                        apellidos: { type: 'string' },
                        whatsapp: { type: 'string' },
                        correo: { type: 'string' },
                        carrera_id: { type: 'integer' },
                        etapa_academica: { type: 'string' },
                        ciclo: { type: 'string' },
                        sede: { type: 'string' },
                        necesidad_inicial: { type: 'string' },
                        tiene_cobertura: { type: 'boolean' }
                    },
                    required: ['nombres', 'whatsapp', 'carrera_id', 'tiene_cobertura']
                }
            }
        }
    ];

    const messages = [
        {
            role: 'system',
            content: `Eres el Asesor Virtual de Tesis de INBESTIGA. Extrae el nombre, universidad, carrera y necesidad del estudiante. Llama a verificar_cobertura y luego a registrar_buyer. Responde cordialmente confirmando si hay cobertura o informando que quedó en lista de espera.`
        },
        { role: 'user', content: userMessage }
    ];

    console.log("\n🧠 Consultando a Grok (xAI) con Function Calling...");

    try {
        let response = await xaiClient.chat.completions.create({
            model: GROK_MODEL,
            messages: messages,
            tools: GROK_TOOLS,
            tool_choice: 'auto'
        });

        let responseMsg = response.choices[0].message;

        while (responseMsg.tool_calls && responseMsg.tool_calls.length > 0) {
            messages.push(responseMsg);
            for (const tool of responseMsg.tool_calls) {
                const name = tool.function.name;
                const args = JSON.parse(tool.function.arguments);
                let result = null;

                if (name === 'verificar_cobertura') {
                    result = await verificarCobertura(pool, args);
                } else if (name === 'registrar_buyer') {
                    args.whatsapp = userPhone;
                    result = await registrarBuyerTransaccional(pool, args);
                }

                messages.push({
                    role: 'tool',
                    tool_call_id: tool.id,
                    name: name,
                    content: JSON.stringify(result)
                });
            }

            response = await xaiClient.chat.completions.create({
                model: GROK_MODEL,
                messages: messages,
                tools: GROK_TOOLS
            });
            responseMsg = response.choices[0].message;
        }

        console.log("\n🤖 RESPUESTA FINAL DEL AGENTE IA:");
        console.log(`"${responseMsg.content}"`);
        console.log("\n✅ La base de datos ha sido actualizada. Abre tu navegador en Streamlit para ver el nuevo registro.");

    } catch (err) {
        console.error("❌ Error en simulación:", err.message);
    } finally {
        await pool.close();
    }
}

simular();

