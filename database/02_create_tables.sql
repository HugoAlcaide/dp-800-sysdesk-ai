/* =========================================================================
   DESCRIPCIÓN: Diseño y creación del modelo relacional, JSON y vectorial (DDL):
                1. Tabla dbo.usuarios: Catálogo de personal, roles y departamentos.
                2. Tabla dbo.sistemas: Inventario de activos TI, criticidad y objetivos SLA.
                3. Tabla dbo.kb_articulos: Base de conocimiento con columna nativa VECTOR(384).
                4. Tabla dbo.tickets: Registro transaccional con telemetría nativa JSON.
                5. Tabla dbo.auditoria_rag: Trazabilidad y observabilidad de consultas IA.
   ========================================================================= */
USE [SysDeskAI];
GO

-- 1. TABLA: dbo.usuarios
CREATE TABLE dbo.usuarios (
    usuario_id INT IDENTITY(1,1) NOT NULL,
    username NVARCHAR(50) NOT NULL,
    nombre_completo NVARCHAR(120) NOT NULL,
    email VARCHAR(150) NOT NULL,
    rol VARCHAR(20) NOT NULL,
    departamento VARCHAR(40) NOT NULL,
    activo BIT NOT NULL CONSTRAINT DF_usuarios_activo DEFAULT (1),
    fecha_registro DATETIME2(0) NOT NULL CONSTRAINT DF_usuarios_fecha DEFAULT (SYSDATETIME()),
    
    CONSTRAINT PK_usuarios PRIMARY KEY CLUSTERED (usuario_id),
    CONSTRAINT UQ_usuarios_username UNIQUE (username),
    CONSTRAINT UQ_usuarios_email UNIQUE (email),
    CONSTRAINT CK_usuarios_rol CHECK (rol IN ('Admin', 'TecnicoTier1', 'TecnicoTier2', 'UsuarioFinal')),
    CONSTRAINT CK_usuarios_departamento CHECK (departamento IN ('Infraestructura', 'BaseDeDatos', 'Redes', 'Seguridad', 'Finanzas', 'RRHH', 'General')),
    CONSTRAINT CK_usuarios_email_formato CHECK (email LIKE '%_@__%.__%')
);
GO

-- 2. TABLA: dbo.sistemas
CREATE TABLE dbo.sistemas (
    sistema_id INT IDENTITY(1,1) NOT NULL,
    codigo_sistema VARCHAR(20) NOT NULL,
    nombre_sistema NVARCHAR(100) NOT NULL,
    categoria VARCHAR(40) NOT NULL,
    ip_servidor VARCHAR(15) NOT NULL,
    criticidad VARCHAR(15) NOT NULL,
    sla_horas_objetivo INT NOT NULL,
    
    CONSTRAINT PK_sistemas PRIMARY KEY CLUSTERED (sistema_id),
    CONSTRAINT UQ_sistemas_codigo UNIQUE (codigo_sistema),
    CONSTRAINT CK_sistemas_categoria CHECK (categoria IN ('Infraestructura', 'BaseDeDatos', 'Redes', 'Seguridad', 'Finanzas', 'RRHH')),
    CONSTRAINT CK_sistemas_criticidad CHECK (criticidad IN ('Baja', 'Media', 'Alta', 'Critica')),
    CONSTRAINT CK_sistemas_sla CHECK (sla_horas_objetivo BETWEEN 1 AND 168)
);
GO

-- 3. TABLA: dbo.kb_articulos (Base de Conocimiento con columna VECTOR nativa)
CREATE TABLE dbo.kb_articulos (
    articulo_id INT IDENTITY(1,1) NOT NULL,
    codigo_error VARCHAR(30) NOT NULL,
    sistema_id INT NOT NULL,
    titulo NVARCHAR(200) NOT NULL,
    sintomas NVARCHAR(1000) NOT NULL,
    procedimiento_resolucion NVARCHAR(MAX) NOT NULL,
    autor_id INT NOT NULL,
    fecha_actualizacion DATETIME2(0) NOT NULL CONSTRAINT DF_kb_fecha DEFAULT (SYSDATETIME()),
    contenido_embedding VECTOR(384) NULL, -- Vector nativo de 384 dimensiones (modelos locales ONNX/Ollama)
    
    CONSTRAINT PK_kb_articulos PRIMARY KEY CLUSTERED (articulo_id),
    CONSTRAINT UQ_kb_codigo_error UNIQUE (codigo_error),
    CONSTRAINT FK_kb_sistemas FOREIGN KEY (sistema_id) REFERENCES dbo.sistemas (sistema_id),
    CONSTRAINT FK_kb_autor FOREIGN KEY (autor_id) REFERENCES dbo.usuarios (usuario_id)
);
GO

-- 4. TABLA: dbo.tickets (Transaccional de incidencias con columna JSON nativa)
CREATE TABLE dbo.tickets (
    ticket_id INT IDENTITY(1000,1) NOT NULL,
    usuario_reporta_id INT NOT NULL,
    tecnico_asignado_id INT NULL,
    sistema_id INT NOT NULL,
    departamento_responsable VARCHAR(40) NOT NULL,
    titulo NVARCHAR(200) NOT NULL,
    descripcion_usuario NVARCHAR(2000) NOT NULL,
    severidad TINYINT NOT NULL, -- 1: Crítica, 2: Alta, 3: Media, 4: Baja
    estado VARCHAR(20) NOT NULL CONSTRAINT DF_tickets_estado DEFAULT ('Abierto'),
    fecha_apertura DATETIME2(0) NOT NULL CONSTRAINT DF_tickets_apertura DEFAULT (SYSDATETIME()),
    fecha_resolucion DATETIME2(0) NULL,
    articulo_kb_aplicado_id INT NULL,
    metadatos_diagnostico JSON NULL, -- Tipo nativo JSON de SQL Server 2025 para telemetría
    
    CONSTRAINT PK_tickets PRIMARY KEY CLUSTERED (ticket_id),
    CONSTRAINT FK_tickets_reporta FOREIGN KEY (usuario_reporta_id) REFERENCES dbo.usuarios (usuario_id),
    CONSTRAINT FK_tickets_tecnico FOREIGN KEY (tecnico_asignado_id) REFERENCES dbo.usuarios (usuario_id),
    CONSTRAINT FK_tickets_sistema FOREIGN KEY (sistema_id) REFERENCES dbo.sistemas (sistema_id),
    CONSTRAINT FK_tickets_kb FOREIGN KEY (articulo_kb_aplicado_id) REFERENCES dbo.kb_articulos (articulo_id),
    CONSTRAINT CK_tickets_severidad CHECK (severidad BETWEEN 1 AND 4),
    CONSTRAINT CK_tickets_estado CHECK (estado IN ('Abierto', 'En Proceso', 'Resuelto', 'Cerrado')),
    CONSTRAINT CK_tickets_departamento CHECK (departamento_responsable IN ('Infraestructura', 'BaseDeDatos', 'Redes', 'Seguridad', 'Finanzas', 'RRHH')),
    CONSTRAINT CK_tickets_fechas CHECK (fecha_resolucion IS NULL OR fecha_resolucion >= fecha_apertura)
);
GO

-- 5. TABLA: dbo.auditoria_rag (Trazabilidad y observabilidad de consultas IA)
CREATE TABLE dbo.auditoria_rag (
    auditoria_id INT IDENTITY(1,1) NOT NULL,
    usuario_consulta_id INT NOT NULL,
    fecha_consulta DATETIME2(0) NOT NULL CONSTRAINT DF_auditoria_fecha DEFAULT (SYSDATETIME()),
    pregunta_usuario NVARCHAR(1000) NOT NULL,
    articulo_recuperado_id INT NULL,
    distancia_coseno FLOAT NULL,
    contexto_enviado NVARCHAR(MAX) NULL,
    respuesta_llm NVARCHAR(MAX) NOT NULL,
    tiempo_respuesta_ms INT NOT NULL,
    
    CONSTRAINT PK_auditoria_rag PRIMARY KEY CLUSTERED (auditoria_id),
    CONSTRAINT FK_auditoria_usuario FOREIGN KEY (usuario_consulta_id) REFERENCES dbo.usuarios (usuario_id),
    CONSTRAINT FK_auditoria_articulo FOREIGN KEY (articulo_recuperado_id) REFERENCES dbo.kb_articulos (articulo_id),
    CONSTRAINT CK_auditoria_distancia CHECK (distancia_coseno IS NULL OR (distancia_coseno >= 0.0 AND distancia_coseno <= 2.0)),
    CONSTRAINT CK_auditoria_tiempo CHECK (tiempo_respuesta_ms >= 0)
);
GO