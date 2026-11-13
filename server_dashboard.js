/**
 * ==============================================================================
 * server_dashboard.js - SERVIDOR API REST & FRONTEND REACT (INBESTIGA BI)
 * ==============================================================================
 * Servidor Express que expone los endpoints para el Dashboard React y sirve
 * la aplicación web moderna en tiempo real conectada a SQL Server (INBESTIGA_TESIS).
 * ==============================================================================
 */

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// ── Configuración de Conexión a SQL Server (Windows Authentication) ───────────
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
                enableArithAbort       : true
            }
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
            enableArithAbort       : true
        }
    };
}

let pool = null;
async function getPool() {
    if (pool && pool.connected) return pool;
    pool = await sql.connect(dbConfig);
    return pool;
}

// ── ENDPOINTS REST API ────────────────────────────────────────────────────────

/**
 * GET /api/status - Estado del servidor y hora de SQL Server
 */
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

/**
 * GET /api/buyers - Lista detallada de Buyers con información académica
 */
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

/**
 * GET /api/conversaciones - Mensajes registrados para auditoría de chat
 */
app.get('/api/conversaciones', async (req, res) => {
    try {
        const p = await getPool();
        const query = `
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
            ORDER BY m.mensaje_id ASC;
        `;
        const result = await p.request().query(query);
        res.json(result.recordset);
    } catch (err) {
        console.error('❌ [API /conversaciones] Error:', err.message);
        res.status(500).json({ error: err.message });
    }
});

// Fallback para SPA React (compatible con Express 5)
app.use((req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// ── Iniciar Servidor ───────────────────────────────────────────────────────────
app.listen(PORT, async () => {
    console.log(`\n🚀 ════════════════════════════════════════════════════════════`);
    console.log(`   INBESTIGA · Dashboard BI en React & API REST`);
    console.log(`   Servidor activo en: http://localhost:${PORT}`);
    console.log(`════════════════════════════════════════════════════════════════\n`);
    try {
        await getPool();
        console.log('✅ [SQL Server] Conectado exitosamente a INBESTIGA_TESIS');
    } catch (err) {
        console.error('⚠️  [SQL Server] No se pudo conectar de inmediato:', err.message);
    }
});
