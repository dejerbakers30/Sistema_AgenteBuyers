/* ============================================================================
   database.sql - SCRIPT DE VERIFICACIÓN Y DATOS DE PRUEBA (FASE BUYER)
   Base de Datos: INBESTIGA_TESIS (SQL Server)
   ============================================================================
   Este script verifica la presencia de los catálogos base requeridos por el Bot
   y proporciona registros de prueba para validar el flujo completo.
   ============================================================================ */

USE INBESTIGA_TESIS;
GO
SET NOCOUNT ON;
GO

-- 1. VERIFICAR CANAL DE CAPTACIÓN POR DEFECTO (canal_id = 1)
IF NOT EXISTS (SELECT 1 FROM CANAL WHERE canal_id = 1)
BEGIN
    SET IDENTITY_INSERT CANAL ON;
    INSERT INTO CANAL (canal_id, nombre, tipo, plataforma)
    VALUES (1, 'WhatsApp organico', 'ORGANICO', 'WhatsApp');
    SET IDENTITY_INSERT CANAL OFF;
    PRINT '✅ Canal por defecto (canal_id = 1) creado.';
END
ELSE
BEGIN
    PRINT 'ℹ️ Canal por defecto (canal_id = 1) ya existe.';
END
GO

-- 2. VERIFICAR O INSERTAR UNIVERSIDADES Y CARRERAS DE PRUEBA
-- Caso Con Cobertura: atendida = 1
-- Caso Sin Cobertura: atendida = 0

IF NOT EXISTS (SELECT 1 FROM UNIVERSIDAD WHERE nombre LIKE '%Universidad Nacional de Trujillo%')
BEGIN
    INSERT INTO UNIVERSIDAD (nombre, tipo, departamento, distrito, norma_citacion, atendida)
    VALUES ('Universidad Nacional de Trujillo', 'PUBLICA', 'La Libertad', 'Trujillo', 'APA 7', 1);
END
GO

IF NOT EXISTS (SELECT 1 FROM UNIVERSIDAD WHERE nombre LIKE '%Universidad Privada Antenor Orrego%')
BEGIN
    INSERT INTO UNIVERSIDAD (nombre, tipo, departamento, distrito, norma_citacion, atendida)
    VALUES ('Universidad Privada Antenor Orrego', 'PRIVADA', 'La Libertad', 'Trujillo', 'APA 7', 1);
END
GO

-- Universidad sin cobertura para probar el flujo de SIN_COBERTURA
IF NOT EXISTS (SELECT 1 FROM UNIVERSIDAD WHERE nombre LIKE '%Universidad Sin Cobertura Demo%')
BEGIN
    INSERT INTO UNIVERSIDAD (nombre, tipo, departamento, distrito, norma_citacion, atendida)
    VALUES ('Universidad Sin Cobertura Demo', 'PRIVADA', 'Lima', 'Lima', 'Vancouver', 0);
END
GO

-- Carreras asociadas
DECLARE @uUntId INT = (SELECT TOP 1 universidad_id FROM UNIVERSIDAD WHERE nombre LIKE '%Nacional de Trujillo%');
IF @uUntId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CARRERA WHERE universidad_id = @uUntId AND nombre = 'Ingenieria de Sistemas')
BEGIN
    INSERT INTO CARRERA (universidad_id, nombre, facultad, atendida)
    VALUES (@uUntId, 'Ingenieria de Sistemas', 'Ingenieria', 1);
END
GO

-- Carrera sin cobertura para probar regla
DECLARE @uUpaoId INT = (SELECT TOP 1 universidad_id FROM UNIVERSIDAD WHERE nombre LIKE '%Antenor Orrego%');
IF @uUpaoId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CARRERA WHERE universidad_id = @uUpaoId AND nombre = 'Medicina Humana')
BEGIN
    INSERT INTO CARRERA (universidad_id, nombre, facultad, atendida)
    VALUES (@uUpaoId, 'Medicina Humana', 'Ciencias Medicas', 0);
END
GO

-- 3. INSERCIÓN DE EJEMPLO TRANSACCIONAL DE PRUEBA (Mismo patrón que ejecuta bot.js)
BEGIN TRANSACTION;

-- A. Insertar Contacto de Prueba
DECLARE @contacto_test INT;
INSERT INTO CONTACTO (nombres, apellidos, whatsapp, correo, consentimiento_contacto, fecha_consentimiento, no_contactar, fecha_registro, estado)
VALUES ('Estudiante Demo BI', 'Orbegoso', '987000111', 'demo.bi@inbestiga.pe', 1, SYSDATETIME(), 0, SYSDATETIME(), 'ACTIVO');
SET @contacto_test = SCOPE_IDENTITY();

-- B. Insertar Perfil Académico
DECLARE @carrera_test INT = (SELECT TOP 1 carrera_id FROM CARRERA WHERE atendida = 1);
INSERT INTO PERFIL_ACADEMICO (contacto_id, carrera_id, etapa_academica, ciclo, sede, tipo_investigacion, avance)
VALUES (@contacto_test, @carrera_test, 'X CICLO', 'X', 'TRUJILLO', 'TESIS', '0-25%');

-- C. Insertar Buyer con Cobertura ACTIVO
INSERT INTO BUYER (contacto_id, canal_captacion_id, campania_id, servicio_interes_id, necesidad_inicial, fecha_buyer, estado)
VALUES (@contacto_test, 1, NULL, 2, 'Proyecto de Tesis - Asesoría Metodológica', SYSDATETIME(), 'ACTIVO');

-- D. Conversación y Mensajes del Chat de Prueba
DECLARE @conv_test INT;
INSERT INTO CONVERSACION (contacto_id, canal_id, campania_id, fecha_inicio, resuelta_sin_humano, estado)
VALUES (@contacto_test, 1, NULL, SYSDATETIME(), 1, 'EN_CURSO');
SET @conv_test = SCOPE_IDENTITY();

INSERT INTO MENSAJE (conversacion_id, fecha_mensaje, emisor, tipo, contenido)
VALUES (@conv_test, DATEADD(SECOND, -15, SYSDATETIME()), 'CLIENTE', 'TEXTO', 'Hola, soy de la UNT de Sistemas y necesito ayuda con mi proyecto de tesis.');

INSERT INTO MENSAJE (conversacion_id, fecha_mensaje, emisor, tipo, contenido)
VALUES (@conv_test, SYSDATETIME(), 'BOT', 'TEXTO', '¡Hola! Qué gusto saludarte. En INBESTIGA sí atendemos a la Universidad Nacional de Trujillo en Ingeniería de Sistemas. Te acabamos de registrar con cobertura total.');

COMMIT TRANSACTION;
PRINT '✅ Transacción de prueba (CONTACTO -> PERFIL_ACADEMICO -> BUYER -> CONVERSACION -> MENSAJE) ejecutada correctamente.';
GO

-- 4. CONSULTA DE VERIFICACIÓN INMEDIATA (Lo que leerá el Dashboard Streamlit)
SELECT 
    b.buyer_id,
    b.fecha_buyer,
    b.estado AS estado_buyer,
    c.nombres,
    c.whatsapp,
    u.nombre AS universidad,
    cr.nombre AS carrera,
    pa.etapa_academica,
    b.necesidad_inicial
FROM BUYER b
INNER JOIN CONTACTO c ON c.contacto_id = b.contacto_id
LEFT JOIN PERFIL_ACADEMICO pa ON pa.contacto_id = c.contacto_id
LEFT JOIN CARRERA cr ON cr.carrera_id = pa.carrera_id
LEFT JOIN UNIVERSIDAD u ON u.universidad_id = cr.universidad_id
ORDER BY b.fecha_buyer DESC;
GO

