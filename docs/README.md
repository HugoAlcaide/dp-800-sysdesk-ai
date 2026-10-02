# SysDesk AI: Sistema Inteligente de Soporte Técnico, Búsqueda Semántica y Asistencia RAG sobre Microsoft SQL Server 2025

**Documento:** Propuesta Técnica de Proyecto y Memoria Conceptual  
**Alineación Profesional:** Certificación Microsoft DP-800: SQL AI Developer Associate  
**Autor:** Hugo Alcaide Martínez  
**Entorno Tecnológico:** Microsoft SQL Server 2025 (Compatibilidad 170) | SSMS 22 | Modelos Locales de Inteligencia Artificial (Ollama)  
**Fecha:** Octubre 2026  
**Documento PDF Asociado:** [`docs/SysDesk_AI_Propuesta_Tecnica_DP-800.pdf`](SysDesk_AI_Propuesta_Tecnica_DP800.pdf)

---

## 1. Resumen Ejecutivo y Visión General

En el tejido empresarial contemporáneo, los departamentos de soporte de tecnologías de la información (ITSM) se enfrentan a un desafío recurrente: la saturación provocada por incidencias repetitivas, tiempos prolongados de diagnóstico y la pérdida silenciosa de conocimiento técnico. A medida que las organizaciones crecen, el volumen de manuales, procedimientos y registros históricos de errores se vuelve inabarcable para los operadores de soporte, reduciendo la agilidad del servicio.

Los buscadores clásicos dentro de las aplicaciones empresariales dependen de la coincidencia literal de palabras clave. Si un usuario reporta un incidente utilizando lenguaje coloquial, estos motores son incapaces de asociar el problema con la documentación oficial elaborada por ingenieros de sistemas. Esto genera una brecha comunicativa que deriva en duplicidad de esfuerzos, resolución inconsistente de problemas y frustración operativa.

**SysDesk AI** nace como una propuesta integral para modernizar este paradigma combinando la robustez de **Microsoft SQL Server 2025** con capacidades de **inteligencia artificial ejecutada localmente**. La solución transforma la base de datos corporativa en un motor activo de búsqueda semántica y recuperación de conocimiento mediante tres ejes:
1. **Comprensión Conceptual:** Búsqueda basada en el significado real de las incidencias en lugar de palabras aisladas.
2. **Generación Asistida Verificada (RAG):** Respuestas automatizadas redactadas por modelos de lenguaje anclados estrictamente en manuales internos aprobados, erradicando alucinaciones.
3. **Seguridad y Privacidad por Diseño:** Blindaje de datos confidenciales y soberanía total sin transferir información sensible a nubes públicas externas.

<div style="page-break-before: always;"></div>

## 2. Diagnóstico del Escenario: El "Antes" frente al "Después"

El propósito de SysDesk AI es subsanar ineficiencias del modelo tradicional de soporte mediante la incorporación de capacidades analíticas avanzadas en la capa de datos.

### El Escenario Tradicional (El "ANTES")
* **Rigidez Léxica en la Búsqueda:** Si un usuario reporta *"la pantalla se queda bloqueada al intentar autenticarme"*, un motor convencional busca esa cadena de texto literal. Si la solución registrada por infraestructura se titula *"Excepción de login 18456 por desajuste en autenticación mixta"*, el sistema devuelve cero coincidencias.
* **Exposición y Brechas de Privacidad:** Todos los técnicos visualizan la totalidad de los campos del ticket, dejando expuestas credenciales temporales, correos personales e información crítica de red (direcciones IP internas y nombres de servidores).
* **Fuga de Información hacia IAs Públicas (*Shadow AI*):** Ante la dificultad de hallar soluciones rápidas, los operadores copian los errores internos y los pegan en herramientas públicas en la nube (como ChatGPT), exponiendo registros corporativos en servidores externos.
* **Falta de Segmentación por Departamentos:** Los técnicos de soporte general pueden acceder a incidencias confidenciales pertenecientes a finanzas, recursos humanos o ciberseguridad, vulnerando normativas de cumplimiento.
* **Degradación Progresiva del Servidor:** Con el aumento de decenas de miles de tickets históricos, la generación de reportes y la consulta diaria colapsan la memoria del servidor debido a revisiones exhaustivas de tablas completas.

---

### La Solución Propuesta con SysDesk AI (El "DESPUÉS")
* **Búsqueda Semántica por Similitud de Ideas:** SQL Server 2025 compara conceptos matemáticos multidimensionales. El sistema comprende de inmediato que *"bloqueo de acceso al validar"* y *"fallo de login 18456"* describen el mismo problema funcional.
* **Enmascaramiento Dinámico Automático:** La base de datos oculta selectivamente fragmentos de correos (`j***@empresa.com`) y segmentos de direcciones IP (`192.xxx.xxx.`) según el rol del usuario, sin alterar el almacenamiento original.
* **Inteligencia Artificial Privada y Confiable (RAG Local):** La respuesta es sintetizada por un modelo de lenguaje que corre en el servidor local. El modelo utiliza únicamente la documentación aprobada recuperada de la base de datos, garantizando respuestas ciertas y manteniendo los datos dentro de la organización.
* **Aislamiento Nativo por Áreas:** Reglas automáticas en el motor de base de datos garantizan que cada técnico consulte únicamente los tickets correspondientes a su especialidad, manteniendo visibilidad global solo para supervisores.
* **Rendimiento Inmediato en Consultas Críticas:** Se aplican estrategias de acceso directo a los datos, permitiendo resolver reportes históricos en milisegundos sin sobrecargar el servidor.

---

### Matriz Comparativa Operativa

| Variable de Evaluación | Sistema de Soporte Tradicional | SysDesk AI sobre SQL Server 2025 |
| :--- | :--- | :--- |
| **Criterio de Búsqueda** | Coincidencia exacta de caracteres (`LIKE`). | Similitud semántica y proximidad conceptual. |
| **Tolerancia al Lenguaje Coloquial** | Nula (requiere conocer la jerga técnica exacta). | Total (interpreta sinónimos, descripciones y códigos). |
| **Tiempo de Redacción de Solución** | Lectura y análisis manual de extensos manuales. | Asistente inteligente que resume el procedimiento en segundos. |
| **Soberanía y Coste de la IA** | Suscripciones cloud con riesgo de fuga de datos. | 100% local (coste recurrente cero y privacidad total). |
| **Seguridad de Datos Sensibles** | Delegada a la interfaz web (vulnerable a descuidos). | Integrada a nivel de motor de base de datos (infranqueable). |
| **Rendimiento ante Grandes Volúmenes** | Escaneo secuencial lento y pesado. | Búsqueda por índices específicos de alto rendimiento. |

<div style="page-break-before: always;"></div>

## 3. Arquitectura Conceptual y Diseño del Modelo de Datos

La arquitectura de SysDesk AI está concebida bajo el principio de **ejecución local soberana**, asegurando que ni las consultas de los usuarios ni los manuales técnicos requieran conectividad externa ni servicios de pago.

### Flujo Operativo de la Solución
1. **Entrada de la Consulta:** El usuario o técnico describe el problema en lenguaje coloquial desde la consola de soporte.
2. **Generación de Coordenadas Semánticas:** El texto es transformado localmente en un vector denso de 384 dimensiones mediante un modelo de embeddings ejecutado en el mismo host.
3. **Búsqueda Vectorial y Filtrado de Seguridad (SQL Server 2025):** El motor relacional calcula la distancia coseno frente a los artículos de conocimiento (`VECTOR_DISTANCE`), descarta documentos ajenos al departamento del técnico mediante Row-Level Security y enmascara datos sensibles.
4. **Construcción del Contexto RAG y Síntesis:** Las dos soluciones más relevantes se inyectan en un prompt restringido hacia un modelo de lenguaje local (Ollama / SLM), que redacta la solución paso a paso garantizando veracidad absoluta.

---

### Especificación del Modelo de Datos Relacional y Vectorial

El sistema estructura la información en un modelo normalizado en Tercera Forma Normal (3FN) compuesto por cinco entidades:

* **`dbo.usuarios`:** Almacena la identidad de técnicos, supervisores y usuarios finales. Contiene atributos de autenticación, rol (`'Admin'`, `'TecnicoTier1'`, `'TecnicoTier2'`) y departamento de adscripción, con enmascaramiento dinámico sobre el correo electrónico.
* **`dbo.sistemas`:** Catálogo maestro de plataformas tecnológicas y servicios corporativos (ERP, CRM, SQL Server, Active Directory, Redes). Incluye enmascaramiento parcial sobre la dirección IP del servidor anfitrión.
* **`dbo.tickets`:** Tabla transaccional central de incidencias. Gestiona el ciclo de vida del ticket (`'Abierto'`, `'En Proceso'`, `'Resuelto'`, `'Cerrado'`), nivel de severidad y fecha de apertura, gobernada por políticas de seguridad por fila (RLS).
* **`dbo.kb_articulos`:** Base de conocimiento de procedimientos técnicos aprobados. Almacena el código de error, título, procedimiento de resolución y la columna nativa `contenido_embedding VECTOR(384)` para indexación matemática.
* **`dbo.auditoria_rag`:** Registro de telemetría y trazabilidad que documenta la consulta del usuario, los artículos recuperados, la distancia semántica calculada y la respuesta entregada por el modelo de IA.

<div style="page-break-before: always;"></div>

## 4. Alineación Estratégica con la Certificación Microsoft DP-800

SysDesk AI ha sido estructurado para satisfacer de forma integral las áreas de conocimiento y competencias evaluadas en la certificación **Microsoft DP-800: SQL AI Developer Associate**:

### Bloque A: Diseño y Modelado Relacional Sólido
* Diseño de un esquema de base de datos normalizado (3FN) con tablas interconectadas mediante claves primarias y foráneas consistentes.
* Incorporación de restricciones de integridad (`CHECK` y valores por defecto) para asegurar transiciones válidas en el ciclo de vida de los tickets.
* Creación de vistas analíticas y procedimientos automatizados para facilitar la gestión diaria del soporte y la evaluación de acuerdos de nivel de servicio (SLA).

### Bloque B: Desarrollo Asistido por Inteligencia Artificial y Supervisión Humana
* Utilización de asistentes de código (Copilot / ChatGPT) durante la fase de conceptualización y diseño técnico.
* Documentación detallada del proceso: registro de las instrucciones (*prompts*) enviadas, identificación de errores cometidos por la IA (como la sugerencia de tipos de datos obsoletos) y validación manual de cada cambio.

### Bloque C: Seguridad Corporativa y Principio de Menor Privilegio
* **Enmascaramiento Dinámico de Datos (DDM):** Protección automática para que los técnicos operen sin observar direcciones IP de infraestructura crítica ni correos electrónicos personales completos.
* **Seguridad a Nivel de Fila (RLS):** Implementación de reglas internas en el motor relacional que filtran de forma transparente las incidencias según el departamento del técnico, eliminando la necesidad de aplicar filtros manuales desde las aplicaciones.

### Bloque D: Análisis Empírico y Optimización de Rendimiento
* Evaluación comparativa de la salud de las consultas antes y después de aplicar estructuras de indexación estratégica.
* Demostración gráfica de cómo el motor de base de datos sustituye escaneos pesados de tabla por lecturas directas y selectivas, reduciendo la carga sobre la memoria y el almacenamiento.

### Bloques E y F: Espacio Vectorial y Búsqueda Inteligente (Semántica e Híbrida)
* Uso del nuevo tipo nativo de SQL Server 2025 para alojar representaciones conceptuales de los manuales de solución técnica.
* Implementación de algoritmos de proximidad semántica para ordenar los manuales según su relevancia con respecto a la duda planteada por el usuario.
* Búsqueda híbrida: combinación de filtrado determinista por plataforma afectada con ordenación semántica por relevancia temática.

### Bloque G: Asistencia RAG (Generación Aumentada por Recuperación)
* Ensamblado de un flujo de trabajo donde SQL Server proporciona la verdad documental y el modelo local redacta la solución.
* Erradicación de alucinaciones: el modelo tiene instrucciones estrictas de abstenerse de responder si la base de datos no contiene documentación formal sobre el fallo reportado.

<div style="page-break-before: always;"></div>

## 5. Beneficios Cuantificables y Gestión de Riesgos

La implementación de SysDesk AI aporta valor medible a la operativa tecnológica y define planes preventivos para mitigar riesgos organizativos y de infraestructura.

### Indicadores Clave de Éxito (KPIs de Negocio)
* **Reducción del Tiempo Medio de Resolución (MTTR):** Disminución sustancial en el tiempo que un técnico dedica a diagnosticar y documentar un problema común, gracias a la sugerencia instantánea de procedimientos ya validados.
* **Incremento en la Resolución en Primer Contacto (FCR):** Capacitación de operadores de soporte de nivel inicial para resolver incidencias complejas que anteriormente requerían ser escaladas a ingenieros sénior.
* **Eficiencia de Costes Operativos:** Reducción a cero de las partidas de gasto asociadas al consumo de tokens o llamadas a APIs comerciales en la nube, aprovechando la infraestructura existente del servidor.
* **Calidad y Adopción Documental:** Fomento del reciclaje de conocimiento: cada nueva solución incorporada a la base de datos queda inmediatamente disponible para el buscador semántico de toda la empresa.

---

### Análisis de Riesgos y Estrategias de Mitigación

| Riesgo Operativo o Técnico | Nivel de Impacto | Estrategia Preventiva de Mitigación |
| :--- | :--- | :--- |
| **Respuestas Inexactas o Alucinadas del Modelo** | Alto | El prompt del sistema restringe al modelo a utilizar exclusivamente el texto provisto por SQL Server. Si no hay coincidencias suficientes, el sistema declara la ausencia de documentación. |
| **Obsolescencia de la Documentación Interna** | Medio | Flujo de validación periódica sobre la base de conocimiento: las soluciones incorporan marcas temporales para priorizar artículos recientemente actualizados. |
| **Degradación de Recursos por Cómputo Local** | Medio | Selección de modelos optimizados y ligeros (de menos de 4.000 millones de parámetros) capaces de ejecutarse en memoria RAM estándar sin competir con la carga del motor SQL. |
| **Acceso Indebido a Procedimientos Restringidos** | Alto | La seguridad se ejecuta a nivel de motor (RLS): si un usuario no tiene autorización para leer una solución confidencial, el buscador vectorial no la incluye en su resultado. |

<div style="page-break-before: always;"></div>

## 6. Plan de Trabajo, Entregables y Conclusión

El proyecto se ejecutará de forma estructurada a lo largo de cuatro fases de trabajo secuenciales, asegurando la reproducibilidad y la trazabilidad de cada entregable:

### Cronograma de Ejecución por Fases

* **Fase 1: Cimientos y Modelado de Datos**
  * Despliegue de la base de datos en SQL Server 2025 bajo nivel de compatibilidad 170.
  * Creación de la estructura relacional con integridad referencial completa y restricciones de catálogo.
  * Carga de un lote representativo de incidencias, sistemas y artículos de conocimiento basados en escenarios cotidianos de TI.
* **Fase 2: Blindaje y Optimización del Motor**
  * Aplicación de reglas de enmascaramiento dinámico sobre direcciones IP y correos corporativos.
  * Configuración de la política de seguridad por departamentos (Row-Level Security).
  * Diagnóstico de una consulta de consulta masiva e incorporación de índices para optimizar los accesos a disco.
* **Fase 3: Búsqueda Semántica e Integración RAG**
  * Configuración del modelo local de generación de vectores en la máquina de desarrollo.
  * Carga de los vectores en la columna especializada de SQL Server 2025 y validación de consultas de similitud semántica.
  * Construcción del puente de comunicación para entregar el contexto recuperado al modelo de lenguaje local.
* **Fase 4: Consolidación Documental y Demostración**
  * Organización del repositorio de GitHub con instrucciones paso a paso para que cualquier revisor pueda desplegar la solución.
  * Redacción de la memoria técnica final con evidencias de ejecución y capturas de pantalla de cada hito.
  * Elaboración de la presentación ejecutiva para la defensa técnica del proyecto.

---

### Estructura del Repositorio

El proyecto se organiza bajo la estructura estandarizada recomendada para la certificación:

```text
dp-800-sysdesk-ai/
├── ai/             <- Modelos locales, embeddings y componentes RAG
├── database/       <- Scripts de base de datos (esquema, seguridad y optimización)
├── docs/           <- Documentación y propuesta técnica (Markdown / PDF)
├── presentation/   <- Diapositivas de soporte para la defensa técnica
├── tests/          <- Pruebas de validación funcional, roles y rendimiento
└── README.md       <- Documentación principal y guía de despliegue paso a paso
```

---

### Compromiso de Entregables
1. **Repositorio Público en GitHub:** Código SQL ordenado por carpetas, scripts de automatización e instrucciones claras de despliegue.
2. **Memoria Técnica en PDF:** Informe formal de 5 a 10 páginas con justificación del diseño, evidencias de planes de ejecución y pruebas de seguridad.
3. **Presentación Ejecutiva:** Diapositivas orientadas a la defensa técnica del proyecto en un tiempo de 5 a 8 minutos.

---

### Conclusión

**SysDesk AI** demuestra de manera tangible cómo una arquitectura de base de datos corporativa construida sobre **Microsoft SQL Server 2025** puede evolucionar hacia un sistema inteligente sin renunciar a las directivas de seguridad, gobernanza y soberanía del dato. El proyecto cubre las competencias nucleares de la certificación **Microsoft DP-800: SQL AI Developer Associate**, aportando un caso de uso práctico, realista y de alto impacto para un porfolio profesional de ingeniería de datos e IA.