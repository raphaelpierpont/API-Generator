-- ==========================================================
-- SWAGGER METADATA DATABASE  (SUPER SAIYAN EDITION)
-- SQLite only. No app code, no external tooling.
-- Generators MUST read ONLY from views.
-- Inserts are idempotent using ON CONFLICT DO UPDATE.
-- Sample data is included for demonstration purposes.
-- Data can be added by duplicating a VALUES tuple in the appropriate INSERT block. No new SQL statements are required.
-- ==========================================================

-- FK enforcement is turned off only around the DROP/CREATE block below.
-- Reason: SQLite performs an implicit delete-then-drop when FK enforcement
-- is on, so DROP TABLE on a parent fails if a child table still holds rows
-- referencing it. That made the original file's "reset" pattern break on
-- any re-run against a populated database. FKs are turned back on before
-- the sample-data inserts, so the idempotent upserts are still checked.
PRAGMA foreign_keys = OFF;

-- ==========================================================
-- TABLES (existing, unchanged)
-- ==========================================================
DROP TABLE IF EXISTS swagger_info;
CREATE TABLE IF NOT EXISTS swagger_info (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sort_order INTEGER NOT NULL DEFAULT 0,
    info_key TEXT NOT NULL UNIQUE,
    info_value TEXT
);
DROP TABLE IF EXISTS swagger_object;
CREATE TABLE IF NOT EXISTS swagger_object (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sort_order INTEGER NOT NULL DEFAULT 0,
    object_name TEXT NOT NULL UNIQUE,
    description TEXT
);
DROP TABLE IF EXISTS swagger_field;
CREATE TABLE IF NOT EXISTS swagger_field (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    object_id INTEGER NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    field_name TEXT NOT NULL,
    datatype TEXT NOT NULL,
    required INTEGER NOT NULL DEFAULT 0,
    description TEXT,
    UNIQUE(object_id, field_name),
    FOREIGN KEY (object_id) REFERENCES swagger_object(id)
);
DROP TABLE IF EXISTS swagger_endpoint;
CREATE TABLE IF NOT EXISTS swagger_endpoint (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sort_order INTEGER NOT NULL DEFAULT 0,
    path TEXT NOT NULL,
    http_method TEXT NOT NULL,
    operation_id TEXT UNIQUE,
    summary TEXT,
    description TEXT,
    tag_name TEXT,
    UNIQUE(path, http_method)
);
DROP TABLE IF EXISTS swagger_parameter;
CREATE TABLE IF NOT EXISTS swagger_parameter (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    endpoint_id INTEGER NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    parameter_name TEXT NOT NULL,
    parameter_in TEXT NOT NULL,
    datatype TEXT,
    required INTEGER NOT NULL DEFAULT 0,
    description TEXT,
    object_name TEXT,
    UNIQUE(endpoint_id, parameter_name, parameter_in),
    FOREIGN KEY (endpoint_id) REFERENCES swagger_endpoint(id)
);
DROP TABLE IF EXISTS swagger_response;
CREATE TABLE IF NOT EXISTS swagger_response (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    endpoint_id INTEGER NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    response_code TEXT NOT NULL,
    description TEXT,
    object_name TEXT,
    UNIQUE(endpoint_id, response_code),
    FOREIGN KEY (endpoint_id) REFERENCES swagger_endpoint(id)
);

-- ==========================================================
-- NEW TABLES: real relationship modeling
-- (the old view referenced 'relationship'/'relationship_type'
--  tables that never existed anywhere in this file -- here
--  they actually do, so belongsTo/hasMany/etc. are real data)
-- ==========================================================
DROP TABLE IF EXISTS swagger_relationship_type;
CREATE TABLE IF NOT EXISTS swagger_relationship_type (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type_name TEXT NOT NULL UNIQUE,     -- hasMany / belongsTo / hasOne / manyToMany
    arrow TEXT NOT NULL,                -- literal PlantUML crow's-foot notation
    description TEXT
);

DROP TABLE IF EXISTS swagger_relationship;
CREATE TABLE IF NOT EXISTS swagger_relationship (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sort_order INTEGER NOT NULL DEFAULT 0,
    source_object_id INTEGER NOT NULL,
    target_object_id INTEGER NOT NULL,
    relationship_type_id INTEGER NOT NULL,
    label TEXT,                         -- e.g. 'places', 'has'

    UNIQUE(source_object_id, target_object_id, relationship_type_id),

    FOREIGN KEY (source_object_id) REFERENCES swagger_object(id),
    FOREIGN KEY (target_object_id) REFERENCES swagger_object(id),
    FOREIGN KEY (relationship_type_id) REFERENCES swagger_relationship_type(id)
);

DROP TABLE IF EXISTS swagger_verb_color;
CREATE TABLE IF NOT EXISTS swagger_verb_color (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sort_order INTEGER NOT NULL DEFAULT 0,
    http_method TEXT NOT NULL UNIQUE,   -- lowercase; 'default' = fallback
    color TEXT NOT NULL,                -- hex, no leading '#'
    description TEXT
);
 
DROP TABLE IF EXISTS swagger_datatype_color;
CREATE TABLE IF NOT EXISTS swagger_datatype_color (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sort_order INTEGER NOT NULL DEFAULT 0,
    datatype TEXT NOT NULL UNIQUE,      -- lowercase, RAW (pre-normalization)
                                         -- type name; 'default' = fallback
    color TEXT NOT NULL,
    description TEXT
);
 
-- ==========================================================
-- VIEWS
-- sort_order added to vw_swagger_object / vw_swagger_field so
-- downstream generators can order deterministically without
-- ever touching a base table.
-- ==========================================================

PRAGMA foreign_keys = ON;

DROP VIEW IF EXISTS vw_swagger_info;
CREATE VIEW vw_swagger_info AS
SELECT
    sort_order,
    info_key,
    COALESCE(info_value,'') AS info_value
FROM swagger_info;

DROP VIEW IF EXISTS vw_swagger_object;
CREATE VIEW vw_swagger_object AS
SELECT
    sort_order,
    object_name,
    COALESCE(description,'') AS description
FROM swagger_object;

DROP VIEW IF EXISTS vw_swagger_field;
CREATE VIEW vw_swagger_field AS
SELECT
    o.object_name,
    f.sort_order,
    f.field_name,

    CASE LOWER(f.datatype)
        WHEN 'integer' THEN 'integer'
        WHEN 'int' THEN 'integer'
        WHEN 'number' THEN 'number'
        WHEN 'float' THEN 'number'
        WHEN 'double' THEN 'number'
        WHEN 'boolean' THEN 'boolean'
        ELSE 'string'
    END AS swagger_type,
LOWER(f.datatype) AS raw_datatype,
    f.required,
    COALESCE(f.description,'') AS description

FROM swagger_field f
JOIN swagger_object o
    ON o.id = f.object_id;

DROP VIEW IF EXISTS vw_swagger_endpoint;
CREATE VIEW vw_swagger_endpoint AS
SELECT
    sort_order,
    path,
    LOWER(http_method) AS http_method,
    operation_id,
    COALESCE(summary,'') AS summary,
    COALESCE(description,'') AS description,
    COALESCE(tag_name,'') AS tag_name
FROM swagger_endpoint;

DROP VIEW IF EXISTS vw_swagger_parameter;
CREATE VIEW vw_swagger_parameter AS
SELECT
    e.path,
    LOWER(e.http_method) AS http_method,
    p.sort_order,
    p.parameter_name,
    p.parameter_in,

    CASE LOWER(COALESCE(p.datatype,''))
        WHEN 'integer' THEN 'integer'
        WHEN 'int' THEN 'integer'
        WHEN 'number' THEN 'number'
        WHEN 'float' THEN 'number'
        WHEN 'double' THEN 'number'
        WHEN 'boolean' THEN 'boolean'
        ELSE 'string'
    END AS swagger_type,

    p.required,
    COALESCE(p.description,'') AS description,
    COALESCE(p.object_name,'') AS object_name

FROM swagger_parameter p
JOIN swagger_endpoint e
    ON e.id = p.endpoint_id;

DROP VIEW IF EXISTS vw_swagger_response;
CREATE VIEW vw_swagger_response AS
SELECT
    e.path,
    LOWER(e.http_method) AS http_method,
    r.sort_order,
    r.response_code,
    COALESCE(r.description,'') AS description,
    COALESCE(r.object_name,'') AS object_name
FROM swagger_response r
JOIN swagger_endpoint e
    ON e.id = r.endpoint_id;

-- NEW: relationship views, fully denormalized to object_name
-- (mirrors the existing pattern used by parameter/response views)
DROP VIEW IF EXISTS vw_swagger_relationship_type;
CREATE VIEW vw_swagger_relationship_type AS
SELECT
    type_name,
    arrow,
    COALESCE(description,'') AS description
FROM swagger_relationship_type;

DROP VIEW IF EXISTS vw_swagger_relationship;
CREATE VIEW vw_swagger_relationship AS
SELECT
    r.sort_order,
    src.object_name AS source_object,
    tgt.object_name AS target_object,
    rt.type_name    AS relationship_type,
    rt.arrow        AS arrow,
    COALESCE(r.label, rt.type_name) AS label
FROM swagger_relationship r
JOIN swagger_object src ON src.id = r.source_object_id
JOIN swagger_object tgt ON tgt.id = r.target_object_id
JOIN swagger_relationship_type rt ON rt.id = r.relationship_type_id;

DROP VIEW IF EXISTS vw_swagger_verb_color;
CREATE VIEW vw_swagger_verb_color AS
SELECT
    sort_order,
    http_method,
    color,
    COALESCE(description,'') AS description
FROM swagger_verb_color;
 
DROP VIEW IF EXISTS vw_swagger_datatype_color;
CREATE VIEW vw_swagger_datatype_color AS
SELECT
    sort_order,
    datatype,
    color,
    COALESCE(description,'') AS description
FROM swagger_datatype_color;

DROP VIEW IF EXISTS vw_swagger_json;
CREATE VIEW vw_swagger_json AS
WITH info_block AS (
    SELECT
        '  "info": {' || CHAR(10) ||
        '    "title": ' || json_quote((SELECT info_value FROM vw_swagger_info WHERE info_key='title')) || ',' || CHAR(10) ||
        '    "description": ' || json_quote((SELECT info_value FROM vw_swagger_info WHERE info_key='description')) || ',' || CHAR(10) ||
        '    "version": ' || json_quote((SELECT info_value FROM vw_swagger_info WHERE info_key='version')) || CHAR(10) ||
        '  }' AS block
),
def_blocks AS (
    SELECT
        obj.object_name,
        '    ' || json_quote(obj.object_name) || ': {' || CHAR(10) ||
        '      "type": "object",' || CHAR(10) ||
        (CASE WHEN fields_txt IS NULL THEN '      "properties": {},'
         ELSE '      "properties": {' || CHAR(10) || fields_txt || CHAR(10) || '      },' END) || CHAR(10) ||
        '      "required": [' || COALESCE(required_txt,'') || ']' || CHAR(10) ||
        '    }' AS block
    FROM (
        SELECT
            o.object_name,
            (
                SELECT GROUP_CONCAT(
                    '        ' || json_quote(field_name) || ': { "type": ' || json_quote(swagger_type) || ' }',
                    ',' || CHAR(10)
                )
                FROM (
                    SELECT field_name, swagger_type
                    FROM vw_swagger_field f
                    WHERE f.object_name = o.object_name
                    ORDER BY f.sort_order, f.field_name
                )
            ) AS fields_txt,
            (
                SELECT GROUP_CONCAT(json_quote(field_name), ', ')
                FROM (
                    SELECT field_name
                    FROM vw_swagger_field f
                    WHERE f.object_name = o.object_name AND f.required = 1
                    ORDER BY f.field_name
                )
            ) AS required_txt
        FROM vw_swagger_object o
    ) obj
),
responses_block AS (
    SELECT
        e.path, e.http_method,
        (
            SELECT GROUP_CONCAT(
                '          ' || json_quote(response_code) || ': { "description": ' || json_quote(description) || ' }',
                ',' || CHAR(10)
            )
            FROM (
                SELECT response_code, description
                FROM vw_swagger_response r
                WHERE r.path = e.path AND r.http_method = e.http_method
                ORDER BY r.response_code
            )
        ) AS txt
    FROM vw_swagger_endpoint e
),
method_blocks AS (
    SELECT
        e.path, e.http_method,
        '      ' || json_quote(e.http_method) || ': {' || CHAR(10) ||
        '        "operationId": ' || json_quote(e.operation_id) || ',' || CHAR(10) ||
        '        "summary": ' || json_quote(e.summary) || ',' || CHAR(10) ||
        '        "description": ' || json_quote(e.description) || ',' || CHAR(10) ||
        '        "tags": [' || json_quote(e.tag_name) || '],' || CHAR(10) ||
        '        "responses": {' ||
        (CASE WHEN r.txt IS NULL THEN '}'
         ELSE CHAR(10) || r.txt || CHAR(10) || '        }' END) || CHAR(10) ||
        '      }' AS block
    FROM vw_swagger_endpoint e
    JOIN responses_block r ON r.path = e.path AND r.http_method = e.http_method
),
path_blocks AS (
    SELECT
        p.path,
        '    ' || json_quote(p.path) || ': {' || CHAR(10) ||
        (
            SELECT GROUP_CONCAT(block, ',' || CHAR(10))
            FROM (
                SELECT block FROM method_blocks m
                WHERE m.path = p.path
                ORDER BY m.http_method
            )
        ) || CHAR(10) ||
        '    }' AS block
    FROM (SELECT DISTINCT path FROM vw_swagger_endpoint) p
)
SELECT
    '{' || CHAR(10) ||
    '  "swagger": "2.0",' || CHAR(10) ||
    (SELECT block FROM info_block) || ',' || CHAR(10) ||
    '  "paths": {' || CHAR(10) ||
    (SELECT GROUP_CONCAT(block, ',' || CHAR(10)) FROM (SELECT block FROM path_blocks ORDER BY path)) || CHAR(10) ||
    '  },' || CHAR(10) ||
    '  "definitions": {' || CHAR(10) ||
    (SELECT GROUP_CONCAT(block, ',' || CHAR(10)) FROM (SELECT block FROM def_blocks ORDER BY object_name)) || CHAR(10) ||
    '  }' || CHAR(10) ||
    '}'
    AS swagger_json;
 ;
-- ==========================================================
-- PLANTUML GENERATOR -- rebuilt from the ground up.
-- Reads ONLY from vw_swagger_* views, per the file's own rule.
-- Uses GROUP_CONCAT(... ORDER BY ...) -- SQLite 3.44+ -- instead
-- of the old nested-subquery-for-ordering trick.
-- ==========================================================
DROP VIEW IF EXISTS vw_generate_plantuml;
CREATE VIEW vw_generate_plantuml AS
WITH title_line AS (
    SELECT 'title ' ||
           (SELECT info_value FROM vw_swagger_info WHERE info_key = 'title') ||
           ' (v' || (SELECT info_value FROM vw_swagger_info WHERE info_key = 'version') || ')'
           AS line
),
entities AS (
    SELECT
        o.object_name,
        o.sort_order,
        'entity "' || o.object_name || '" as ' || o.object_name || ' {' || CHAR(10) ||
        COALESCE(
            (SELECT GROUP_CONCAT(field_line, CHAR(10))
             FROM (
                SELECT
                    CASE WHEN f.required = 1
                        THEN '  * ' || f.field_name || ' : ' || f.swagger_type
                        ELSE '  ' || f.field_name || ' : ' || f.swagger_type
                    END AS field_line
                FROM vw_swagger_field f
                WHERE f.object_name = o.object_name
                ORDER BY f.sort_order, f.field_name
             )),
            '  ..no fields..'
        ) || CHAR(10) || '}' AS block
    FROM vw_swagger_object o
),
relationships AS (
    SELECT
        sort_order,
        source_object || ' ' || arrow || ' ' || target_object ||
        ' : ' || label AS line
    FROM vw_swagger_relationship
),
-- endpoints that touch an object get documented as a note attached
-- to that entity, grouped so one object with many endpoints gets one note
endpoint_notes AS (
    SELECT
        object_name,
        'note right of ' || object_name || CHAR(10) ||
        GROUP_CONCAT(note_line, CHAR(10)) ||
        CHAR(10) || 'end note' AS block
    FROM (
        SELECT DISTINCT
            r.object_name,
            '  ' || UPPER(e.http_method) || ' ' || e.path AS note_line
        FROM vw_swagger_response r
        JOIN vw_swagger_endpoint e
            ON e.path = r.path AND e.http_method = r.http_method
        WHERE r.object_name IS NOT NULL AND r.object_name <> ''
    )
    GROUP BY object_name
)
SELECT
    '@startuml' || CHAR(10) ||
    'skinparam shadowing false' || CHAR(10) ||
    'skinparam roundcorner 8' || CHAR(10) ||
    (SELECT line FROM title_line) || CHAR(10) ||
    CHAR(10) ||
 
    (SELECT GROUP_CONCAT(block, CHAR(10) || CHAR(10))
     FROM (SELECT block FROM entities ORDER BY sort_order, object_name)) ||
 
    CHAR(10) || CHAR(10) ||
 
    COALESCE(
        (SELECT GROUP_CONCAT(line, CHAR(10))
         FROM (SELECT line FROM relationships ORDER BY sort_order)),
        ''
    ) ||
 
    CHAR(10) || CHAR(10) ||
 
    COALESCE(
        (SELECT GROUP_CONCAT(block, CHAR(10))
         FROM (SELECT block FROM endpoint_notes ORDER BY object_name)),
        ''
    ) ||
 
    CHAR(10) || '@enduml'
    AS plantuml;
-- ==========================================================
-- GENERAL DATA INSERTS (idempotent, ON CONFLICT DO UPDATE)
-- ==========================================================

INSERT INTO swagger_relationship_type (type_name, arrow, description) VALUES
('hasMany',    '||--o{', 'One source has many targets'),
('belongsTo',  '}o--||', 'Many sources belong to one target'),
('hasOne',     '||--||', 'One-to-one'),
('manyToMany', '}o--o{', 'Many-to-many')
ON CONFLICT(type_name) DO UPDATE SET arrow=excluded.arrow, description=excluded.description;

INSERT INTO swagger_verb_color (sort_order, http_method, color, description) VALUES
(1,'get',     '61AFFE', 'Common verb'),
(2,'post',    '49CC90', 'Common verb'),
(3,'put',     'FCA130', 'Common verb'),
(4,'delete',  'F93E3E', 'Common verb'),
(5,'patch',   'B10DC9', 'Uncommon verb'),
(6,'head',    '9012FE', 'Uncommon verb'),
(7,'options', '0D5AA7', 'Uncommon verb'),
(8,'trace',   '7D8492', 'Uncommon verb'),
(9,'connect', '4A4A4A', 'Uncommon verb'),
(10,'default','CCCCCC', 'Fallback for any unrecognized verb')
ON CONFLICT(http_method) DO UPDATE SET sort_order=excluded.sort_order, color=excluded.color, description=excluded.description;
 
-- Basic JSON Schema primitives (string/integer/number/boolean) each get
-- a distinct color; non-basic types (array/object) each still get their
-- own color rather than folding into "string". 'default' covers custom
-- or exotic raw type names (date, uuid, binary, etc.) that aren't one
-- of the above -- so even something never seen before still gets colored,
-- not left blank.
INSERT INTO swagger_datatype_color (sort_order, datatype, color, description) VALUES
(1,'string',  'F4D35E', 'Basic JSON type'),
(2,'integer', '5DA9E9', 'Basic JSON type'),
(3,'int',     '5DA9E9', 'Basic JSON type (alias of integer)'),
(4,'number',  '6A4C93', 'Basic JSON type'),
(5,'float',   '6A4C93', 'Basic JSON type (alias of number)'),
(6,'double',  '6A4C93', 'Basic JSON type (alias of number)'),
(7,'boolean', 'EF6461', 'Basic JSON type'),
(8,'array',   '2EC4B6', 'Non-basic type'),
(9,'object',  'FF9F1C', 'Non-basic type'),
(10,'default','8D99AE', 'Fallback for any custom/uncommon type')
ON CONFLICT(datatype) DO UPDATE SET sort_order=excluded.sort_order, color=excluded.color, description=excluded.description;
 

-- ==========================================================
-- MINDMAP GENERATOR
-- Reads ONLY from vw_swagger_* views. Root = API title/version.
--
-- Branch 1: endpoints grouped by tag. Each endpoint expands into:
--   - Request: <object_name> or None (from vw_swagger_parameter
--     rows where parameter_in='body'; that's what its object_name
--     column is for)
--   - Responses: one <code>: <object_name|None> leaf per response
--     row, or a single None leaf if the endpoint has no responses
--
-- Branch 2: data model. Each object expands into its fields as
-- <field_name> : <datatype> leaves, or (no fields) if it has none.
--
-- Same hand-built CHAR(10)-based formatting as vw_generate_plantuml
-- and vw_swagger_json, for the same reason: PlantUML mindmap syntax
-- is indentation/depth-marker driven, so it has to be real text with
-- real line breaks, not something a generic JSON/string function emits.
-- ==========================================================
DROP VIEW IF EXISTS vw_mindmap_plantuml;
CREATE VIEW vw_mindmap_plantuml AS
WITH title_line AS (
    SELECT
        (SELECT info_value FROM vw_swagger_info WHERE info_key = 'title') ||
        ' (v' || (SELECT info_value FROM vw_swagger_info WHERE info_key = 'version') || ')'
        AS line
),
endpoint_blocks AS (
    SELECT
        COALESCE(NULLIF(e.tag_name,''), 'Untagged') AS tag,
        e.path, e.http_method,
        '****[#' ||
        COALESCE(
            (SELECT color FROM vw_swagger_verb_color WHERE http_method = e.http_method),
            (SELECT color FROM vw_swagger_verb_color WHERE http_method = 'default')
        ) || '] ' ||
        UPPER(e.http_method) || ' ' || e.path ||
        (CASE WHEN e.operation_id IS NOT NULL AND e.operation_id <> ''
              THEN ' : ' || e.operation_id ELSE '' END) || CHAR(10) ||
 
        '***** Request: ' ||
        COALESCE(
            (SELECT p.object_name FROM vw_swagger_parameter p
             WHERE p.path = e.path AND p.http_method = e.http_method
                   AND p.parameter_in = 'body'
                   AND p.object_name IS NOT NULL AND p.object_name <> ''
             ORDER BY p.sort_order LIMIT 1),
            'None'
        ) || CHAR(10) ||
 
        '***** Responses' || CHAR(10) ||
        COALESCE(
            (SELECT GROUP_CONCAT(
                '****** ' || response_code || ': ' || COALESCE(NULLIF(object_name,''),'None'),
                CHAR(10)
             )
             FROM (SELECT response_code, object_name
                   FROM vw_swagger_response r
                   WHERE r.path = e.path AND r.http_method = e.http_method
                   ORDER BY r.sort_order)),
            '****** None'
        ) AS block
    FROM vw_swagger_endpoint e
),
tag_blocks AS (
    SELECT
        t.tag,
        '*** ' || t.tag || CHAR(10) ||
        (SELECT GROUP_CONCAT(block, CHAR(10))
         FROM (SELECT block FROM endpoint_blocks e
               WHERE e.tag = t.tag
               ORDER BY e.path, e.http_method)) AS block
    FROM (SELECT DISTINCT tag FROM endpoint_blocks) t
),
object_blocks AS (
    SELECT
        o.object_name,
        '*** ' || o.object_name || CHAR(10) ||
        COALESCE(
            (SELECT GROUP_CONCAT(
                '****[#' ||
                COALESCE(
                    (SELECT color FROM vw_swagger_datatype_color WHERE datatype = f.raw_datatype),
                    (SELECT color FROM vw_swagger_datatype_color WHERE datatype = 'default')
                ) || '] ' || f.field_name || ' : ' || f.raw_datatype,
                CHAR(10)
             )
             FROM (SELECT field_name, raw_datatype FROM vw_swagger_field f
                   WHERE f.object_name = o.object_name
                   ORDER BY f.sort_order, f.field_name) f),
            '**** (no fields)'
        ) AS block
    FROM vw_swagger_object o
)
SELECT
    '@startmindmap' || CHAR(10) ||
    '* ' || (SELECT line FROM title_line) || CHAR(10) ||
 
    '** Endpoints' || CHAR(10) ||
    (SELECT GROUP_CONCAT(block, CHAR(10))
     FROM (SELECT block FROM tag_blocks ORDER BY tag)) || CHAR(10) ||
 
    '** Data Model' || CHAR(10) ||
    (SELECT GROUP_CONCAT(block, CHAR(10))
     FROM (SELECT block FROM object_blocks ORDER BY object_name)) || CHAR(10) ||
 
    '@endmindmap'
    AS mindmap;
 
 DROP VIEW IF EXISTS vw_mindmap_text;
CREATE VIEW vw_mindmap_text AS
  WITH RECURSIVE
  replacements(find_str, replace_str, priority) AS (
     VALUES 
            ('*', CHAR(9), 1),
            (CHAR(9)||' ', CHAR(9), 2),
            (CHAR(10)||CHAR(9), CHAR(10), 3),
            ('@startmindmap'||CHAR(10), '', 4),
            ('@endmindmap', '', 5)
  ),
  pairs_raw(find_str, replace_str, priority) AS (
    SELECT find_str, replace_str, priority FROM replacements
    UNION ALL
    SELECT '[#'||color||'] ', '', 9 FROM vw_swagger_datatype_color
    UNION ALL
    SELECT '[#'||color||'] ', '', 9 FROM vw_swagger_verb_color
  ),
  -- Assign a guaranteed gapless sequence (1, 2, 3...) to drive the recursion
  pairs AS (
    SELECT find_str, replace_str, 
           ROW_NUMBER() OVER (ORDER BY priority) AS step_id
    FROM pairs_raw
  ),
  do_replace(id, current_text, step) AS (
     -- Base case: Grab the initial mindmap text
     SELECT 0, mindmap, 1 FROM vw_mindmap_plantuml
     UNION ALL
     -- Recursive case: Apply replacements one step at a time
     SELECT d.id, REPLACE(d.current_text, p.find_str, p.replace_str), d.step + 1
     FROM do_replace d
     JOIN pairs p ON p.step_id = d.step
  ),
  final_trans AS (
     -- Pull the result from the final step
     SELECT id, current_text FROM do_replace
     WHERE step = (SELECT COUNT(*) + 1 FROM pairs)
  )
SELECT current_text AS mindmap FROM final_trans;

DROP VIEW IF EXISTS vw_planuml_dependency;
CREATE VIEW vw_planuml_dependency AS

SELECT '@startuml' 
UNION ALL
SELECT DISTINCT '[' || m.name || '] ' 
FROM sqlite_master m WHERE m.type='table'
UNION ALL
SELECT '[' || m.name || '] --> [' || fk."table" || '] : ' || fk."from" || ' -> ' || fk."to"
FROM sqlite_master m
JOIN pragma_foreign_key_list(m.name) fk
WHERE m.type = 'table'
UNION ALL
SELECT '@enduml';

DROP VIEW IF EXISTS vw_create_esql;
CREATE VIEW vw_create_esql AS

WITH esql_source(datatype, source_expr) AS (
VALUES
 ('header','TRIM(InputRoot.HTTPInputHeader.?)')
,('query','TRIM(InputLocalEnvironment.REST.Input.Parameters.?)')
,('body','TRIM(InputRoot.JSON.Data.?)')
,('path','TRIM(InputLocalEnvironment.REST.Input.Parameters.?)')
),
declarations AS (
    SELECT
        '        DECLARE ' || sp.parameter_name || ' CHARACTER ' ||
        REPLACE(es.source_expr, '?', sp.parameter_name) || ';' AS decl_line,
        '            ' || sp.parameter_name AS call_arg,
        sp.path, sp.http_method, sp.sort_order
    FROM vw_swagger_parameter sp
    JOIN esql_source es ON es.datatype = sp.parameter_in
),
params AS (
    SELECT
        REPLACE(REPLACE(REPLACE(TRIM(path,'/'), '/', '_'), '{', ''), '}', '') || '_' || http_method AS proc_name,
        path, http_method,
        GROUP_CONCAT(decl_line, CHAR(10)) AS decls,
        GROUP_CONCAT(call_arg, ',' || CHAR(10)) AS call_args
    FROM declarations
    GROUP BY path, http_method
)
SELECT
     proc_name AS named,
    '    CREATE FUNCTION Main() RETURNS BOOLEAN' || CHAR(10) ||
    '    BEGIN' || CHAR(10) ||
    '        DECLARE statusCode INTEGER;' || CHAR(10) ||
    '        DECLARE responseBody CHARACTER ''{"message":"No content."}'';' || CHAR(10) ||
    decls || CHAR(10) ||
    '        -- Call the stored procedure' || CHAR(10) ||
    '        CALL "' || proc_name || '"(' || CHAR(10) ||
    '            statusCode,' || CHAR(10) ||
    '            responseBody,' || CHAR(10) ||
    call_args || CHAR(10) ||
    '        );' || CHAR(10) ||
    '        -- Set HTTP headers' || CHAR(10) ||
    '        SET OutputRoot.HTTPResponseHeader."Content-Type" = ''application/json'';' || CHAR(10) ||
    '        SET OutputLocalEnvironment.Destination.HTTP.ReplyStatusCode = statusCode;' || CHAR(10) ||
    '        DECLARE dataAsBit BIT CAST(COALESCE(responseBody,''{"message":"No content."}'') AS BIT CCSID 1208);' || CHAR(10) ||
    '        CREATE LASTCHILD OF OutputRoot DOMAIN ''JSON'' PARSE(dataAsBit CCSID 1208);' || CHAR(10) ||
    '        RETURN TRUE;' || CHAR(10) ||
    '    END;' || CHAR(10) ||
    '    -- EXTERNAL NAME must match your DSN and DB name, schema, and proc name' || CHAR(10) ||
    '    CREATE PROCEDURE "' || proc_name || '" (' || CHAR(10) ||
    '        INOUT statusCode INTEGER,' || CHAR(10) ||
    '        INOUT responseBody CHARACTER,' || CHAR(10) ||
    call_args || ' CHARACTER' || CHAR(10) ||
    '    )' || CHAR(10) ||
    '    LANGUAGE DATABASE' || CHAR(10) ||
    '    EXTERNAL NAME "dbo.' || proc_name || '"; -- Adjust to your actual DSN' || CHAR(10) ||
    'END MODULE;' AS ESQL
FROM params
;

DROP VIEW IF EXISTS vw_create_storedprocedure;
CREATE VIEW vw_create_storedprocedure AS

WITH sql_types(swagger_type, sql_type) AS (
VALUES
 ('integer','INT')
,('number','FLOAT')
,('boolean','BIT')
,('string','VARCHAR(50)')
),
params AS (
    SELECT
        '    @' || sp.parameter_name || ' ' || st.sql_type
        || CASE WHEN sp.required = 1 THEN '' ELSE ' = NULL' END
        || ' -- ' || sp.description AS line,
        sp.parameter_name || ' -- '|| sp.description AS param,
        sp.path, sp.http_method, sp.sort_order
    FROM vw_swagger_parameter sp
    JOIN sql_types st ON st.swagger_type = sp.swagger_type
)
SELECT REPLACE(REPLACE(REPLACE(TRIM(path,'/'), '/', '_'), '{', ''), '}', '') || '_' || http_method AS named,
    'CREATE OR ALTER PROCEDURE [dbo].[' ||
    REPLACE(REPLACE(REPLACE(TRIM(path,'/'), '/', '_'), '{', ''), '}', '') ||
    '_' || http_method || ']' || CHAR(10) ||
    '(' || CHAR(10) ||
    '    @status_code INT OUTPUT,' || CHAR(10) ||
    '    @body NVARCHAR(4000) OUTPUT,' || CHAR(10) ||
    GROUP_CONCAT(line, ',' || CHAR(10)) || CHAR(10) ||
    ')' || CHAR(10) ||
    'AS' || CHAR(10) ||
    'BEGIN' || CHAR(10) ||
    '    SET NOCOUNT ON;' || CHAR(10) ||CHAR(10) ||
    '    -- your code here' || CHAR(10) ||
    '    SELECT ' || CHAR(10) ||
    '        @status_code as status' || CHAR(10) ||
    '       ,@body as body' || CHAR(10) ||
    GROUP_CONCAT('       ,' ||param,  CHAR(10))|| CHAR(10) ||CHAR(10) ||
    '    SET @status_code = 200;' || CHAR(10) ||
    '    SET @body = ''{}'';' || CHAR(10) ||
    'END' AS SP
FROM params
GROUP BY path, http_method
;
