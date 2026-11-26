@echo off
cd /d "%~dp0"
echo Mise a jour des flux gratuits Club Africain (Football)...
powershell -ExecutionPolicy Bypass -File "scripts\collect.ps1"
echo Lancement du serveur sur http://localhost:8088 ...
start "" "http://localhost:8088"
powershell -ExecutionPolicy Bypass -File "scripts\server.ps1" -Port 8088
