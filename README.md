# Web Engine Utilities
**Developer:** [TonyA](https://github.com/ToneAr)

A collection of Wolfram Language functions used in the WREL Wolfram Web Engine deployment.

Exposed under the `WWE` context.

---
## Table of Contents
- [Deployment Functions](#deployment-functions)
- [Utility Functions](#utility-functions)
- [Database Functions](#database-functions)
- [External Tools](#external-tools)

---
## Deployment Functions
### `DeployWebapps`
#### Usage
| Form | Description |
|------|-------------|
| `DeployWebapps[]` | Deploys all repositories defined in the webapps-manifest.m file |

#### Options

| Option | Pattern | Default | Description |
|--------|---------|---------|-------------|
| `"Manifest"`       | `_String`    | `"/deployment/webapps-manifest.m"` | Location to the webapps-manifest.m file |
| `"Initialize"`     | `_?BooleanQ` | `False` | If `True`, will pass initialization flag to `DeployWebappRepository` |
| `"DeployFrontend"` | `_?BooleanQ` | `True`  | Whether to deploy the found frontends |
| `"DeployBackend"`  | `_?BooleanQ` | `True`  | Whether to deploy the found backends  |

---
### `DeployWebappRepository`
#### Usage
| Form | Description |
|------|-------------|
| `DeployWebappRepository[repositoryAssoc_]` | Deploys the repository at `repositoryAssoc` to the Tomcat ROOT webapp directory |

**Repository Association Format:**
```wl
<|
	"type"   -> "git"
	"remote" -> repoRemoteLink_String,
	"branch" -> trackedBranch_String,
	"local"  -> localRepoDirectory_String,
	"prefix" -> deploymentPrefix_String
|> | <|
	"type"   -> "site:paclet",
	"name"   -> pacletName_String,
	"site"   -> pacletSiteUrl_String,
	"prefix" -> deploymentPrefix_String
|> | | <|
	"type"   -> "url:paclet",
	"name"   -> pacletName_String,
	"remote" -> pacletUrl_String | pacletCloudObj_CloudObject,
	"prefix" -> deploymentPrefix_String
|>
```
#### Options

| Option | Pattern | Default | Description |
|--------|---------|---------|-------------|
| `"Initialize"`     | `_?BooleanQ` | `False` | If `True`, will pass `--init` to any WWE deployment scripts it executes |
| `"DeployFrontend"` | `_?BooleanQ` | `True`  | Whether to deploy the frontend |
| `"DeployBackend"`  | `_?BooleanQ` | `True`  | Whether to deploy the backend |

---
### `DeployWebappFrontEnd` (**Alias:** `deployBuildFolder`)
#### Usage
| Form | Description |
|------|-------------|
| `DeployWebappFrontEnd[buildDir_]`             | Deploys the build files inside `buildDir` to the root of the server `https://address/` |
| `DeployWebappFrontEnd[buildDir_, loc_String]` | Deploys the build files inside `buildDir` at `https://address/{loc}` |
#### Options
| Option | Pattern | Default | Description |
|--------|---------|---------|-------------|
| `"WebappLocation"` | `_String` | `"/usr/local/tomcat/webapps/ROOT"` | The ROOT location of the tomcat webapp directory |

---
### `DeployExpression` (**Alias:** `deployExpression`)
#### Usage
| Form | Description |
|------|-------------|
| `DeployExpression[expr_]`            | Deploys WL `expr` to `https://address/wl/{CreateUUID[]}` |
| `DeployExpression[expr_, location_]` | Deploys WL `expr` to `https://address/wl/{location}` |

#### Options
| Option | Pattern | Default | Description |
|--------|---------|---------|-------------|
| `OverwriteTarget`   | `_?BooleanQ` | `True` | Controls whether to overwrite existing content |
| `"WebappLocation"`  | `_String`    | `"/usr/local/tomcat/webapps/ROOT"` | The ROOT location of the tomcat webapp directory |
| `"ActiveExtension"` | `_String`    | `"wl"` | The extension on the server which handles WL requests using the GenerateHTTPResponse servlet |

---
### `AddWolframInitCode` (**Alias:** `addInitCode`)
#### Usage

| Form | Description |
|------|-------------|
| `AddWolframInitCode[initCode_]` | Adds `initCode` to the Wolfram Engine's `init.m` file |

#### Options
| Option | Pattern | Default | Description |
|--------|---------|---------|-------------|
| `"InitFile"` | `_String` | `"/usr/share/Wolfram/Kernel/init.m"` | Location of the Wolfram `init.m` file |

---
### AddSupervisorCommand (**Alias:** `addSupervisorCommand`, `DefineSupervisorCommand`)
#### Usage
| Form | Description |
|------|-------------|
| `AddSupervisorCommand[command_String, name_String]` | Adds program definition to supervisord file under the name `name` with command `command` |

#### Options
| Option | Pattern | Default | Description |
|--------|---------|---------|-------------|
| `"AutoStart"`     | `_?BooleanQ` | `True` | Autostart the program |
| `"AutoRestart"`   | `_?BooleanQ` | `True` | AutoRestart the program in the case of an unexpected crash |
| `"StdErrLogFile"` | `_String`    | `"/dev/stderr"` | File to pipe stderr to |
| `"StdOutLogFile"` | `_String`    | `"/dev/stdout"` | File to pipe stdout to |

---
### AddCronJob (**Alias:** `addCrontabCommand`, `DefineCronJob`)
#### Usage
| Form | Description |
|------|-------------|
| `AddCronJob[command_String, cronSpec_String]` | Adds a command to the crontab file with the provided cronSpec |

#### Options
| Option | Pattern | Default | Description |
|--------|---------|---------|-------------|
| `"CrontabFile"` | `_String` | `"/etc/crontab"` | Crontab file to write to |
| `"User"` | `_String` | `"root"` | User for the cron job |

---
### `RestartKernelPool`
#### Usage
| Form | Description |
|------|-------------|
| `RestartKernelPool[]` | Restarts the kernel pool by calling the KillAll.jsp endpoint |

---
## Utility Functions
### `Logger`
#### Usage
| Form | Description |
|------|-------------|
| `Logger[level_String, appName_String, functionName_String, message_String]` | Logs an event message to the log file `/var/log/{appName}/{functionName}-{level}.log` |

**Supported log levels:** `"error"`, `"info"`, `"warning"`, `"debug"`

#### Options
| Option | Pattern | Default | Description |
|--------|---------|---------|-------------|
| `"LogDirectory"` | `_String` | `"/var/log/"` | Directory that all generated logs will be saved in |

---
## Database Functions
### `WebappDatabaseInitialize` (**Alias:** `initialiseDatabase`)
#### Usage
| Form | Description |
|------|-------------|
| `WebappDatabaseInitialize[sqlFile_]` | Initializes the database by executing the SQL commands in `sqlFile` |

#### Options
| Option | Pattern | Default | Description |
|--------|---------|---------|-------------|
| `"RootPassword"`       | `_String`      | `SystemCredential["db-pass"]` | Password used for root connections to mariadb |
| `"DatabasePassword"`   | `_String`      | `SystemCredential["db-pass"]` | Password that will be used to connect to the created database (uses string replacement rules to replace any `db-pass` in the SQL file with this password) |
| `"Port"`               | `_Integer`     | `3306`         | Port mariadb is listening on |
| `"BaseURL"`            | `_String`      | `"mariadb"`    | Base URL for mariadb connection |
| `"TemplateParameters"` | `_Association` | `<||>` | Additional string template parameters used inside the SQL file |

---
### `WebappDatabaseConnect` (**Alias:** `makeDBConnection`)
#### Usage
| Form | Description |
|------|-------------|
| `WebappDatabaseConnect[]` | Creates a connection to the mariadb server |
| `WebappDatabaseConnect[dbName_]` | Creates a connection to the database `dbName` |

#### Options
| Option | Pattern | Default | Description |
|--------|---------|---------|-------------|
| `"Username"` | `_String`  | `"admin"` | Username used to connect to the database |
| `"Password"` | `_String`  | `SystemCredential["db-pass"]` | Password used to connect to the database |
| `"UseConnectionPool"`     | `_?BooleanQ` | `True` | Use mariadb connection pool |
| `"BaseURL"`  | `_String`  | `"mariadb"` | Base URL for mariadb connection |
| `"Port"`     | `_Integer` | `3306` | Port mariadb is listening on |

---
## External Tools
### ANSITools

Provides ANSI color and formatting utilities for terminal output.

**Source:** Wolfram Function Repository

#### Usage
Refer to the [ANSITools documentation](https://resources.wolframcloud.com/FunctionRepository/resources/ANSITools) for detailed usage information.

---
## Deprecated Functions
The following functions are deprecated and should not be used in new code:

- **`LogError`** / **`logError`** → Use `Logger` instead
- **`CommandLineParse`** → Use `ResourceFunction["CommandLineTools"]` instead

