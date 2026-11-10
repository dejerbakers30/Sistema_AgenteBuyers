/* ============================================================================
01_CREAR_BD_TRANSACCIONAL.sql
INBESTIGA_TESIS - BASE DE DATOS TRANSACCIONAL
SQL SERVER / SSMS - VERSION DEFINITIVA CONSOLIDADA

Estructura fuente del aplicativo. Las tablas aqui creadas alimentan las
18 dimensiones y 13 hechos del DataMart mediante el script 04.

Correcciones de normalizacion aplicadas:
- PERFIL_ACADEMICO conserva carrera_id; la universidad se obtiene por CARRERA.
- RESPONSABLE_PAGO es la unica fuente del responsable/pagador real.
- El tipo de entregable se obtiene desde ENTREGABLE, no se duplica en HITO_CRONOGRAMA.
============================================================================ */
USE master;
GO
IF DB_ID('INBESTIGA_TESIS') IS NOT NULL
BEGIN
    ALTER DATABASE INBESTIGA_TESIS SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE INBESTIGA_TESIS;
END;
GO
CREATE DATABASE INBESTIGA_TESIS;
GO
USE INBESTIGA_TESIS;
GO
SET NOCOUNT ON;

CREATE TABLE UNIVERSIDAD(
 universidad_id INT IDENTITY PRIMARY KEY, nombre VARCHAR(120) NOT NULL, tipo VARCHAR(20) NOT NULL,
 departamento VARCHAR(60) NULL, distrito VARCHAR(60) NULL, norma_citacion VARCHAR(40) NULL, atendida BIT NOT NULL DEFAULT 1);
CREATE TABLE CARRERA(
 carrera_id INT IDENTITY PRIMARY KEY, universidad_id INT NOT NULL REFERENCES UNIVERSIDAD(universidad_id),
 nombre VARCHAR(120) NOT NULL, facultad VARCHAR(120) NULL, atendida BIT NOT NULL DEFAULT 1);
CREATE TABLE CONTACTO(
 contacto_id INT IDENTITY PRIMARY KEY, nombres VARCHAR(100) NOT NULL, apellidos VARCHAR(100) NULL,
 whatsapp VARCHAR(30) NOT NULL UNIQUE, correo VARCHAR(150) NULL, consentimiento_contacto BIT NOT NULL DEFAULT 1,
 fecha_consentimiento DATETIME2 NULL, no_contactar BIT NOT NULL DEFAULT 0, fecha_registro DATETIME2 NOT NULL DEFAULT SYSDATETIME(), estado VARCHAR(30) NOT NULL DEFAULT 'ACTIVO');
CREATE TABLE CANAL(
 canal_id INT IDENTITY PRIMARY KEY, nombre VARCHAR(80) NOT NULL, tipo VARCHAR(40) NOT NULL, plataforma VARCHAR(50) NOT NULL);
CREATE TABLE CAMPANIA(
 campania_id INT IDENTITY PRIMARY KEY, canal_id INT NOT NULL REFERENCES CANAL(canal_id), nombre VARCHAR(120) NOT NULL,
 fecha_inicio DATE NOT NULL, fecha_fin DATE NULL, inversion DECIMAL(12,2) NOT NULL DEFAULT 0);
CREATE TABLE PERFIL_ACADEMICO(
 perfil_academico_id INT IDENTITY PRIMARY KEY, contacto_id INT NOT NULL UNIQUE REFERENCES CONTACTO(contacto_id),
 carrera_id INT NOT NULL REFERENCES CARRERA(carrera_id),
 etapa_academica VARCHAR(40) NOT NULL, ciclo VARCHAR(20) NULL, sede VARCHAR(80) NULL,
 tipo_investigacion VARCHAR(60) NULL, avance VARCHAR(30) NULL, recomendado_por_contacto_id INT NULL REFERENCES CONTACTO(contacto_id));
CREATE TABLE SERVICIO(
 servicio_id INT IDENTITY PRIMARY KEY, familia VARCHAR(60) NOT NULL, nombre VARCHAR(120) NOT NULL,
 tipo_servicio VARCHAR(60) NOT NULL, paquete VARCHAR(60) NULL, modalidad VARCHAR(40) NULL,
 precio_referencia DECIMAL(12,2) NOT NULL DEFAULT 0, activo BIT NOT NULL DEFAULT 1);
CREATE TABLE ENTREGABLE(
 entregable_id INT IDENTITY PRIMARY KEY, nombre VARCHAR(120) NOT NULL, tipo_entregable VARCHAR(60) NOT NULL,
 descripcion VARCHAR(300) NULL, precio_extra DECIMAL(12,2) NOT NULL DEFAULT 0, activo BIT NOT NULL DEFAULT 1);
CREATE TABLE SERVICIO_ENTREGABLE(
 servicio_id INT NOT NULL REFERENCES SERVICIO(servicio_id), entregable_id INT NOT NULL REFERENCES ENTREGABLE(entregable_id),
 cantidad_incluida INT NULL, umbral_pct DECIMAL(6,2) NULL, frecuencia_dias INT NULL, duracion_min INT NULL,
 precio_unidad_extra DECIMAL(12,2) NULL, PRIMARY KEY(servicio_id,entregable_id));
CREATE TABLE CONTENIDO(
 contenido_id INT IDENTITY PRIMARY KEY, servicio_id INT NULL REFERENCES SERVICIO(servicio_id), tipo_contenido VARCHAR(50) NOT NULL,
 tema VARCHAR(120) NULL, titulo VARCHAR(180) NOT NULL);
CREATE TABLE BUYER(
 buyer_id INT IDENTITY PRIMARY KEY, contacto_id INT NOT NULL UNIQUE REFERENCES CONTACTO(contacto_id),
 canal_captacion_id INT NULL REFERENCES CANAL(canal_id), campania_id INT NULL REFERENCES CAMPANIA(campania_id),
 servicio_interes_id INT NULL REFERENCES SERVICIO(servicio_id), necesidad_inicial VARCHAR(150) NULL,
 fecha_buyer DATETIME2 NOT NULL, estado VARCHAR(30) NOT NULL);
CREATE TABLE INTERACCION_CAPTACION(
 interaccion_id INT IDENTITY PRIMARY KEY, buyer_id INT NOT NULL REFERENCES BUYER(buyer_id), canal_id INT NULL REFERENCES CANAL(canal_id),
 contenido_id INT NULL REFERENCES CONTENIDO(contenido_id), fecha_interaccion DATETIME2 NOT NULL,
 tipo_interaccion VARCHAR(60) NOT NULL, es_valor BIT NOT NULL DEFAULT 0);
CREATE TABLE DESCARGA_CONTENIDO(
 descarga_id INT IDENTITY PRIMARY KEY, buyer_id INT NOT NULL REFERENCES BUYER(buyer_id), contenido_id INT NOT NULL REFERENCES CONTENIDO(contenido_id),
 fecha_descarga DATETIME2 NOT NULL);
CREATE TABLE PLANTILLA_MENSAJE(
 plantilla_msg_id INT IDENTITY PRIMARY KEY, nombre VARCHAR(120) NOT NULL, tipo VARCHAR(50) NOT NULL,
 contenido VARCHAR(800) NOT NULL, ventana VARCHAR(20) NULL, activa BIT NOT NULL DEFAULT 1);
CREATE TABLE SEGUIMIENTO_BUYER(
 seguimiento_buyer_id INT IDENTITY PRIMARY KEY, buyer_id INT NOT NULL REFERENCES BUYER(buyer_id),
 plantilla_msg_id INT NULL REFERENCES PLANTILLA_MENSAJE(plantilla_msg_id), fecha_envio DATETIME2 NOT NULL,
 intento INT NOT NULL, intervalo_horas INT NULL, tipo_seguimiento VARCHAR(50) NOT NULL, resultado VARCHAR(60) NULL);
CREATE TABLE ASESOR(
 asesor_id INT IDENTITY PRIMARY KEY, nombre VARCHAR(120) NOT NULL, rol VARCHAR(30) NOT NULL,
 equipo VARCHAR(60) NULL, especialidad VARCHAR(100) NULL, activo BIT NOT NULL DEFAULT 1);
CREATE TABLE ASESOR_CARRERA(
 asesor_id INT NOT NULL REFERENCES ASESOR(asesor_id), carrera_id INT NOT NULL REFERENCES CARRERA(carrera_id),
 PRIMARY KEY(asesor_id,carrera_id));
CREATE TABLE LEAD(
 lead_id INT IDENTITY PRIMARY KEY, buyer_id INT NOT NULL UNIQUE REFERENCES BUYER(buyer_id), asesor_id INT NULL REFERENCES ASESOR(asesor_id),
 fecha_lead DATETIME2 NOT NULL, prioridad VARCHAR(20) NULL, estado VARCHAR(30) NOT NULL);
CREATE TABLE PERFIL_NEGOCIACION(
 perfil_negociacion_id INT IDENTITY PRIMARY KEY, lead_id INT NOT NULL UNIQUE REFERENCES LEAD(lead_id),
 disponibilidad VARCHAR(60) NULL, urgencia VARCHAR(30) NULL, nivel_confianza VARCHAR(30) NULL,
 completo BIT NOT NULL DEFAULT 0);
CREATE TABLE RESPONSABLE_PAGO(
 responsable_pago_id INT IDENTITY PRIMARY KEY, lead_id INT NOT NULL REFERENCES LEAD(lead_id),
 tipo_responsable VARCHAR(40) NOT NULL, relacion VARCHAR(60) NULL, segmento VARCHAR(60) NULL,
 nombre VARCHAR(120) NULL, participa_decision BIT NOT NULL DEFAULT 1);
CREATE TABLE DIAGNOSTICO(
 diagnostico_id INT IDENTITY PRIMARY KEY, lead_id INT NOT NULL REFERENCES LEAD(lead_id),
 fecha_solicitud DATETIME2 NOT NULL, fecha_entrega DATETIME2 NULL, tema_tesis VARCHAR(200) NULL,
 tipo_tesis VARCHAR(60) NULL, avance_declarado VARCHAR(30) NULL, limitaciones VARCHAR(300) NULL,
 tiene_empresa_aplicacion BIT NOT NULL DEFAULT 0, empresa_aplicacion VARCHAR(150) NULL, requiere_derivacion BIT NOT NULL DEFAULT 0);
CREATE TABLE TARIFA(
 tarifa_id INT IDENTITY PRIMARY KEY, servicio_id INT NOT NULL REFERENCES SERVICIO(servicio_id), carrera_id INT NULL REFERENCES CARRERA(carrera_id),
 etapa_academica VARCHAR(40) NULL, precio_base DECIMAL(12,2) NOT NULL, precio_minimo DECIMAL(12,2) NOT NULL,
 tope_descuento_pct DECIMAL(6,2) NOT NULL, vigente_desde DATE NOT NULL, vigente_hasta DATE NULL, activo BIT NOT NULL DEFAULT 1);
CREATE TABLE REGLA_PRECIO(
 regla_id INT IDENTITY PRIMARY KEY, nombre VARCHAR(120) NOT NULL, tipo VARCHAR(30) NOT NULL,
 factor DECIMAL(10,4) NULL, valor_condicion VARCHAR(100) NULL, umbral_dias INT NULL, porcentaje DECIMAL(6,2) NULL,
 vigente_desde DATE NOT NULL, vigente_hasta DATE NULL, activa BIT NOT NULL DEFAULT 1);
CREATE TABLE PROPUESTA(
 propuesta_id INT IDENTITY PRIMARY KEY, lead_id INT NOT NULL REFERENCES LEAD(lead_id), servicio_id INT NOT NULL REFERENCES SERVICIO(servicio_id),
 tarifa_id INT NULL REFERENCES TARIFA(tarifa_id), asesor_id INT NULL REFERENCES ASESOR(asesor_id), generada_por VARCHAR(20) NOT NULL,
 version INT NOT NULL DEFAULT 1, fecha_presentacion DATETIME2 NOT NULL, precio_base DECIMAL(12,2) NOT NULL,
 monto_extras DECIMAL(12,2) NOT NULL DEFAULT 0, descuento DECIMAL(12,2) NOT NULL DEFAULT 0, recargo DECIMAL(12,2) NOT NULL DEFAULT 0,
 precio_final AS (precio_base + monto_extras + recargo - descuento) PERSISTED,
 precio_minimo_aplicado DECIMAL(12,2) NOT NULL, tope_descuento_aplicado DECIMAL(6,2) NOT NULL,
 vigencia_hasta DATETIME2 NULL, estado VARCHAR(30) NOT NULL);
CREATE TABLE PROPUESTA_AJUSTE(
 ajuste_id INT IDENTITY PRIMARY KEY, propuesta_id INT NOT NULL REFERENCES PROPUESTA(propuesta_id), regla_id INT NULL REFERENCES REGLA_PRECIO(regla_id),
 tipo VARCHAR(30) NOT NULL, concepto VARCHAR(120) NOT NULL, porcentaje DECIMAL(6,2) NULL, monto DECIMAL(12,2) NOT NULL);
CREATE TABLE PROPUESTA_ENTREGABLE(
 propuesta_id INT NOT NULL REFERENCES PROPUESTA(propuesta_id), entregable_id INT NOT NULL REFERENCES ENTREGABLE(entregable_id),
 cantidad INT NOT NULL DEFAULT 1, precio_unitario DECIMAL(12,2) NOT NULL DEFAULT 0, es_extra BIT NOT NULL DEFAULT 0,
 PRIMARY KEY(propuesta_id,entregable_id));
CREATE TABLE RESPUESTA_PROPUESTA(
 respuesta_id INT IDENTITY PRIMARY KEY, propuesta_id INT NOT NULL REFERENCES PROPUESTA(propuesta_id),
 fecha_respuesta DATETIME2 NOT NULL, tipo_respuesta VARCHAR(30) NOT NULL, observacion VARCHAR(300) NULL);
CREATE TABLE OBJECION(
 objecion_id INT IDENTITY PRIMARY KEY, propuesta_id INT NOT NULL REFERENCES PROPUESTA(propuesta_id),
 grupo VARCHAR(60) NOT NULL, tipo VARCHAR(80) NOT NULL, descripcion VARCHAR(300) NULL, fecha_registro DATETIME2 NOT NULL,
 veces_repetida INT NOT NULL DEFAULT 1, escalada BIT NOT NULL DEFAULT 0, estado VARCHAR(30) NOT NULL,
 fecha_resolucion DATETIME2 NULL, resultado VARCHAR(60) NULL);
CREATE TABLE SEGUIMIENTO_LEAD(
 seguimiento_lead_id INT IDENTITY PRIMARY KEY, lead_id INT NOT NULL REFERENCES LEAD(lead_id), asesor_id INT NULL REFERENCES ASESOR(asesor_id),
 canal_id INT NULL REFERENCES CANAL(canal_id), plantilla_msg_id INT NULL REFERENCES PLANTILLA_MENSAJE(plantilla_msg_id),
 propuesta_id INT NULL REFERENCES PROPUESTA(propuesta_id), fecha_accion DATETIME2 NOT NULL, resultado VARCHAR(60) NULL, siguiente_accion VARCHAR(120) NULL);
CREATE TABLE PLANTILLA_CONTRATO(
 plantilla_contrato_id INT IDENTITY PRIMARY KEY, nombre VARCHAR(120) NOT NULL, version INT NOT NULL,
 clausulas_variables VARCHAR(MAX) NULL, vigente_desde DATE NOT NULL, activa BIT NOT NULL DEFAULT 1);
CREATE TABLE CONTRATO(
 contrato_id INT IDENTITY PRIMARY KEY, propuesta_id INT NOT NULL UNIQUE REFERENCES PROPUESTA(propuesta_id),
 plantilla_contrato_id INT NOT NULL REFERENCES PLANTILLA_CONTRATO(plantilla_contrato_id), fecha_generacion DATETIME2 NOT NULL,
 fecha_confirmacion DATETIME2 NULL, plazo_dias INT NULL, penalidad_pct DECIMAL(6,2) NULL, estado VARCHAR(30) NOT NULL);
CREATE TABLE MODALIDAD_PAGO(
 modalidad_pago_id INT IDENTITY PRIMARY KEY, nombre VARCHAR(80) NOT NULL, tipo_modalidad VARCHAR(40) NOT NULL,
 numero_cuotas INT NOT NULL, condicion VARCHAR(120) NULL, activa BIT NOT NULL DEFAULT 1);
CREATE TABLE MEDIO_PAGO(
 medio_pago_id INT IDENTITY PRIMARY KEY, nombre VARCHAR(80) NOT NULL, tipo_medio VARCHAR(40) NOT NULL,
 proveedor VARCHAR(80) NULL, comision_pct DECIMAL(6,3) NOT NULL DEFAULT 0, automatico BIT NOT NULL DEFAULT 0, activo BIT NOT NULL DEFAULT 1);
CREATE TABLE ORDEN_PAGO(
 orden_pago_id INT IDENTITY PRIMARY KEY, propuesta_id INT NOT NULL UNIQUE REFERENCES PROPUESTA(propuesta_id),
 contrato_id INT NULL REFERENCES CONTRATO(contrato_id), responsable_pago_id INT NULL REFERENCES RESPONSABLE_PAGO(responsable_pago_id),
 modalidad_pago_id INT NOT NULL REFERENCES MODALIDAD_PAGO(modalidad_pago_id), fecha_creacion DATETIME2 NOT NULL,
 monto_comprometido DECIMAL(12,2) NOT NULL, moneda CHAR(3) NOT NULL DEFAULT 'PEN', estado VARCHAR(30) NOT NULL);
CREATE TABLE PAYER(
 payer_id INT IDENTITY PRIMARY KEY, lead_id INT NOT NULL UNIQUE REFERENCES LEAD(lead_id), orden_pago_id INT NOT NULL UNIQUE REFERENCES ORDEN_PAGO(orden_pago_id),
 fecha_payer DATETIME2 NOT NULL, estado VARCHAR(30) NOT NULL);
CREATE TABLE HITO_CRONOGRAMA(
 hito_id INT IDENTITY PRIMARY KEY, customer_id INT NULL, entregable_id INT NOT NULL REFERENCES ENTREGABLE(entregable_id),
 capitulo VARCHAR(80) NULL, fecha_pactada DATETIME2 NOT NULL, fecha_entrega_real DATETIME2 NULL,
 estado VARCHAR(30) NOT NULL);
CREATE TABLE CUOTA_PAGO(
 cuota_id INT IDENTITY PRIMARY KEY, orden_pago_id INT NOT NULL REFERENCES ORDEN_PAGO(orden_pago_id),
 numero_cuota INT NOT NULL, porcentaje DECIMAL(6,2) NULL, monto_programado DECIMAL(12,2) NOT NULL,
 condicion VARCHAR(120) NULL, fecha_vencimiento DATETIME2 NULL, estado VARCHAR(30) NOT NULL, hito_id INT NULL REFERENCES HITO_CRONOGRAMA(hito_id));
CREATE TABLE ENLACE_PAGO(
 enlace_id INT IDENTITY PRIMARY KEY, orden_pago_id INT NOT NULL REFERENCES ORDEN_PAGO(orden_pago_id), cuota_id INT NULL REFERENCES CUOTA_PAGO(cuota_id),
 medio_pago_id INT NULL REFERENCES MEDIO_PAGO(medio_pago_id), referencia_externa VARCHAR(120) NULL,
 fecha_envio DATETIME2 NOT NULL, fecha_expiracion DATETIME2 NULL, estado VARCHAR(30) NOT NULL);
CREATE TABLE PAGO(
 pago_id INT IDENTITY PRIMARY KEY, orden_pago_id INT NOT NULL REFERENCES ORDEN_PAGO(orden_pago_id), cuota_id INT NULL REFERENCES CUOTA_PAGO(cuota_id),
 medio_pago_id INT NOT NULL REFERENCES MEDIO_PAGO(medio_pago_id), fecha_inicio DATETIME2 NOT NULL, fecha_confirmacion DATETIME2 NULL,
 monto_pagado DECIMAL(12,2) NOT NULL, comision_pasarela DECIMAL(12,2) NOT NULL DEFAULT 0, referencia VARCHAR(120) NULL,
 metodo_verificacion VARCHAR(40) NOT NULL, verificado_por_asesor_id INT NULL REFERENCES ASESOR(asesor_id), estado VARCHAR(30) NOT NULL);
CREATE TABLE EVENTO_WEBHOOK(
 evento_id INT IDENTITY PRIMARY KEY, pago_id INT NULL REFERENCES PAGO(pago_id), proveedor VARCHAR(80) NOT NULL,
 tipo_evento VARCHAR(60) NOT NULL, fecha_recepcion DATETIME2 NOT NULL, procesado BIT NOT NULL DEFAULT 0, detalle VARCHAR(400) NULL);
CREATE TABLE ALERTA_COBRANZA(
 alerta_cobranza_id INT IDENTITY PRIMARY KEY, orden_pago_id INT NOT NULL REFERENCES ORDEN_PAGO(orden_pago_id), cuota_id INT NULL REFERENCES CUOTA_PAGO(cuota_id),
 plantilla_msg_id INT NULL REFERENCES PLANTILLA_MENSAJE(plantilla_msg_id), fecha_envio DATETIME2 NOT NULL,
 secuencia INT NOT NULL, tipo VARCHAR(50) NOT NULL, resultado VARCHAR(60) NULL, escalado BIT NOT NULL DEFAULT 0);
CREATE TABLE CUSTOMER(
 customer_id INT IDENTITY PRIMARY KEY, payer_id INT NOT NULL UNIQUE REFERENCES PAYER(payer_id), fecha_activacion DATETIME2 NOT NULL,
 estado_servicio VARCHAR(30) NOT NULL, fecha_cierre DATETIME2 NULL);
ALTER TABLE HITO_CRONOGRAMA ADD CONSTRAINT FK_HITO_CUSTOMER FOREIGN KEY(customer_id) REFERENCES CUSTOMER(customer_id);
CREATE TABLE ASIGNACION_ASESOR(
 asignacion_id INT IDENTITY PRIMARY KEY, customer_id INT NOT NULL REFERENCES CUSTOMER(customer_id), asesor_id INT NOT NULL REFERENCES ASESOR(asesor_id),
 fecha_asignacion DATETIME2 NOT NULL, activa BIT NOT NULL DEFAULT 1);
CREATE TABLE SESION(
 sesion_id INT IDENTITY PRIMARY KEY, customer_id INT NOT NULL REFERENCES CUSTOMER(customer_id), asesor_id INT NOT NULL REFERENCES ASESOR(asesor_id),
 tipo_sesion VARCHAR(60) NOT NULL, modalidad VARCHAR(30) NOT NULL, fecha_programada DATETIME2 NOT NULL,
 fecha_real DATETIME2 NULL, duracion_min INT NULL, estado VARCHAR(30) NOT NULL);
CREATE TABLE REPROGRAMACION_SESION(
 reprogramacion_id INT IDENTITY PRIMARY KEY, sesion_id INT NOT NULL REFERENCES SESION(sesion_id),
 fecha_anterior DATETIME2 NOT NULL, fecha_nueva DATETIME2 NOT NULL, motivo VARCHAR(200) NULL, fecha_registro DATETIME2 NOT NULL);
CREATE TABLE REPORTE_CALIDAD(
 reporte_calidad_id INT IDENTITY PRIMARY KEY, hito_id INT NOT NULL REFERENCES HITO_CRONOGRAMA(hito_id),
 fecha_emision DATETIME2 NOT NULL, porcentaje_similitud DECIMAL(6,2) NULL, porcentaje_ia DECIMAL(6,2) NULL,
 umbral_vigente DECIMAL(6,2) NULL, cumple_umbral BIT NOT NULL, costo_turnitin DECIMAL(12,2) NOT NULL DEFAULT 0);
CREATE TABLE OBSERVACION_UNIVERSITARIA(
 observacion_id INT IDENTITY PRIMARY KEY, hito_id INT NOT NULL REFERENCES HITO_CRONOGRAMA(hito_id),
 fecha_recepcion DATETIME2 NOT NULL, fecha_levantamiento DATETIME2 NULL, estado VARCHAR(30) NOT NULL,
 es_ronda_extra BIT NOT NULL DEFAULT 0, monto_extra DECIMAL(12,2) NOT NULL DEFAULT 0, detalle VARCHAR(300) NULL);
CREATE TABLE ENCUESTA_SATISFACCION(
 encuesta_id INT IDENTITY PRIMARY KEY, customer_id INT NOT NULL REFERENCES CUSTOMER(customer_id),
 fecha_encuesta DATETIME2 NOT NULL, puntaje DECIMAL(4,2) NOT NULL CHECK(puntaje BETWEEN 1 AND 5), comentario VARCHAR(300) NULL);
CREATE TABLE HONORARIO_TARIFA(
 honorario_tarifa_id INT IDENTITY PRIMARY KEY, servicio_id INT NOT NULL REFERENCES SERVICIO(servicio_id),
 rol VARCHAR(30) NOT NULL, monto_base DECIMAL(12,2) NOT NULL, vigente_desde DATE NOT NULL, vigente_hasta DATE NULL, activo BIT NOT NULL DEFAULT 1);
CREATE TABLE HONORARIO(
 honorario_id INT IDENTITY PRIMARY KEY, customer_id INT NOT NULL REFERENCES CUSTOMER(customer_id), asesor_id INT NOT NULL REFERENCES ASESOR(asesor_id),
 honorario_tarifa_id INT NULL REFERENCES HONORARIO_TARIFA(honorario_tarifa_id), fecha_devengo DATETIME2 NOT NULL,
 monto DECIMAL(12,2) NOT NULL, estado VARCHAR(30) NOT NULL);
CREATE TABLE LICENCIA_HERRAMIENTA(
 licencia_id INT IDENTITY PRIMARY KEY, nombre VARCHAR(100) NOT NULL, proveedor VARCHAR(100) NULL,
 costo_mensual DECIMAL(12,2) NOT NULL, fecha_inicio DATE NOT NULL, fecha_fin DATE NULL, activa BIT NOT NULL DEFAULT 1);
CREATE TABLE CIERRE_SERVICIO(
 cierre_id INT IDENTITY PRIMARY KEY, customer_id INT NOT NULL UNIQUE REFERENCES CUSTOMER(customer_id),
 fecha_cierre DATETIME2 NOT NULL, motivo VARCHAR(120) NULL, estado_final VARCHAR(30) NOT NULL);
CREATE TABLE CERTIFICADO_GARANTIA(
 certificado_id INT IDENTITY PRIMARY KEY, customer_id INT NOT NULL UNIQUE REFERENCES CUSTOMER(customer_id),
 fecha_emision DATETIME2 NOT NULL, vigencia_dias INT NOT NULL, condiciones VARCHAR(300) NULL, estado VARCHAR(30) NOT NULL);
CREATE TABLE ALERTA_SERVICIO(
 alerta_servicio_id INT IDENTITY PRIMARY KEY, customer_id INT NOT NULL REFERENCES CUSTOMER(customer_id), sesion_id INT NULL REFERENCES SESION(sesion_id),
 hito_id INT NULL REFERENCES HITO_CRONOGRAMA(hito_id), plantilla_msg_id INT NULL REFERENCES PLANTILLA_MENSAJE(plantilla_msg_id),
 fecha_generacion DATETIME2 NOT NULL, tipo VARCHAR(60) NOT NULL, estado VARCHAR(30) NOT NULL);
CREATE TABLE EVALUACION_RIESGO(
 evaluacion_riesgo_id INT IDENTITY PRIMARY KEY, customer_id INT NOT NULL REFERENCES CUSTOMER(customer_id),
 fecha_evaluacion DATETIME2 NOT NULL, nivel VARCHAR(20) NOT NULL, puntaje INT NOT NULL, motivo VARCHAR(300) NULL);
CREATE TABLE CONVERSACION(
 conversacion_id INT IDENTITY PRIMARY KEY, contacto_id INT NOT NULL REFERENCES CONTACTO(contacto_id), canal_id INT NOT NULL REFERENCES CANAL(canal_id),
 campania_id INT NULL REFERENCES CAMPANIA(campania_id), fecha_inicio DATETIME2 NOT NULL, fecha_cierre DATETIME2 NULL,
 resuelta_sin_humano BIT NOT NULL DEFAULT 0, estado VARCHAR(30) NOT NULL);
CREATE TABLE MENSAJE(
 mensaje_id INT IDENTITY PRIMARY KEY, conversacion_id INT NOT NULL REFERENCES CONVERSACION(conversacion_id),
 fecha_mensaje DATETIME2 NOT NULL, emisor VARCHAR(20) NOT NULL, tipo VARCHAR(30) NOT NULL, contenido VARCHAR(1000) NULL,
 plantilla_msg_id INT NULL REFERENCES PLANTILLA_MENSAJE(plantilla_msg_id));
CREATE TABLE ESCALAMIENTO(
 escalamiento_id INT IDENTITY PRIMARY KEY, conversacion_id INT NOT NULL UNIQUE REFERENCES CONVERSACION(conversacion_id),
 lead_id INT NULL REFERENCES LEAD(lead_id), asesor_id INT NULL REFERENCES ASESOR(asesor_id), fecha DATETIME2 NOT NULL,
 fecha_atencion DATETIME2 NULL, motivo VARCHAR(100) NOT NULL, destino VARCHAR(40) NOT NULL, estado VARCHAR(30) NOT NULL);
CREATE TABLE META(
 meta_id INT IDENTITY PRIMARY KEY, periodo DATE NOT NULL, fase VARCHAR(20) NOT NULL, indicador VARCHAR(20) NOT NULL,
 carrera_id INT NOT NULL REFERENCES CARRERA(carrera_id), valor_meta DECIMAL(14,4) NOT NULL, valor_real DECIMAL(14,4) NOT NULL);
GO
CREATE VIEW dbo.v_MargenCustomer AS
SELECT c.customer_id,
       ingresos = ISNULL(SUM(CASE WHEN p.estado='CONFIRMADO' THEN p.monto_pagado ELSE 0 END),0),
       comision_pasarela = ISNULL(SUM(CASE WHEN p.estado='CONFIRMADO' THEN p.comision_pasarela ELSE 0 END),0),
       honorarios = ISNULL((SELECT SUM(h.monto) FROM HONORARIO h WHERE h.customer_id=c.customer_id),0),
       costo_turnitin = ISNULL((SELECT SUM(rc.costo_turnitin) FROM REPORTE_CALIDAD rc JOIN HITO_CRONOGRAMA hc ON hc.hito_id=rc.hito_id WHERE hc.customer_id=c.customer_id),0),
       margen = ISNULL(SUM(CASE WHEN p.estado='CONFIRMADO' THEN p.monto_pagado-p.comision_pasarela ELSE 0 END),0)
                - ISNULL((SELECT SUM(h.monto) FROM HONORARIO h WHERE h.customer_id=c.customer_id),0)
                - ISNULL((SELECT SUM(rc.costo_turnitin) FROM REPORTE_CALIDAD rc JOIN HITO_CRONOGRAMA hc ON hc.hito_id=rc.hito_id WHERE hc.customer_id=c.customer_id),0)
FROM CUSTOMER c
JOIN PAYER py ON py.payer_id=c.payer_id
JOIN ORDEN_PAGO op ON op.orden_pago_id=py.orden_pago_id
LEFT JOIN PAGO p ON p.orden_pago_id=op.orden_pago_id
GROUP BY c.customer_id;
GO
PRINT 'INBESTIGA_TESIS creada: 59 tablas + 1 vista.';
GO
