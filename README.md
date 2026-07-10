## Database Initialization and API Generation

Follow these steps to initialize the local SQLite database, seed the MySQL schema configuration records, and extract your API documentation artifacts.

### Prerequisites

Ensure you have the SQLite3 CLI tool installed. 
* **Mac**: `brew install sqlite`
* **Linux**: `sudo apt-get install sqlite3`
* **Windows**: Download the precompiled binaries from the official SQLite website.

---

### Step 1: Initialize the SQLite Database

Run the scaffold script to create the `.sqlite` file and build the database schema (tables, views, and recursive logic triggers).

```bash
sqlite3 database.sqlite < Scaffold.sql

```

### Step 2: Seed the Database Configuration Data

Populate the newly created database tables with the Swagger metadata values.

```bash
sqlite3 database.sqlite < SeedData.sql

```

---

### Step 3: Extract Documentation Artifacts

Once the database is configured and seeded, run the following commands to pull compiled OpenAPI JSON specifications and structural PlantUML visualization models straight out of the generated database views:

#### 1. Generate OpenAPI/Swagger JSON Spec

Extracts the compiled production-ready OpenAPI definition file.

```bash
sqlite3 database.sqlite "SELECT swagger_json FROM vw_swagger_json;" > swagger.json

```

#### 2. Generate Database ERD (PlantUML Diagram)

Extracts a standard class-style visual representation map of data tables.

```bash
sqlite3 database.sqlite "SELECT plantuml FROM vw_generate_plantuml;" > database_erd.puml

```

#### 3. Generate Functional Mindmap (PlantUML)

Extracts a visual hierarchical flowchart model representing systemic application routing connections.

```bash
sqlite3 database.sqlite "SELECT mindmap FROM vw_mindmap_plantuml;" > api_mindmap.puml

```

#### 4. Generate Text-Based Mindmap Outline

Extracts an indented plaintext documentation brief map outlining system tree nodes.

```bash
sqlite3 database.sqlite "SELECT mindmap FROM vw_mindmap_text;" > mindmap_outline.txt

```
