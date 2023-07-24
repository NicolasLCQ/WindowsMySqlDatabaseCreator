@echo off
setlocal enabledelayedexpansion
set current_path=%~dp0

::database configuration
set DATABASE_HOST=127.0.0.1
set DATABASE_PORT=3001
::the database that will be automaticaly created
set DATABASE_NAME=testDatabase
::do not change user=root. if you want an other user create it manually after connecting with root.
set DATABASE_USER=root 
::strongly recommended to change this password for a stronger one !!!
set DATABASE_PASSWORD=root

::working dir
set DATABASE_DIRECTORY_NAME=sqlServer
set DATABASE_DATA_DIRECTORY_NAME=bdd_data
set DATABASE_DIRECTORY_PATH=%current_path%%DATABASE_DIRECTORY_NAME%
set DATABASE_DATA_DIRECTORY_PATH=%current_path%%DATABASE_DATA_DIRECTORY_NAME%

::working files
set zipName=MySqlServer.zip

::outside if else because batch is a shity thing
set "password_prefix=A temporary password is generated for %DATABASE_USER%@localhost: "

if %DATABASE_DIRECTORY_PATH% == %current_path% (
  echo DATABASE_DIRECTORY_PATH cannot be the current path : %current_path%
  pause
  exit
)

if %DATABASE_DATA_DIRECTORY_PATH% == %current_path% (
  echo DATABASE_DATA_DIRECTORY_PATH cannot be the current path : %current_path%
  pause
  exit
)

if %DATABASE_NAME% == 'database' (
  echo DATABASE_NAME cannot be database
)


if exist "%DATABASE_DIRECTORY_PATH%" (
  echo Directory %DATABASE_DIRECTORY_PATH% already exist. Skipping installation ...
) else (
  echo download sql server archive from oracle website to %current_path%%zipName% ...
  powershell -Command "& { Invoke-WebRequest 'https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.32-winx64.zip' -OutFile '%zipName%' }"

  echo unzip %current_path%%zipName% to %DATABASE_DIRECTORY_PATH%...
  powershell Expand-Archive -LiteralPath "%zipName%" -DestinationPath "%DATABASE_DIRECTORY_PATH%"

  echo taking zip content to %DATABASE_DIRECTORY_PATH% ... 
  xcopy "%DATABASE_DIRECTORY_PATH%\mysql-8.0.32-winx64\*" "%DATABASE_DIRECTORY_PATH%\" /E /H /C /Y

  echo deleting :
  echo unzip file...
  rd /S /Q "%DATABASE_DIRECTORY_PATH%\mysql-8.0.32-winx64"
  echo zip file ...
  del %zipName%
)


if exist "%DATABASE_DATA_DIRECTORY_PATH%" (
  echo Directory %DATABASE_DATA_DIRECTORY_PATH% already exist. Skipping initialisation ...
) else (
  
  echo initialize %DATABASE_DATA_DIRECTORY_PATH% directory with database data
  powershell %DATABASE_DIRECTORY_PATH%/bin/mysqld.exe --basedir=%DATABASE_DIRECTORY_PATH% --datadir=%DATABASE_DATA_DIRECTORY_PATH% --initialize --user=%DATABASE_USER%

  echo geting the errors file from %DATABASE_DATA_DIRECTORY_PATH% to %current_path% to prevent rights trouble
  cd %DATABASE_DATA_DIRECTORY_PATH%
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

  echo Initialize MySql with super user %DATABASE_USER%
  start %DATABASE_DIRECTORY_PATH%/bin/mysqld.exe --basedir=%DATABASE_DIRECTORY_PATH% --datadir=%DATABASE_DATA_DIRECTORY_PATH% --initialize --user=%DATABASE_USER%

  echo start Mysql Server on new terminal
  start %DATABASE_DIRECTORY_PATH%/bin/mysqld.exe --basedir=%DATABASE_DIRECTORY_PATH% --datadir=%DATABASE_DATA_DIRECTORY_PATH% --console --port=%DATABASE_PORT%

  echo setting configurated password : %DATABASE_PASSWORD% as new password for configurated user : %DATABASE_USER%
  %DATABASE_DIRECTORY_PATH%/bin/mysql.exe -u%DATABASE_USER% -p!temporary_password! --port=%DATABASE_PORT% --execute="ALTER USER '%DATABASE_USER%'@'localhost' IDENTIFIED WITH mysql_native_password BY '%DATABASE_PASSWORD%';" --connect-expired-password

  echo creating database %DATABASE_NAME%
  %DATABASE_DIRECTORY_PATH%/bin/mysql.exe -u%DATABASE_USER% -p%DATABASE_PASSWORD% --port=%DATABASE_PORT% --execute="CREATE DATABASE IF NOT EXISTS %DATABASE_NAME%;"

  echo ----------------------------------------------------------------------------------------------------------------------------------------
  echo MYSQL SERVER INITIALAZED FOR %DATABASE_USER% WITH PASSWORD : %DATABASE_PASSWORD%
  echo DATABASE %DATABASE_NAME% HAVE BEEN CREATED ON IT

  pause
)
::launch database server if needed
%DATABASE_DIRECTORY_PATH%/bin/mysqld.exe --basedir=%DATABASE_DIRECTORY_PATH% --datadir=%DATABASE_DATA_DIRECTORY_PATH% --console --port=%DATABASE_PORT% 

endlocal
::Everything done ...
exit