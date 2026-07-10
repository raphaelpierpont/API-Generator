-- ========================================================================
-- 1. SWAGGER INFO
-- ========================================================================
INSERT INTO swagger_info (sort_order, info_key, info_value) VALUES
(1,'title','Enterprise Employee Management System API'),
(2,'description','API for managing corporate employee profiles, department tracking, salary histories, and job designations.'),
(3,'version','2.1.0')
ON CONFLICT(info_key) DO UPDATE SET sort_order=excluded.sort_order, info_value=excluded.info_value;

-- ========================================================================
-- 2. SWAGGER OBJECTS (Data Models)
-- ========================================================================
INSERT INTO swagger_object (sort_order, object_name, description) VALUES
(1,'EmployeeRequest','Payload to create or update an employee record'),
(2,'EmployeeResponse','Detailed employee profile data'),
(3,'EmployeeListResponse','Paginated array wrapped list of employee profiles'),
(4,'DepartmentRequest','Payload to add or edit a company department'),
(5,'DepartmentResponse','Department summary details'),
(6,'SalaryHistoryResponse','Historical record of employee pay scales'),
(7,'PromotionRequest','Payload to upgrade an employee''s title and department assignment'),
(8,'GenericMessageResponse','Standard success message container')
ON CONFLICT(object_name) DO UPDATE SET sort_order=excluded.sort_order, description=excluded.description;

-- ========================================================================
-- 3. SWAGGER FIELDS (Object Properties)
-- ========================================================================
WITH v(object_name, sort_order, field_name, datatype, required, description) AS (
    VALUES
    -- EmployeeRequest Fields
    ('EmployeeRequest',1,'first_name','string',1,'Employee first name'),
    ('EmployeeRequest',2,'last_name','string',1,'Employee last name'),
    ('EmployeeRequest',3,'birth_date','string',1,'Date of birth format YYYY-MM-DD'),
    ('EmployeeRequest',4,'gender','string',0,'M or F values allowed'),
    ('EmployeeRequest',5,'hire_date','string',1,'Date hired format YYYY-MM-DD'),
    
    -- EmployeeResponse Fields
    ('EmployeeResponse',1,'emp_no','integer',1,'Unique employee identifier key'),
    ('EmployeeResponse',2,'first_name','string',1,''),
    ('EmployeeResponse',3,'last_name','string',1,''),
    ('EmployeeResponse',4,'birth_date','string',1,''),
    ('EmployeeResponse',5,'gender','string',0,''),
    ('EmployeeResponse',6,'hire_date','string',1,''),
    ('EmployeeResponse',7,'current_title','string',0,'Active corporate title designation'),
    ('EmployeeResponse',8,'current_salary','number',0,'Active annual base income'),

    -- DepartmentRequest/Response Fields
    ('DepartmentRequest',1,'dept_name','string',1,'Unique name of corporate entity branch'),
    ('DepartmentResponse',1,'dept_no','string',1,'Internal ID formatted as d000'),
    ('DepartmentResponse',2,'dept_name','string',1,''),

    -- SalaryHistoryResponse Fields
    ('SalaryHistoryResponse',1,'salary','number',1,'Calculated base tracking number'),
    ('SalaryHistoryResponse',2,'from_date','string',1,'Activation timeframe stamp'),
    ('SalaryHistoryResponse',3,'to_date','string',1,'Termination or expiration timeframe stamp'),

    -- PromotionRequest Fields
    ('PromotionRequest',1,'new_title','string',1,'Target promotion role title text'),
    ('PromotionRequest',2,'new_dept_no','string',1,'Target department system key'),
    ('PromotionRequest',3,'salary_bump','number',1,'Updated income baseline amount'),

    -- GenericMessageResponse Fields
    ('GenericMessageResponse',1,'message','string',1,'Status confirmation alert response context')
)
INSERT INTO swagger_field (object_id, sort_order, field_name, datatype, required, description)
SELECT o.id, v.sort_order, v.field_name, v.datatype, v.required, v.description
FROM v JOIN swagger_object o ON o.object_name = v.object_name
ON CONFLICT(object_id, field_name) DO UPDATE SET
    sort_order=excluded.sort_order, datatype=excluded.datatype,
    required=excluded.required, description=excluded.description;

-- ========================================================================
-- 4. SWAGGER ENDPOINTS (Routes)
-- ========================================================================
INSERT INTO swagger_endpoint (sort_order, path, http_method, operation_id, summary, description, tag_name) VALUES
(1,'/employees','GET','getEmployees','List employees','Fetch a list of active and historic employee files','Employees'),
(2,'/employees','POST','createEmployee','Add employee','Provision a clean record entity file','Employees'),
(3,'/employees/{emp_no}','GET','getEmployeeById','Get employee details','Return full current dossier information','Employees'),
(4,'/employees/{emp_no}','PUT','updateEmployee','Update employee info','Overwrite core demographics registry records','Employees'),
(5,'/employees/{emp_no}','DELETE','terminateEmployee','Terminate employee','Soft-delete resource files out of current operational pool','Employees'),
(6,'/employees/{emp_no}/salaries','GET','getEmployeeSalaries','View salary history','Fetch timelines of compensation historical rows','Salaries'),
(7,'/employees/{emp_no}/promote','POST','promoteEmployee','Execute a promotion action','Simultaneously adjusts department registry mappings and title tags','Promotions'),
(8,'/departments','GET','getDepartments','List company departments','Extract full inventory list of organizational branches','Departments'),
(9,'/departments','POST','createDepartment','Create a department','Instantiate a new structural branch asset','Departments')
ON CONFLICT(path,http_method) DO UPDATE SET sort_order=excluded.sort_order, operation_id=excluded.operation_id, summary=excluded.summary, description=excluded.description, tag_name=excluded.tag_name;

-- ========================================================================
-- 5. SWAGGER PARAMETERS (Query/Header/Path)
-- ========================================================================
WITH v(path, http_method, sort_order, parameter_name, parameter_in, datatype, required, description) AS (
    VALUES
    -- Pagination and filtering for the list endpoint
    ('/employees','GET',1,'page','query','integer',0,'Page offset index count number'),
    ('/employees','GET',2,'limit','query','integer',0,'Total records payload return restriction size'),
    ('/employees','GET',3,'dept_no','query','string',0,'Filter results targeting strict department parameters'),
    
    -- Path mapping identifiers
    ('/employees/{emp_no}','GET',1,'emp_no','path','integer',1,'Employee target index number'),
    ('/employees/{emp_no}','PUT',1,'emp_no','path','integer',1,'Employee target index number'),
    ('/employees/{emp_no}','DELETE',1,'emp_no','path','integer',1,'Employee target index number'),
    ('/employees/{emp_no}/salaries','GET',1,'emp_no','path','integer',1,'Employee target index number'),
    ('/employees/{emp_no}/promote','POST',1,'emp_no','path','integer',1,'Employee target index number')
)
INSERT INTO swagger_parameter (endpoint_id, sort_order, parameter_name, parameter_in, datatype, required, description)
SELECT e.id, v.sort_order, v.parameter_name, v.parameter_in, v.datatype, v.required, v.description
FROM v JOIN swagger_endpoint e ON e.path = v.path AND e.http_method = v.http_method
ON CONFLICT(endpoint_id, parameter_name, parameter_in) DO UPDATE SET
    sort_order=excluded.sort_order, datatype=excluded.datatype,
    required=excluded.required, description=excluded.description;

-- ========================================================================
-- 6. SWAGGER RESPONSES
-- ========================================================================
WITH v(sort_order, response_code, description, object_name, path, http_method) AS (
    VALUES
    (1,'200','Employee listings successfully scanned and retrieved','EmployeeListResponse','/employees','GET'),
    (1,'201','Employee creation profile successfully committed','EmployeeResponse','/employees','POST'),
    (1,'200','Dossier payload successfully matched and retrieved','EmployeeResponse','/employees/{emp_no}','GET'),
    (1,'200','Target modifications processed successfully','EmployeeResponse','/employees/{emp_no}','PUT'),
    (1,'200','Target record deactivated from active systems database','GenericMessageResponse','/employees/{emp_no}','DELETE'),
    (1,'200','Full historic payroll timeline matches found','SalaryHistoryResponse','/employees/{emp_no}/salaries','GET'),
    (1,'200','Promotion transaction workflows logged successfully','GenericMessageResponse','/employees/{emp_no}/promote','POST'),
    (1,'200','Active structural division list mapped','DepartmentResponse','/departments','GET'),
    (1,'201','New corporate partition division verified and registered','DepartmentResponse','/departments','POST')
)
INSERT INTO swagger_response (endpoint_id, sort_order, response_code, description, object_name)
SELECT e.id, v.sort_order, v.response_code, v.description, v.object_name
FROM v JOIN swagger_endpoint e ON e.path = v.path AND e.http_method = v.http_method
ON CONFLICT(endpoint_id, response_code) DO UPDATE SET
    sort_order=excluded.sort_order, description=excluded.description, object_name=excluded.object_name;
