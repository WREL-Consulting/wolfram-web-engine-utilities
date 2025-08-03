# Web Engine Utilities
Developer: [TonyA](https://github.com/ToneAr)

A collection of WL functions used in the WREL Wolfram Web Engine deployment.

Exposed under the `` WWE` `` context.

## Deployment Functions

- ### DeployWebappRepository (alias: deployBuildFolder)
  - #### Usage
    | Form | Description |
    |------|-------------|
    | `DeployWebappRepository[repositoryAssoc_]` | Deploys the repository at `repositoryAssoc` to the Tomcat ROOT webapp directory |

    where:
    ```wl
    <|
      "link"   -> _String, (* SSH clone link to repository *)
      "name"   -> _String, (* Repository name *)
      "branch" -> _String, (* Branch to clone and track with CD endpoint *)
      "local"  -> _String, (* Local directory of repo *)
      "prefix" -> _String  (* The prefix used for any deployments *)
    |>
    ```
  - #### Options
    | Option | Pattern | Default | Description |
    |--------|---------|---------|-------------|
    | `"Initialize"` | `_?BooleanQ` | `False` | If `True`, will pass `--init` to any WWE deployment scripts it executes |

---

- ### DeployWebappFrontEnd (alias: deployBuildFolder)

  - #### Usage
    | Form | Description |
    |------|-------------|
    | `DeployWebappFrontEnd[buildDir_]` | Deploys the build files inside `buildDir` to the root of the server `https://address/` |
    | `DeployWebappFrontEnd[buildDir_, location_String]` | Deploys the build files inside `buildDir` at `https://address/{location}` |


  - #### Options
    | Option | Pattern | Default | Description |
    |--------|---------|---------|-------------|
    | `"WebappLocation"` | `_String` | `"/usr/local/tomcat/webapps/ROOT"` | The ROOT location of the tomcat webapp directory |

---

- ### DeployExpression

  - #### Usage
    | Form | Description |
    |------|-------------|
    | `DeployExpression[expr_]` | Deploys WL `expr` to `https://address/wl/{CreateUUID[]}` |
    | `DeployExpression[expr_, location_]` | Deploys WL `expr` to `https://address/wl/{location}` |

  - #### Options
    | Option | Pattern | Default | Description |
    |--------|---------|---------|-------------|
    | `OverwriteTarget` | `_?BooleanQ` | `True` | Controls whether to overwrite existing content |
    | `"WebappLocation"` | `_String` | `"/usr/local/tomcat/webapps/ROOT"` | The ROOT location of the tomcat webapp directory |
    | `"ActiveExtension"` | `_String` | `"wl"` | The extension on the server which handles WL requests using the GenerateHTTPResponse servlet |

---

- ### AddWolframInitCode (alias: addInitCode)
  - #### Usage
    | Form | Description |
    |------|-------------|
    | `AddWolframInitCode[initCode_]` | Adds `initCode` to the Wolfram Engine's `init.m` file |

  - #### Options
    | Option | Pattern | Default | Description |
    |--------|---------|---------|-------------|
    | `"InitFile"` | `_String` | `"/usr/share/Wolfram/Kernel/init.m"` | Location of the Wolfram `init.m` file |

---

- ### DefineSupervisorCommand (alias: addSupervisorCommand)
  - #### Usage
    | Form | Description |
    |------|-------------|
    | `DefineSupervisorCommand[command_String, name_String]` | Adds program definition to supervisord file under the name `name` with command `command` |

  - #### Options
    | Option | Pattern | Default | Description |
    |--------|---------|---------|-------------|
    | `"AutoStart"` | `_?BooleanQ` | `True` | Autostart the program |
    | `"AutoRestart"` | `_?BooleanQ` | `True` | AutoRestart the program in the case of an unexpected crash |
    | `"StdErrLogFile"` | `_String` | `"/dev/stderr"` | File to pipe stderr to |
    | `"StdOutLogFile"` | `_String` | `"/dev/stdout"` | File to pipe stdout to |

---

- ### DefineCronJob (alias: addCrontabCommand)
  - #### Usage
    | Form | Description |
    |------|-------------|
    | `DefineCronJob[command_String, cronSpec_String]` | Adds a command to the crontab file with the provided cronSpec |

  - #### Options
    | Option | Pattern | Default | Description |
    |--------|---------|---------|-------------|
    | `"CrontabFile"` | `_String` | `"/etc/crontab"` | Crontab file to write to |
    | `"User"` | `_String` | `"root"` | User for the cron job |

---

- ### RestartKernelPool
  - #### Usage
    | Form | Description |
    |------|-------------|
    | `RestartKernelPool[]` | Restarts the kernel pool by calling the KillAll.jsp endpoint |

---

## Utility Functions

- ### LogError (alias: logError)
  - #### Usage
    | Form | Description |
    |------|-------------|
    | `LogError[appName_String, functionName_String, message_String]` | Logs an event message to the log file `/var/log/appName/functionName-error.log` |

  - #### Options
    | Option | Pattern | Default | Description |
    |--------|---------|---------|-------------|
    | `"LogDirectory"` | `_String` | `"/var/log/"` | Directory that all generated logs will be saved in |

---

## Database Functions

- ### WebappDatabaseInitialize (alias: initiliseDatabase)
  - #### Usage
    | Form | Description |
    |------|-------------|
    | `WebappDatabaseInitialize[sqlFile_]` | Initializes the database by executing the SQL commands in `sqlFile` |

  - #### Options
    | Option | Pattern | Default | Description |
    |--------|---------|---------|-------------|
    | `"RootPassword"` | `_String` | `SystemCredential["db-pass"]` | Password used for root connections to mariadb |
    | `"DatabasePassword"` | `_String` | `SystemCredential["db-pass"]` | Password that will be used to connect to the created database (uses string replacement rules to replace any `db-pass` in the SQL file with this password) |
    | `"Port"` | `_Integer` | `3306` | Port mariadb is listening on |
    | `"BaseURL"` | `_String` | `"mariadb"` | Base URL for mariadb connection |
    | `"TemplateParameters"` | `_Association` | `Association[]` | Additional string template parameters used inside the SQL file |

---

- ### WebappDatabaseConnect (alias: makeDBConnection)
  - #### Usage
    | Form | Description |
    |------|-------------|
    | `WebappDatabaseConnect[]` | Creates a connection to the mariadb |
    | `WebappDatabaseConnect[dbName_]` | Creates a connection to the database `dbName` |

  - #### Options
    | Option | Pattern | Default | Description |
    |--------|---------|---------|-------------|
    | `"Username"` | `_String` | `"admin"` | Username used to connect to the database |
    | `"Password"` | `_String` | `SystemCredential["db-pass"]` | Password used to connect to the database |
    | `"UseConnectionPool"` | `_?BooleanQ` | `True` | Use mariadb connection pool |
    | `"BaseURL"` | `_String` | `"mariadb"` | Base URL for mariadb connection |
    | `"Port"` | `_Integer` | `3306` | Port mariadb is listening on |

---
