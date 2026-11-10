/* ============================================================================
03_CREAR_DATAMART_DEFINITIVO.sql
INBESTIGA_MART - MODELO DIMENSIONAL
SQL SERVER / SSMS

MODELO:
- 18 dimensiones
- 13 hechos
- DIM_TIEMPO se conserva exactamente como estaba acordada.
- En las demás dimensiones: primero niveles jerárquicos de mayor a menor; luego atributos descriptivos; id natural al final.
- No se duplican atributos que pertenecen a otra dimensión.
- Los hechos NO tienen Fact...Key artificial
- Las FK de los hechos son NOT NULL
- Miembros técnicos: Key -1 = DESCONOCIDO, Key 0 = NO APLICA
============================================================================ */

USE master;
GO

IF DB_ID('INBESTIGA_MART') IS NOT NULL
BEGIN
    ALTER DATABASE INBESTIGA_MART SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE INBESTIGA_MART;
END;
GO

CREATE DATABASE INBESTIGA_MART;
GO

USE INBESTIGA_MART;
GO

/* ============================================================================
18 DIMENSIONES
============================================================================ */

CREATE TABLE dbo.DIM_TIEMPO(
    KeyTiempo INT IDENTITY(1,1) PRIMARY KEY,
    Anio INT NULL,
    Trimestre VARCHAR(150) NULL,
    NroMes INT NULL,
    Mes VARCHAR(150) NULL,
    Semana INT NULL,
    DiaSemana VARCHAR(150) NULL,
    Dia INT NULL,
    idFecha DATE NOT NULL
);
GO

CREATE TABLE dbo.DIM_ESTUDIANTE(
    KeyEstudiante INT IDENTITY(1,1) PRIMARY KEY,
    Sede VARCHAR(150) NULL,
    EtapaAcademica VARCHAR(150) NULL,
    Ciclo VARCHAR(150) NULL,
    idPerfilAcademico INT NOT NULL
);
GO

CREATE TABLE dbo.DIM_CARRERA(
    KeyCarrera INT IDENTITY(1,1) PRIMARY KEY,
    TipoUniversidad VARCHAR(150) NULL,
    Universidad VARCHAR(150) NULL,
    Facultad VARCHAR(150) NULL,
    Carrera VARCHAR(150) NULL,
    idCarrera INT NOT NULL
);
GO

CREATE TABLE dbo.DIM_CANAL_CAPTACION(
    KeyCanalCaptacion INT IDENTITY(1,1) PRIMARY KEY,
    TipoCanal VARCHAR(150) NULL,
    Plataforma VARCHAR(150) NULL,
    Canal VARCHAR(150) NULL,
    Campania VARCHAR(150) NULL,
    idCanal INT NOT NULL,
    idCampania INT NOT NULL
);
GO

CREATE TABLE dbo.DIM_CONTENIDO(
    KeyContenido INT IDENTITY(1,1) PRIMARY KEY,
    TipoContenido VARCHAR(150) NULL,
    Tema VARCHAR(150) NULL,
    Titulo VARCHAR(250) NULL,
    idContenido INT NOT NULL
);
GO

CREATE TABLE dbo.DIM_SERVICIO(
    KeyServicio INT IDENTITY(1,1) PRIMARY KEY,
    Familia VARCHAR(150) NULL,
    TipoServicio VARCHAR(150) NULL,
    Servicio VARCHAR(150) NULL,
    idServicio INT NOT NULL
);
GO

CREATE TABLE dbo.DIM_SEGUIMIENTO(
    KeySeguimiento INT IDENTITY(1,1) PRIMARY KEY,
    TipoSeguimiento VARCHAR(150) NULL,
    Resultado VARCHAR(150) NULL,
    idSeguimientoBuyer INT NOT NULL
);
GO

CREATE TABLE dbo.DIM_INVESTIGACION(
    KeyInvestigacion INT IDENTITY(1,1) PRIMARY KEY,
    TipoInvestigacion VARCHAR(150) NULL,
    RangoAvance VARCHAR(150) NULL,
    EmpresaAplicacion VARCHAR(150) NULL,
    idDiagnostico INT NOT NULL
);
GO

CREATE TABLE dbo.DIM_ASESOR(
    KeyAsesor INT IDENTITY(1,1) PRIMARY KEY,
    Equipo VARCHAR(150) NULL,
    Rol VARCHAR(150) NULL,
    Especialidad VARCHAR(150) NULL,
    Asesor VARCHAR(150) NULL,
    idAsesor INT NOT NULL
);
GO

CREATE TABLE dbo.DIM_OBJECION(
    KeyObjecion INT IDENTITY(1,1) PRIMARY KEY,
    Grupo VARCHAR(150) NULL,
    Tipo VARCHAR(150) NULL,
    Estado VARCHAR(150) NULL,
    idObjecion INT NOT NULL
);
GO

CREATE TABLE dbo.DIM_ORIGEN_PROPUESTA(
    KeyOrigenPropuesta INT IDENTITY(1,1) PRIMARY KEY,
    GeneradaPor VARCHAR(150) NOT NULL
);
GO

CREATE TABLE dbo.DIM_MODALIDAD_PAGO(
    KeyModalidadPago INT IDENTITY(1,1) PRIMARY KEY,
    TipoModalidad VARCHAR(150) NULL,
    NumeroCuotas INT NULL,
    Condicion VARCHAR(150) NULL,
    idModalidadPago INT NOT NULL
);
GO

CREATE TABLE dbo.DIM_MEDIO_PAGO(
    KeyMedioPago INT IDENTITY(1,1) PRIMARY KEY,
    TipoMedio VARCHAR(150) NULL,
    Proveedor VARCHAR(150) NULL,
    MedioPago VARCHAR(150) NULL,
    idMedioPago INT NOT NULL
);
GO

CREATE TABLE dbo.DIM_PAGADOR(
    KeyPagador INT IDENTITY(1,1) PRIMARY KEY,
    Segmento VARCHAR(150) NULL,
    TipoResponsable VARCHAR(150) NULL,
    Relacion VARCHAR(150) NULL,
    idResponsablePago INT NOT NULL
);
GO

CREATE TABLE dbo.DIM_SESION(
    KeySesion INT IDENTITY(1,1) PRIMARY KEY,
    TipoSesion VARCHAR(150) NULL,
    Modalidad VARCHAR(150) NULL,
    EstadoSesion VARCHAR(150) NULL,
    idSesion INT NOT NULL
);
GO

CREATE TABLE dbo.DIM_HITO(
    KeyHito INT IDENTITY(1,1) PRIMARY KEY,
    TipoEntregable VARCHAR(150) NULL,
    Entregable VARCHAR(150) NULL,
    Capitulo VARCHAR(150) NULL,
    idHito INT NOT NULL
);
GO

CREATE TABLE dbo.DIM_MOTIVO_ESCALAMIENTO(
    KeyMotivoEscalamiento INT IDENTITY(1,1) PRIMARY KEY,
    Destino VARCHAR(150) NULL,
    Motivo VARCHAR(150) NULL
);
GO

CREATE TABLE dbo.DIM_INDICADOR(
    KeyIndicador INT IDENTITY(1,1) PRIMARY KEY,
    FaseIMPULSE VARCHAR(150) NULL,
    Indicador VARCHAR(150) NULL
);
GO

/* ============================================================================
MIEMBROS TÉCNICOS
============================================================================ */

SET IDENTITY_INSERT dbo.DIM_TIEMPO ON;
INSERT dbo.DIM_TIEMPO(KeyTiempo,Anio,Trimestre,NroMes,Mes,Semana,DiaSemana,Dia,idFecha)
VALUES (-1,1900,'DESCONOCIDO',1,'DESCONOCIDO',1,'DESCONOCIDO',1,'19000101'),
       ( 0,1900,'NO APLICA',1,'NO APLICA',1,'NO APLICA',2,'19000102');
SET IDENTITY_INSERT dbo.DIM_TIEMPO OFF;
GO

SET IDENTITY_INSERT dbo.DIM_ESTUDIANTE ON;
INSERT dbo.DIM_ESTUDIANTE(KeyEstudiante,Sede,EtapaAcademica,Ciclo,idPerfilAcademico)
VALUES (-1,'DESCONOCIDO','DESCONOCIDO','DESCONOCIDO',-1),
       ( 0,'NO APLICA','NO APLICA','NO APLICA',-2);
SET IDENTITY_INSERT dbo.DIM_ESTUDIANTE OFF;
GO

SET IDENTITY_INSERT dbo.DIM_CARRERA ON;
INSERT dbo.DIM_CARRERA(KeyCarrera,TipoUniversidad,Universidad,Facultad,Carrera,idCarrera)
VALUES (-1,'DESCONOCIDO','DESCONOCIDO','DESCONOCIDO','DESCONOCIDO',-1),
       ( 0,'NO APLICA','NO APLICA','NO APLICA','NO APLICA',-2);
SET IDENTITY_INSERT dbo.DIM_CARRERA OFF;
GO

SET IDENTITY_INSERT dbo.DIM_CANAL_CAPTACION ON;
INSERT dbo.DIM_CANAL_CAPTACION(KeyCanalCaptacion,TipoCanal,Plataforma,Canal,Campania,idCanal,idCampania)
VALUES (-1,'DESCONOCIDO','DESCONOCIDO','DESCONOCIDO','DESCONOCIDO',-1,-1),
       ( 0,'NO APLICA','NO APLICA','NO APLICA','NO APLICA',-2,-2);
SET IDENTITY_INSERT dbo.DIM_CANAL_CAPTACION OFF;
GO

SET IDENTITY_INSERT dbo.DIM_CONTENIDO ON;
INSERT dbo.DIM_CONTENIDO(KeyContenido,TipoContenido,Tema,Titulo,idContenido)
VALUES (-1,'DESCONOCIDO','DESCONOCIDO','DESCONOCIDO',-1),
       ( 0,'NO APLICA','NO APLICA','NO APLICA',-2);
SET IDENTITY_INSERT dbo.DIM_CONTENIDO OFF;
GO

SET IDENTITY_INSERT dbo.DIM_SERVICIO ON;
INSERT dbo.DIM_SERVICIO(KeyServicio,Familia,TipoServicio,Servicio,idServicio)
VALUES (-1,'DESCONOCIDO','DESCONOCIDO','DESCONOCIDO',-1),
       ( 0,'NO APLICA','NO APLICA','NO APLICA',-2);
SET IDENTITY_INSERT dbo.DIM_SERVICIO OFF;
GO

SET IDENTITY_INSERT dbo.DIM_SEGUIMIENTO ON;
INSERT dbo.DIM_SEGUIMIENTO(KeySeguimiento,TipoSeguimiento,Resultado,idSeguimientoBuyer)
VALUES (-1,'DESCONOCIDO','DESCONOCIDO',-1),
       ( 0,'NO APLICA','NO APLICA',-2);
SET IDENTITY_INSERT dbo.DIM_SEGUIMIENTO OFF;
GO

SET IDENTITY_INSERT dbo.DIM_INVESTIGACION ON;
INSERT dbo.DIM_INVESTIGACION(KeyInvestigacion,TipoInvestigacion,RangoAvance,EmpresaAplicacion,idDiagnostico)
VALUES (-1,'DESCONOCIDO','DESCONOCIDO','DESCONOCIDO',-1),
       ( 0,'NO APLICA','NO APLICA','NO APLICA',-2);
SET IDENTITY_INSERT dbo.DIM_INVESTIGACION OFF;
GO

SET IDENTITY_INSERT dbo.DIM_ASESOR ON;
INSERT dbo.DIM_ASESOR(KeyAsesor,Equipo,Rol,Especialidad,Asesor,idAsesor)
VALUES (-1,'DESCONOCIDO','DESCONOCIDO','DESCONOCIDO','DESCONOCIDO',-1),
       ( 0,'NO APLICA','NO APLICA','NO APLICA','SIN ASESOR / NO APLICA',-2);
SET IDENTITY_INSERT dbo.DIM_ASESOR OFF;
GO

SET IDENTITY_INSERT dbo.DIM_OBJECION ON;
INSERT dbo.DIM_OBJECION(KeyObjecion,Grupo,Tipo,Estado,idObjecion)
VALUES (-1,'DESCONOCIDO','DESCONOCIDO','DESCONOCIDO',-1),
       ( 0,'NO APLICA','NO APLICA','NO APLICA',-2);
SET IDENTITY_INSERT dbo.DIM_OBJECION OFF;
GO

SET IDENTITY_INSERT dbo.DIM_ORIGEN_PROPUESTA ON;
INSERT dbo.DIM_ORIGEN_PROPUESTA(KeyOrigenPropuesta,GeneradaPor)
VALUES (-1,'DESCONOCIDO'),
       ( 0,'NO APLICA');
SET IDENTITY_INSERT dbo.DIM_ORIGEN_PROPUESTA OFF;
GO

SET IDENTITY_INSERT dbo.DIM_MODALIDAD_PAGO ON;
INSERT dbo.DIM_MODALIDAD_PAGO(KeyModalidadPago,TipoModalidad,NumeroCuotas,Condicion,idModalidadPago)
VALUES (-1,'DESCONOCIDO',0,'DESCONOCIDO',-1),
       ( 0,'NO APLICA',0,'NO APLICA',-2);
SET IDENTITY_INSERT dbo.DIM_MODALIDAD_PAGO OFF;
GO

SET IDENTITY_INSERT dbo.DIM_MEDIO_PAGO ON;
INSERT dbo.DIM_MEDIO_PAGO(KeyMedioPago,TipoMedio,Proveedor,MedioPago,idMedioPago)
VALUES (-1,'DESCONOCIDO','DESCONOCIDO','DESCONOCIDO',-1),
       ( 0,'NO APLICA','NO APLICA','NO APLICA',-2);
SET IDENTITY_INSERT dbo.DIM_MEDIO_PAGO OFF;
GO

SET IDENTITY_INSERT dbo.DIM_PAGADOR ON;
INSERT dbo.DIM_PAGADOR(KeyPagador,Segmento,TipoResponsable,Relacion,idResponsablePago)
VALUES (-1,'DESCONOCIDO','DESCONOCIDO','DESCONOCIDO',-1),
       ( 0,'NO APLICA','NO APLICA','NO APLICA',-2);
SET IDENTITY_INSERT dbo.DIM_PAGADOR OFF;
GO

SET IDENTITY_INSERT dbo.DIM_SESION ON;
INSERT dbo.DIM_SESION(KeySesion,TipoSesion,Modalidad,EstadoSesion,idSesion)
VALUES (-1,'DESCONOCIDO','DESCONOCIDO','DESCONOCIDO',-1),
       ( 0,'NO APLICA','NO APLICA','NO APLICA',-2);
SET IDENTITY_INSERT dbo.DIM_SESION OFF;
GO

SET IDENTITY_INSERT dbo.DIM_HITO ON;
INSERT dbo.DIM_HITO(KeyHito,TipoEntregable,Entregable,Capitulo,idHito)
VALUES (-1,'DESCONOCIDO','DESCONOCIDO','DESCONOCIDO',-1),
       ( 0,'NO APLICA','NO APLICA','NO APLICA',-2);
SET IDENTITY_INSERT dbo.DIM_HITO OFF;
GO

SET IDENTITY_INSERT dbo.DIM_MOTIVO_ESCALAMIENTO ON;
INSERT dbo.DIM_MOTIVO_ESCALAMIENTO(KeyMotivoEscalamiento,Destino,Motivo)
VALUES (-1,'DESCONOCIDO','DESCONOCIDO'),
       ( 0,'NO APLICA','SIN ESCALAMIENTO');
SET IDENTITY_INSERT dbo.DIM_MOTIVO_ESCALAMIENTO OFF;
GO

SET IDENTITY_INSERT dbo.DIM_INDICADOR ON;
INSERT dbo.DIM_INDICADOR(KeyIndicador,FaseIMPULSE,Indicador)
VALUES (-1,'DESCONOCIDO','DESCONOCIDO'),
       ( 0,'NO APLICA','NO APLICA');
SET IDENTITY_INSERT dbo.DIM_INDICADOR OFF;
GO

/* ============================================================================
13 HECHOS
Sin PK artificial Fact...Key.
============================================================================ */

CREATE TABLE dbo.FACT_CAPTACION_BUYER(
    KeyTiempo INT NOT NULL REFERENCES dbo.DIM_TIEMPO(KeyTiempo),
    KeyEstudiante INT NOT NULL REFERENCES dbo.DIM_ESTUDIANTE(KeyEstudiante),
    KeyCarrera INT NOT NULL REFERENCES dbo.DIM_CARRERA(KeyCarrera),
    KeyCanalCaptacion INT NOT NULL REFERENCES dbo.DIM_CANAL_CAPTACION(KeyCanalCaptacion),
    KeyContenido INT NOT NULL REFERENCES dbo.DIM_CONTENIDO(KeyContenido),
    KeyServicio INT NOT NULL REFERENCES dbo.DIM_SERVICIO(KeyServicio),
    buyer_registrado INT NOT NULL DEFAULT 0,
    lead_generado INT NOT NULL DEFAULT 0,
    buyer_con_interaccion_valor INT NOT NULL DEFAULT 0,
    buyer_con_descarga INT NOT NULL DEFAULT 0,
    minutos_hasta_primera_interaccion DECIMAL(14,4) NULL,
    buyer_sin_cobertura INT NOT NULL DEFAULT 0
);
GO

CREATE TABLE dbo.FACT_SEGUIMIENTO_BUYER(
    KeyTiempo INT NOT NULL REFERENCES dbo.DIM_TIEMPO(KeyTiempo),
    KeyEstudiante INT NOT NULL REFERENCES dbo.DIM_ESTUDIANTE(KeyEstudiante),
    KeyCarrera INT NOT NULL REFERENCES dbo.DIM_CARRERA(KeyCarrera),
    KeySeguimiento INT NOT NULL REFERENCES dbo.DIM_SEGUIMIENTO(KeySeguimiento),
    buyer_inactivo_contactado INT NOT NULL DEFAULT 0,
    buyer_reactivado INT NOT NULL DEFAULT 0
);
GO

CREATE TABLE dbo.FACT_CAMPANIA(
    KeyTiempo INT NOT NULL REFERENCES dbo.DIM_TIEMPO(KeyTiempo),
    KeyCanalCaptacion INT NOT NULL REFERENCES dbo.DIM_CANAL_CAPTACION(KeyCanalCaptacion),
    inversion DECIMAL(14,4) NOT NULL DEFAULT 0,
    buyers_generados INT NOT NULL DEFAULT 0
);
GO

CREATE TABLE dbo.FACT_DIAGNOSTICO_LEAD(
    KeyTiempo INT NOT NULL REFERENCES dbo.DIM_TIEMPO(KeyTiempo),
    KeyEstudiante INT NOT NULL REFERENCES dbo.DIM_ESTUDIANTE(KeyEstudiante),
    KeyCarrera INT NOT NULL REFERENCES dbo.DIM_CARRERA(KeyCarrera),
    KeyInvestigacion INT NOT NULL REFERENCES dbo.DIM_INVESTIGACION(KeyInvestigacion),
    lead_solicita_diagnostico INT NOT NULL DEFAULT 0,
    perfil_completo INT NOT NULL DEFAULT 0,
    diagnostico_solicitado INT NOT NULL DEFAULT 0,
    diagnostico_48h INT NOT NULL DEFAULT 0,
    horas_diagnostico DECIMAL(14,4) NULL
);
GO

CREATE TABLE dbo.FACT_NEGOCIACION_LEAD(
    KeyTiempo INT NOT NULL REFERENCES dbo.DIM_TIEMPO(KeyTiempo),
    KeyEstudiante INT NOT NULL REFERENCES dbo.DIM_ESTUDIANTE(KeyEstudiante),
    KeyCarrera INT NOT NULL REFERENCES dbo.DIM_CARRERA(KeyCarrera),
    KeyServicio INT NOT NULL REFERENCES dbo.DIM_SERVICIO(KeyServicio),
    KeyAsesor INT NOT NULL REFERENCES dbo.DIM_ASESOR(KeyAsesor),
    KeyOrigenPropuesta INT NOT NULL REFERENCES dbo.DIM_ORIGEN_PROPUESTA(KeyOrigenPropuesta),
    KeyCanalCaptacion INT NOT NULL REFERENCES dbo.DIM_CANAL_CAPTACION(KeyCanalCaptacion),
    lead_con_propuesta INT NOT NULL DEFAULT 0,
    lead_con_propuesta_aceptada INT NOT NULL DEFAULT 0,
    horas_hasta_aceptacion DECIMAL(14,4) NULL,
    horas_hasta_primera_propuesta DECIMAL(14,4) NULL,
    lead_cohorte INT NOT NULL DEFAULT 0,
    payer_generado INT NOT NULL DEFAULT 0,
    monto_descuento DECIMAL(14,4) NOT NULL DEFAULT 0,
    precio_base DECIMAL(14,4) NOT NULL DEFAULT 0,
    propuesta_en_minimo INT NOT NULL DEFAULT 0,
    propuesta_aceptada INT NOT NULL DEFAULT 0
);
GO

CREATE TABLE dbo.FACT_OBJECION_LEAD(
    KeyTiempo INT NOT NULL REFERENCES dbo.DIM_TIEMPO(KeyTiempo),
    KeyObjecion INT NOT NULL REFERENCES dbo.DIM_OBJECION(KeyObjecion),
    KeyServicio INT NOT NULL REFERENCES dbo.DIM_SERVICIO(KeyServicio),
    KeyAsesor INT NOT NULL REFERENCES dbo.DIM_ASESOR(KeyAsesor),
    lead_con_objecion INT NOT NULL DEFAULT 0,
    lead_recuperado INT NOT NULL DEFAULT 0,
    lead_objecion_escalada INT NOT NULL DEFAULT 0
);
GO

CREATE TABLE dbo.FACT_COBRANZA(
    KeyTiempo INT NOT NULL REFERENCES dbo.DIM_TIEMPO(KeyTiempo),
    KeyServicio INT NOT NULL REFERENCES dbo.DIM_SERVICIO(KeyServicio),
    KeyModalidadPago INT NOT NULL REFERENCES dbo.DIM_MODALIDAD_PAGO(KeyModalidadPago),
    KeyPagador INT NOT NULL REFERENCES dbo.DIM_PAGADOR(KeyPagador),
    orden_creada INT NOT NULL DEFAULT 0,
    orden_con_pago INT NOT NULL DEFAULT 0,
    minutos_a_primer_pago DECIMAL(14,4) NULL,
    pendiente_alertado INT NOT NULL DEFAULT 0,
    pendiente_recuperado INT NOT NULL DEFAULT 0,
    monto_exigible DECIMAL(14,4) NOT NULL DEFAULT 0,
    monto_cobrado DECIMAL(14,4) NOT NULL DEFAULT 0
);
GO

CREATE TABLE dbo.FACT_PAGO(
    KeyTiempo INT NOT NULL REFERENCES dbo.DIM_TIEMPO(KeyTiempo),
    KeyServicio INT NOT NULL REFERENCES dbo.DIM_SERVICIO(KeyServicio),
    KeyModalidadPago INT NOT NULL REFERENCES dbo.DIM_MODALIDAD_PAGO(KeyModalidadPago),
    KeyMedioPago INT NOT NULL REFERENCES dbo.DIM_MEDIO_PAGO(KeyMedioPago),
    pago_por_webhook INT NOT NULL DEFAULT 0,
    pago_confirmado INT NOT NULL DEFAULT 0,
    comision_pasarela DECIMAL(14,4) NOT NULL DEFAULT 0,
    monto_pagado DECIMAL(14,4) NOT NULL DEFAULT 0
);
GO

CREATE TABLE dbo.FACT_CUSTOMER_SERVICIO(
    KeyTiempo INT NOT NULL REFERENCES dbo.DIM_TIEMPO(KeyTiempo),
    KeyEstudiante INT NOT NULL REFERENCES dbo.DIM_ESTUDIANTE(KeyEstudiante),
    KeyCarrera INT NOT NULL REFERENCES dbo.DIM_CARRERA(KeyCarrera),
    KeyServicio INT NOT NULL REFERENCES dbo.DIM_SERVICIO(KeyServicio),
    KeyAsesor INT NOT NULL REFERENCES dbo.DIM_ASESOR(KeyAsesor),
    customer_activado INT NOT NULL DEFAULT 0,
    asignacion_24h INT NOT NULL DEFAULT 0,
    horas_asignacion DECIMAL(14,4) NULL,
    primera_sesion_48h INT NOT NULL DEFAULT 0,
    encuesta_respondida INT NOT NULL DEFAULT 0,
    puntaje_satisfaccion DECIMAL(14,4) NOT NULL DEFAULT 0,
    ingresos DECIMAL(14,4) NOT NULL DEFAULT 0,
    comision_pasarela DECIMAL(14,4) NOT NULL DEFAULT 0,
    honorarios DECIMAL(14,4) NOT NULL DEFAULT 0,
    costo_turnitin DECIMAL(14,4) NOT NULL DEFAULT 0,
    margen DECIMAL(14,4) NOT NULL DEFAULT 0
);
GO

CREATE TABLE dbo.FACT_SESION(
    KeyTiempo INT NOT NULL REFERENCES dbo.DIM_TIEMPO(KeyTiempo),
    KeyEstudiante INT NOT NULL REFERENCES dbo.DIM_ESTUDIANTE(KeyEstudiante),
    KeyCarrera INT NOT NULL REFERENCES dbo.DIM_CARRERA(KeyCarrera),
    KeyServicio INT NOT NULL REFERENCES dbo.DIM_SERVICIO(KeyServicio),
    KeyAsesor INT NOT NULL REFERENCES dbo.DIM_ASESOR(KeyAsesor),
    KeySesion INT NOT NULL REFERENCES dbo.DIM_SESION(KeySesion),
    sesion_programada INT NOT NULL DEFAULT 0,
    sesion_reprogramada INT NOT NULL DEFAULT 0
);
GO

CREATE TABLE dbo.FACT_HITO_CALIDAD(
    KeyTiempo INT NOT NULL REFERENCES dbo.DIM_TIEMPO(KeyTiempo),
    KeyEstudiante INT NOT NULL REFERENCES dbo.DIM_ESTUDIANTE(KeyEstudiante),
    KeyCarrera INT NOT NULL REFERENCES dbo.DIM_CARRERA(KeyCarrera),
    KeyServicio INT NOT NULL REFERENCES dbo.DIM_SERVICIO(KeyServicio),
    KeyAsesor INT NOT NULL REFERENCES dbo.DIM_ASESOR(KeyAsesor),
    KeyHito INT NOT NULL REFERENCES dbo.DIM_HITO(KeyHito),
    hito_evaluado INT NOT NULL DEFAULT 0,
    hito_a_tiempo INT NOT NULL DEFAULT 0,
    dias_desviacion DECIMAL(14,4) NULL,
    reporte_emitido INT NOT NULL DEFAULT 0,
    reporte_cumple_umbral INT NOT NULL DEFAULT 0,
    dias_levantamiento DECIMAL(14,4) NULL,
    observacion_levantada INT NOT NULL DEFAULT 0,
    ronda_extra INT NOT NULL DEFAULT 0,
    observacion_recibida INT NOT NULL DEFAULT 0
);
GO

CREATE TABLE dbo.FACT_CONVERSACION(
    KeyTiempo INT NOT NULL REFERENCES dbo.DIM_TIEMPO(KeyTiempo),
    KeyEstudiante INT NOT NULL REFERENCES dbo.DIM_ESTUDIANTE(KeyEstudiante),
    KeyCarrera INT NOT NULL REFERENCES dbo.DIM_CARRERA(KeyCarrera),
    KeyCanalCaptacion INT NOT NULL REFERENCES dbo.DIM_CANAL_CAPTACION(KeyCanalCaptacion),
    KeyMotivoEscalamiento INT NOT NULL REFERENCES dbo.DIM_MOTIVO_ESCALAMIENTO(KeyMotivoEscalamiento),
    conversacion_iniciada INT NOT NULL DEFAULT 0,
    segundos_primera_respuesta DECIMAL(14,4) NULL,
    conversacion_resuelta_sin_humano INT NOT NULL DEFAULT 0,
    conversacion_escalada INT NOT NULL DEFAULT 0,
    escalamiento INT NOT NULL DEFAULT 0,
    escalamiento_atendido INT NOT NULL DEFAULT 0,
    minutos_hasta_atencion DECIMAL(14,4) NULL
);
GO

CREATE TABLE dbo.FACT_META(
    KeyTiempo INT NOT NULL REFERENCES dbo.DIM_TIEMPO(KeyTiempo),
    KeyIndicador INT NOT NULL REFERENCES dbo.DIM_INDICADOR(KeyIndicador),
    KeyCarrera INT NOT NULL REFERENCES dbo.DIM_CARRERA(KeyCarrera),
    valor_meta DECIMAL(14,4) NOT NULL DEFAULT 0,
    valor_real DECIMAL(14,4) NOT NULL DEFAULT 0
);
GO

PRINT 'INBESTIGA_MART creado correctamente: 18 dimensiones + 13 hechos.';
GO
