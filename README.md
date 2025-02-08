# Web Engine Utilities

A collection of WL functions used in the WREL Wolfram Web Engine deployment.

The functions include deployment and database utility functions.


   ## Deployment Functions

- ### deployRepository
  - | Form | Description |
    |------|-------------|
    | `deployRepository[repositoryAssoc_RepoObj]` | Deploys the repository at `repositoryAssoc` to the Tomcat ROOT webapp directory |

    where:
    ```wl
    RepoObj = <|
      "link"   -> _String, (* SSH clone link to repositoy *)
      "name"   -> _String, (* Repository name *)
      "branch" -> _String, (* Branch to clone and track with CD endpoint *)
      "local"  -> _?StringMatchQ["contents/*"], (* Local directory of repo *)
      "prefix" -> _?StringMatchQ["/*"] (* The prefix used for any deployments *)
    |>
    ```

  - | Option | Pattern | Default | Description |
    |--------|---------|-------------|---------|
    | `"Initialize"` | `_?BooleanQ` | `False` | If `True`, `deployRepository` will pass the `- -init` to to any WWE deployment scripts it executes |

   ---

- ### deployBuildFolder
  - | Form | Description |
    |------|-------------|
    | `deployBuildFolder[buildDir_?DirectoryQ]` | Deploys the build files inside `buildDir` to the root of the server `https://address/` |
    | `deployBuildFolder[buildDir_?DirectoryQ, location_String]` | Deploys the build files inside `buildDir` at `https://address/{location}` |

  - | Option | Pattern | Default | Description |
    |--------|---------|-------------|---------|
    | `"WebappLocation"` | `_?DirectoryQ` | `"/usr/local/tomcat/webapps/ROOT"` | The ROOT lo cation of the tomcat webapp directory |

   ---

- ### deployExpression
  - | Form | Description |
    |------|-------------|
    | `deployExpression[expr_]` | Deploys WL `expr` to `https://address/wl/{CreateUUID[]}` |
    | `deployExpression[expr_, location_]` | Deploys WL `expr` to `https://address/wl/{l ocation}` |

  - | Option | Pattern | Default | Description |
    |--------|---------|-------------|---------|
    | `OverwriteTarget` | `_?BooleanQ` | `True` | Controls whether to overwrite existing co ntent |
    | `"WebappLocation"` | `_?DirectoryQ` | `"/usr/local/tomcat/webapps/ROOT"` | The ROOT lo cation of the tomcat webapp directory |
    | `"ActiveExtension"` | `_String` | `"wl"` | The extension on the server which handles WL  requests using the GenerateHTTPResponse servlet |

   ---

- ### addInitCode
  - | Form | Description |
    |------|-------------|
    | `addInitCode[initCode_]` | Adds `initCode` to the WWE initialization file |

  - | Option | Pattern | Default | Description |
    |--------|---------|-------------|---------|
    | `"InitFile"` | `_?FileExistsQ` | `"/usr/share/Wolfram/Kernel/init.m"` | Location of the Wolfram `init.m` file |

- ### addSupervisorProgram
 -  | Form | Description |
    |------|-------------|
    | `addSupervisorProgram[command_String, name_String]` | Adds program definition to su pervisord file under the name `name` with command `command` |

  - | Option | Pattern | Default | Description |
    |--------|---------|-------------|---------|
    | `"AutoStart"` | `_?BooleanQ` | `True` | Autostart the program |
    | `"AutoRestart"` | `_?BooleanQ` | `True` | AutoRestart the program in the case of anm un expected crash |
    | `"StdErrLogFile"` | `_?FileExistsQ` | `"/dev/stderr"` | File to pipe stderr to |
    | `"StdOutLogFile"` | `_?FileExistsQ` | `"/dev/stdout"` | File to pipe stdout to |

   ---

   ## Database Functions

- ### initialiseDatabase
  - | Form | Description |
    |------|-------------|
    | `initialiseDatabase[sqlFile_]` | Initializes the database by executing the SQL commands in `sqlFile` |

  - | Option | Pattern | Default | Description |
    |--------|------|---------|----------------|
    | `"RootPassword"` | `_String` | `SystemCredential["db-pass"]` | Password used for root connections to mariadb |
    | `"DatabasePassword"` | `_String` | `SystemCredential["db-pass"]` | Password that will be used to connect to the created database (Uses string replacement rules to replace any \`dbPass\` in the SQL file with this password ) |
    | `"Port"` | `_Integer` | `3306` | Port mariadb is listening on |

   ---

- ### makeDBConnection
  - | Form | Description |
    |------|-------------|
    | `makeDBConnection[]` | Creates a connection to the mariadb |
    | `makeDBConnection[dbName_]` | Creates a connection to the database `dbName` |

  - | Option | Pattern | Default | Description |
    |--------|------|---------|----------------|
    | `"Username"` | `_String` | `"admin"` | Username used to connect to the database |
    | `"Password"` | `_String` | `SystemCredential["db-pass"]` | Password used to connect to th e database |
    | `"UseConnectionPool"` | `_?BooleanQ` | `True` | Use mariadb connection pool |
    | `"BaseURL"` | `_String` | `"localhost"` | Base URL for mariadb connection |
    | `"Port"` | `_Integer` | `3306` | Port mariadb is listening on |

   ---
