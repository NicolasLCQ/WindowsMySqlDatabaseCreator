@echo off
setlocal enabledelayedexpansion
set current_path=%~dp0

::database configuration
set DATABASE_SERVER_PORT=3005
:: Don't change USER If you want an other user create it manually after connecting with root.
set DATABASE_SERVER_USER=root
::strongly recommended to change this password for a stronger one !
set DATABASE_SERVER_PASSWORD=root

::working dir
set DATABASE_DIRECTORY_DESTINATION_PATH=%current_path%sqlServer
set DATABASE_DATA_DIRECTORY_DESTINATION_PATH=%current_path%bdd_data

::working temporary file
set zipName=MySqlServer.zip

::outside if else because batch is a shity thing
set "password_prefix=A temporary password is generated for %DATABASE_SERVER_USER%@localhost: "


if %DATABASE_DIRECTORY_DESTINATION_PATH% == %current_path% (
  echo DATABASE_DIRECTORY_DESTINATION_PATH cannot be the current path : %current_path%
  pause
  exit
)

if %DATABASE_DATA_DIRECTORY_DESTINATION_PATH% == %current_path% (
  echo DATABASE_DATA_DIRECTORY_DESTINATION_PATH cannot be the current path : %current_path%
  pause
  exit
)


if exist "%DATABASE_DIRECTORY_DESTINATION_PATH%" (
  echo Directory %DATABASE_DIRECTORY_DESTINATION_PATH% already exist. Skipping installation ...
) else (
  echo downloading sql server archive from oracle website : https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.34-winx64.zip to %current_path%%zipName% ...
  powershell -Command "& { Invoke-WebRequest 'https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.34-winx64.zip' -OutFile '%zipName%' }"

  echo unzip %current_path%%zipName% to %DATABASE_DIRECTORY_DESTINATION_PATH%...
  powershell Expand-Archive -LiteralPath "%zipName%" -DestinationPath "%DATABASE_DIRECTORY_DESTINATION_PATH%"

  echo taking zip content to %DATABASE_DIRECTORY_DESTINATION_PATH% ... 
  xcopy "%DATABASE_DIRECTORY_DESTINATION_PATH%\mysql-8.0.34-winx64\*" "%DATABASE_DIRECTORY_DESTINATION_PATH%\" /E /H /C /Y

  echo deleting :
  echo unzip file...
  rd /S /Q "%DATABASE_DIRECTORY_DESTINATION_PATH%\mysql-8.0.34-winx64"
  echo zip file ...
  del %zipName%
)


if exist "%DATABASE_DATA_DIRECTORY_DESTINATION_PATH%" (
  echo Directory %DATABASE_DATA_DIRECTORY_DESTINATION_PATH% already exist. Skipping initialisation ...
) else (
  
  echo initialize %DATABASE_DATA_DIRECTORY_DESTINATION_PATH% directory with database data
  powershell %DATABASE_DIRECTORY_DESTINATION_PATH%/bin/mysqld.exe --basedir=%DATABASE_DIRECTORY_DESTINATION_PATH% --datadir=%DATABASE_DATA_DIRECTORY_DESTINATION_PATH% --initialize --user=%DATABASE_SERVER_USER%

  echo geting the errors file from %DATABASE_DATA_DIRECTORY_DESTINATION_PATH% to %current_path% to prevent rights trouble
  cd %DATABASE_DATA_DIRECTORY_DESTINATION_PATH%
  xcopy "*.err" "%current_path%" /Y
  cd %current_path%

  echo looking for temporary password
  
  echo pw pref = !password_prefix!
  for /f "tokens=*" %%a in ('findstr /c:"!password_prefix!" "*.err"') do (
    set "password_line=%%a"
    set "temporary_password=!password_line:*%password_prefix%=!"
  )

  if defined password_line (
      echo Temporary password : !temporary_password!
  ) else (
      echo Temporary password not found.
      echo Database initialisation failed ...
      echo deleting error files ...
      del *.err
      pause
      exit
  )

  echo deleting error files ...
  del *.err

  echo Initialize MySql with super user %DATABASE_SERVER_USER%
  start %DATABASE_DIRECTORY_DESTINATION_PATH%/bin/mysqld.exe --basedir=%DATABASE_DIRECTORY_DESTINATION_PATH% --datadir=%DATABASE_DATA_DIRECTORY_DESTINATION_PATH% --initialize --user=%DATABASE_SERVER_USER%

  echo start Mysql Server on new terminal
  start %DATABASE_DIRECTORY_DESTINATION_PATH%/bin/mysqld.exe --basedir=%DATABASE_DIRECTORY_DESTINATION_PATH% --datadir=%DATABASE_DATA_DIRECTORY_DESTINATION_PATH% --console --port=%DATABASE_SERVER_PORT%
  
  echo waiting 30 secs to be sure database server is launch
  timeout /t 30

  echo setting configurated password : %DATABASE_SERVER_PASSWORD% as new password for configurated user : %DATABASE_SERVER_USER%
  %DATABASE_DIRECTORY_DESTINATION_PATH%/bin/mysql.exe -u%DATABASE_SERVER_USER% -p!temporary_password! --port=%DATABASE_SERVER_PORT% --execute="ALTER USER '%DATABASE_SERVER_USER%'@'localhost' IDENTIFIED WITH mysql_native_password BY '%DATABASE_SERVER_PASSWORD%';" --connect-expired-password

  echo ----------------------------------------------------------------------------------------------------------------------------------------
  echo MYSQL SERVER INITIALAZED FOR %DATABASE_SERVER_USER% WITH PASSWORD : %DATABASE_SERVER_PASSWORD%

  pause
)
::launch database server if needed
%DATABASE_DIRECTORY_DESTINATION_PATH%/bin/mysqld.exe --basedir=%DATABASE_DIRECTORY_DESTINATION_PATH% --datadir=%DATABASE_DATA_DIRECTORY_DESTINATION_PATH% --console --port=%DATABASE_SERVER_PORT%  --verbose

endlocal
::Everything done ...
exit