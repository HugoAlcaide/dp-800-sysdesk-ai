/* =========================================================================
   DESCRIPCIÓN: Carga inicial de datos maestros y transaccionales (DML Seed Data):
                1. Población de usuarios corporativos (Admins, Técnicos Tier 1/2 y Usuarios).
                2. Registro de sistemas críticos (SQL 2025, VPN FortiGate, AD, SAP, K8s, Workday).
                3. Inserción de artículos técnicos de resolución en la Base de Conocimiento (KB).
                4. Generación de tickets históricos y activos con telemetría en formato JSON.
   ========================================================================= */
USE [SysDeskAI];
GO

SET NOCOUNT ON;

-- 1. Insertar Usuarios (Admins, Técnicos por departamento y Usuarios finales)
INSERT INTO dbo.usuarios (username, nombre_completo, email, rol, departamento) VALUES
(N'halcaide', N'Hugo Alcaide Martínez', 'hugo.alcaide@sysdesk.corp', 'Admin', 'Infraestructura'),
(N'cmartinez', N'Carlos Martínez Ruiz', 'carlos.martinez@sysdesk.corp', 'TecnicoTier2', 'BaseDeDatos'),
(N'lgomez', N'Laura Gómez Pérez', 'laura.gomez@sysdesk.corp', 'TecnicoTier1', 'Redes'),
(N'dfernandez', N'David Fernández Gil', 'david.fernandez@sysdesk.corp', 'TecnicoTier2', 'Seguridad'),
(N'asanz', N'Ana Sanz López', 'ana.sanz@sysdesk.corp', 'TecnicoTier1', 'Finanzas'),
(N'mrodriguez', N'Marta Rodríguez Soler', 'marta.rodriguez@sysdesk.corp', 'UsuarioFinal', 'General'),
(N'jperez', N'Javier Pérez Cano', 'javier.perez@sysdesk.corp', 'UsuarioFinal', 'General'),
(N'elopez', N'Elena López Díaz', 'elena.lopez@sysdesk.corp', 'UsuarioFinal', 'RRHH');
GO

-- 2. Insertar Sistemas Corporativos
INSERT INTO dbo.sistemas (codigo_sistema, nombre_sistema, categoria, ip_servidor, criticidad, sla_horas_objetivo) VALUES
('SYS-SQL-01', N'Clúster Microsoft SQL Server 2025 Producción', 'BaseDeDatos', '10.20.10.15', 'Critica', 2),
('SYS-NET-01', N'Concentrador VPN Corporativa FortiGate', 'Redes', '10.20.1.254', 'Alta', 4),
('SYS-SEC-01', N'Controlador de Dominio Active Directory / Entra ID', 'Seguridad', '10.20.5.10', 'Critica', 2),
('SYS-FIN-01', N'ERP Financiero SAP S/4HANA', 'Finanzas', '10.20.30.50', 'Alta', 6),
('SYS-INF-01', N'Granja de Servidores Kubernetes On-Premise', 'Infraestructura', '10.20.40.100', 'Critica', 3),
('SYS-RRHH-01', N'Portal del Empleado y Nóminas Workday', 'RRHH', '10.20.60.22', 'Media', 24);
GO

-- 3. Insertar Artículos de Base de Conocimiento (KB)
-- Nota: Los vectores se poblarán en el Bloque E mediante el modelo de embeddings
INSERT INTO dbo.kb_articulos (codigo_error, sistema_id, titulo, sintomas, procedimiento_resolucion, autor_id) VALUES
('ERR-SQL-18456', 1, N'Excepción de login 18456 por desajuste en modo de autenticación mixta',
 N'El usuario no puede entrar a la base de datos, recibe error 18456 State 58 o mensaje de credenciales rechazadas al conectar desde SSMS o la aplicación.',
 N'1. Abrir SSMS como administrador. 2. Ir a Propiedades del Servidor -> Seguridad. 3. Cambiar de Autenticación de Windows a Modo Mixto (SQL Server y Windows). 4. Reiniciar el servicio MSSQLSERVER y verificar que el login tenga estado ENABLED.', 2),

('ERR-SQL-1205', 1, N'Interbloqueo (Deadlock) de transacciones concurrentes en cierre contable',
 N'Las consultas se quedan congeladas y el sistema aborta la operación indicando que el proceso fue elegido como víctima de interbloqueo (Error 1205).',
 N'1. Capturar el grafo XML del deadlock en el evento extendido system_health. 2. Asegurar que los procedimientos accedan a las tablas en el mismo orden. 3. Evaluar la activación de READ_COMMITTED_SNAPSHOT (RCSI) para evitar bloqueos entre lecturas y escrituras.', 2),

('ERR-NET-VPN809', 2, N'Fallo de conexión VPN IPSec por bloqueo de puertos UDP 500 y 4500',
 N'Al teletrabajar desde casa o red externa, la VPN se queda intentando conectar infinitamente y falla sin pedir el segundo factor.',
 N'1. Comprobar conectividad UDP hacia los puertos 500 y 4500 del concentrador. 2. Ejecutar en PowerShell: New-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\PolicyAgent -Name AssumeUDPEncapsulationContextOnSendRule -Value 2. 3. Reiniciar el equipo.', 3),

('ERR-SEC-AD4740', 3, N'Bloqueo recurrente de cuenta de dominio por credenciales cacheadas tras cambio de clave',
 N'La pantalla se queda bloqueada al intentar autenticarme en Windows o salta aviso de cuenta bloqueada cada 15 minutos después de cambiar la contraseña.',
 N'1. Abrir el Administrador de Credenciales de Windows en el equipo del usuario y borrar entradas antiguas de red. 2. Cerrar sesiones RDP huérfanas en servidores. 3. Desbloquear la cuenta en Active Directory Users and Computers (Unlock Account).', 4),

('ERR-FIN-SAP500', 4, N'Timeout de pasarela RFC al exportar el balance trimestral a Excel',
 N'El programa de contabilidad da pantallazo de tiempo de espera agotado cuando intento descargar el listado grande de facturas del trimestre.',
 N'1. Acceder a la transacción SMGW para verificar procesos activos. 2. Incrementar el parámetro rdisp/max_wprun_time a 1800 segundos para ejecuciones de cierre. 3. Recomendar al usuario lanzar el reporte en modo background (Job SM37).', 5),

('ERR-INF-OOM137', 5, N'Reinicio abrupto de contenedor con código Exit 137 por límite de memoria (OOMKilled)',
 N'El microservicio web se cae solo a mitad de mañana cuando entra mucha gente y devuelve error 502 Bad Gateway.',
 N'1. Inspeccionar el pod con kubectl describe pod para confirmar estado OOMKilled. 2. Incrementar limits.memory en el manifiesto YAML de despliegue de 512Mi a 2Gi. 3. Configurar JVM MaxRAMPercentage al 75% para evitar desbordamiento del contenedor.', 1);
GO

-- 4. Insertar Tickets de Soporte (Históricos y Activos con JSON nativo)
INSERT INTO dbo.tickets (
    usuario_reporta_id, tecnico_asignado_id, sistema_id, departamento_responsable,
    titulo, descripcion_usuario, severidad, estado, fecha_apertura, fecha_resolucion,
    articulo_kb_aplicado_id, metadatos_diagnostico
) VALUES
(6, 2, 1, 'BaseDeDatos', N'No me deja entrar al servidor de datos con mi usuario SQL',
 N'Intento entrar a la base de datos de informes pero me sale error de login y me rechaza la clave aunque está bien escrita.',
 1, 'Resuelto', DATEADD(HOUR, -10, SYSDATETIME()), DATEADD(HOUR, -9, SYSDATETIME()), 1,
 '{"host":"PC-MARTA-09","os":"Windows 11","error_code":18456,"client":"SSMS 22","cpu_pct":14}'),

(7, 3, 2, 'Redes', N'Desde casa no me engancha la VPN de la empresa',
 N'Estoy intentando teletrabajar y el cliente de conexión se queda dando vueltas hasta que dice que el servidor remoto no responde.',
 2, 'Resuelto', DATEADD(HOUR, -24, SYSDATETIME()), DATEADD(HOUR, -21, SYSDATETIME()), 3,
 '{"host":"LAPTOP-JAVI","os":"Windows 11","error_code":809,"isp":"Movistar","wifi_signal":"Good"}'),

(6, 4, 3, 'Seguridad', N'La pantalla se queda bloqueada al intentar autenticarme',
 N'Cambié la contraseña ayer por la mañana y hoy cada pocos minutos me dice que mi usuario está bloqueado y no puedo entrar al correo.',
 1, 'En Proceso', DATEADD(HOUR, -2, SYSDATETIME()), NULL, NULL,
 '{"host":"PC-MARTA-09","os":"Windows 11","ad_event":4740,"failed_attempts":5}'),

(8, 5, 4, 'Finanzas', N'Se cuelga el programa al sacar las facturas del trimestre',
 N'Cuando le doy a exportar el libro de IVA se queda pensando cinco minutos y me tira un error de pasarela agotada.',
 2, 'Abierto', DATEADD(HOUR, -5, SYSDATETIME()), NULL, NULL,
 '{"host":"PC-ELENA-FIN","os":"Windows 11","sap_tx":"FBL1N","memory_mb":4096}'),

(7, 2, 1, 'BaseDeDatos', N'Se abortan los cierres de inventario con fallo de bloqueo',
 N'Al lanzar la consolidación de almacén a la vez que facturación me salta un cartel de que mi proceso fue víctima de bloqueo.',
 1, 'Resuelto', DATEADD(HOUR, -48, SYSDATETIME()), DATEADD(HOUR, -44, SYSDATETIME()), 2,
 '{"host":"SRV-APP-02","os":"Windows Server 2025","error_code":1205,"isolation_level":"READ_COMMITTED"}'),

(8, 1, 5, 'Infraestructura', N'La web interna da error 502 cuando hay picos de tráfico',
 N'A las 11 de la mañana el portal deja de responder durante un par de minutos y parece que el servidor se reinicia solo.',
 1, 'En Proceso', DATEADD(HOUR, -4, SYSDATETIME()), NULL, NULL,
 '{"cluster":"k8s-prod-mad","pod":"portal-api-7f8b9","exit_code":137,"ram_usage_mb":512}');
GO