# Script para iniciar sesión en disco.uv.es
# SE EJECUTA AUTOMÁTICAMENTE COMO ADMINISTRADOR

# Verificar si se está ejecutando como administrador
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
    Write-Host ""
    Write-Host "=== EJECUTANDO AUTOMÁTICAMENTE COMO ADMINISTRADOR ===" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "El script requiere permisos de administrador." -ForegroundColor Cyan
    Write-Host "Relanzando automáticamente con permisos elevados..." -ForegroundColor Green
    Write-Host ""
    Write-Host "Se abrirá una nueva ventana de PowerShell como administrador." -ForegroundColor Gray
    Write-Host "Puede cerrar esta ventana una vez que se abra la nueva." -ForegroundColor Gray
    Write-Host ""
    
    try {
        # Relanzar el script como administrador
        $arguments = "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
        Start-Process powershell -Verb runAs -ArgumentList $arguments -Wait
        
        Write-Host "Script completado en modo administrador." -ForegroundColor Green
        Write-Host ""
        Read-Host "Presione Enter para cerrar esta ventana"
        exit 0
        
    } catch {
        Write-Host "Error al intentar ejecutar como administrador:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""
        Write-Host "Ejecute manualmente como administrador:" -ForegroundColor Cyan
        Write-Host "1. Haga clic derecho en PowerShell" -ForegroundColor White
        Write-Host "2. Seleccione 'Ejecutar como administrador'" -ForegroundColor White
        Write-Host "3. Ejecute: .\login_disco_uv.ps1" -ForegroundColor White
        Write-Host ""
        Read-Host "Presione Enter para salir"
        exit 1
    }
}

Write-Host "=== LOGIN DISCO.UV.ES ===" -ForegroundColor Cyan
Write-Host "✓ Ejecutándose con permisos de administrador" -ForegroundColor Green
Write-Host ""

# Solicitar credenciales
$username = Read-Host "Ingrese su usuario"
$securePassword = Read-Host "Ingrese su contraseña" -AsSecureString

# Convertir la contraseña segura a texto plano
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
$password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

try {
    Write-Host "Iniciando sesión en disco.uv.es..." -ForegroundColor Yellow
    
    # URL de login
    $loginUrl = "https://as.uv.es/cgi-bin/AuthServer?ATTREQ=disco&PAPIPOAREF=cfcad1b2976a2b6f0201cdc8d2295837&PAPIPOAURL=https%3A%2F%2Fdisco.uv.es%2Fdisco"
    
    # Crear una sesión web para mantener cookies
    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    
    Write-Host "Obteniendo página de login..." -ForegroundColor Gray
    $initialResponse = Invoke-WebRequest -Uri $loginUrl -SessionVariable session -UseBasicParsing
    
    # Buscar el formulario de login
    $formAction = ""
    if ($initialResponse.Content -match 'action="([^"]*)"') {
        $formAction = $matches[1]
        if ($formAction -notmatch "^https?://") {
            $formAction = "https://as.uv.es" + $formAction
        }
    }
    
    # Preparar datos del formulario
    $formData = @{
        username = $username
        password = $password
    }
    
    Write-Host "Enviando credenciales..." -ForegroundColor Gray
    
    # Enviar formulario de login
    $loginResponse = Invoke-WebRequest -Uri $formAction -Method Post -Body $formData -WebSession $session -UseBasicParsing
    
    # Verificar si el login fue exitoso
    $loginSuccess = $false
    
    # Verificar diferentes indicaciones de éxito
    if ($loginResponse.Content -match "disco\.uv\.es" -and $loginResponse.StatusCode -eq 200) {
        $loginSuccess = $true
    }
    
    if ($loginSuccess) {
        Write-Host ""
        Write-Host "Inicio de sesión exitoso!" -ForegroundColor Green
        Write-Host "=== SESIÓN INICIADA CORRECTAMENTE ===" -ForegroundColor Green
        
        # Navegar a la carpeta de software
        Write-Host ""
        Write-Host "Navegando a la carpeta de software..." -ForegroundColor Yellow
        $softwareUrl = "https://disco.uv.es/disco?fileman:en:principal:grupo:disco/Software/programas:cauburjassot:1a"
        
        try {
            $softwareResponse = Invoke-WebRequest -Uri $softwareUrl -WebSession $session -UseBasicParsing
            Write-Host "Accediendo a la lista de archivos..." -ForegroundColor Gray
            

            
            # Buscar archivos con múltiples patrones
            $fileLinks = @()
            
            # Patrón 1: Enlaces dentro de celdas de tabla
            $pattern1 = '<td[^>]*><a[^>]*href="[^"]*">([^<]+)</a></td>'
            $matches1 = [regex]::Matches($softwareResponse.Content, $pattern1)
            Write-Host "Patrón 1 encontró: $($matches1.Count) enlaces" -ForegroundColor Gray
            
            # Patrón 2: Enlaces más simples
            $pattern2 = '<a[^>]*href="[^"]*disco/Software/programas/([^"]*)"[^>]*>([^<]+)</a>'
            $matches2 = [regex]::Matches($softwareResponse.Content, $pattern2)
            Write-Host "Patrón 2 encontró: $($matches2.Count) enlaces" -ForegroundColor Gray
            
            # Patrón 3: Buscar todos los enlaces que contengan archivos
            $pattern3 = '<a[^>]*href="[^"]*">([^<]+\.[a-zA-Z0-9]+)</a>'
            $matches3 = [regex]::Matches($softwareResponse.Content, $pattern3)
            Write-Host "Patrón 3 encontró: $($matches3.Count) enlaces con extensión" -ForegroundColor Gray
            
            # Combinar resultados
            foreach ($match in $matches1) {
                $fileName = $match.Groups[1].Value.Trim()
                if ($fileName -match '\.[a-zA-Z0-9]+$' -and $fileName -notin $fileLinks) {
                    $fileLinks += $fileName
                }
            }
            
            foreach ($match in $matches2) {
                $fileName = $match.Groups[2].Value.Trim()
                if ($fileName -notin $fileLinks) {
                    $fileLinks += $fileName
                }
            }
            
            foreach ($match in $matches3) {
                $fileName = $match.Groups[1].Value.Trim()
                if ($fileName -match '\.(exe|msi|bat|cmd|ps1|zip|rar|7z|pdf|txt)$' -and $fileName -notin $fileLinks) {
                    $fileLinks += $fileName
                }
            }
            
            Write-Host "Total de archivos únicos encontrados: $($fileLinks.Count)" -ForegroundColor Cyan
            
            if ($fileLinks.Count -eq 0) {
                Write-Host ""
                Write-Host "No se encontraron archivos en la carpeta." -ForegroundColor Yellow

            } else {
                Write-Host "Encontrados $($fileLinks.Count) archivos. Iniciando descarga..." -ForegroundColor Green
                
                # Crear carpeta de descarga en la carpeta del usuario
                $downloadPath = [System.IO.Path]::Combine([Environment]::GetFolderPath("UserProfile"), "Downloads", "UV-Software")
                Write-Host "Usando carpeta de descarga del usuario: $downloadPath" -ForegroundColor Gray
                if (-not (Test-Path $downloadPath)) {
                    New-Item -ItemType Directory -Path $downloadPath -Force | Out-Null
                }
                
                $downloadedFiles = @()
                $skippedFiles = @()
                
                foreach ($fileName in $fileLinks) {
                    
                    # Evitar duplicados en la misma sesión
                    if ($downloadedFiles -contains $fileName) {
                        $skippedFiles += $fileName
                        Write-Host "Omitido (duplicado en sesión): $fileName" -ForegroundColor Yellow
                        continue
                    }
                    
                    $filePath = Join-Path $downloadPath $fileName
                    
                    # Si ya existe el archivo, lo sobreescribimos
                    if (Test-Path $filePath) {
                        Write-Host "Sobreescribiendo archivo existente: $fileName" -ForegroundColor Yellow
                    }
                    
                    try {
                        $fileExtension = [System.IO.Path]::GetExtension($fileName).ToLower()
                        
                        if ($fileExtension -in @('.bat', '.cmd', '.ps1')) {
                            # Para archivos de script, usar la URL con ?raw
                            $downloadUrl = "https://disco.uv.es/disco/cauburjassot/disco/Software/programas/$fileName" + "?raw"
                            Write-Host "Descargando script: $fileName" -ForegroundColor Cyan
                        } else {
                            # Para otros archivos, usar la URL directa
                            $downloadUrl = "https://disco.uv.es/disco/cauburjassot/disco/Software/programas/$fileName"
                            Write-Host "Descargando archivo: $fileName" -ForegroundColor Cyan
                        }
                        
                        # Descargar el archivo con optimización
                        $webClient = New-Object System.Net.WebClient
                        $webClient.Headers.Add("User-Agent", "PowerShell")
                        
                        # Copiar cookies de la sesión
                        if ($session.Cookies) {
                            $cookieHeader = ""
                            foreach ($cookie in $session.Cookies.GetCookies($downloadUrl)) {
                                $cookieHeader += "$($cookie.Name)=$($cookie.Value); "
                            }
                            if ($cookieHeader) {
                                $webClient.Headers.Add("Cookie", $cookieHeader.TrimEnd("; "))
                            }
                        }
                        
                        # Descargar de forma asíncrona para mayor velocidad
                        $webClient.DownloadFile($downloadUrl, $filePath)
                        $webClient.Dispose()
                        
                        $downloadedFiles += $fileName
                        Write-Host "✓ Descargado: $fileName" -ForegroundColor Green
                        
                    } catch {
                        Write-Host "✗ Error descargando $fileName : $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
                
                # Descargar antivirus de la UV (opcional)
                Write-Host ""
                Write-Host "Descargando antivirus de la UV..." -ForegroundColor Cyan
                
                try {
                    $antivirusPath = Join-Path $downloadPath "win_installer.exe"
                    
                    # Si ya existe, lo sobreescribimos
                    if (Test-Path $antivirusPath) {
                        Write-Host "Sobreescribiendo win_installer.exe existente" -ForegroundColor Yellow
                    }
                    
                    # Verificar conectividad al servidor de antivirus
                    Write-Host "Verificando acceso al servidor de antivirus..." -ForegroundColor Gray
                    
                    try {
                        $testResponse = Invoke-WebRequest -Uri "https://www.uv.es" -Method Head -UseBasicParsing -TimeoutSec 10
                        Write-Host "✓ Servidor www.uv.es accesible" -ForegroundColor Green
                    } catch {
                        Write-Host "✗ Problema accediendo a www.uv.es: $($_.Exception.Message)" -ForegroundColor Yellow
                    }
                    
                    # Intentar diferentes métodos de autenticación
                    $antivirusDownloaded = $false
                    
                    # Método 1: Con credenciales predefinidas usando autenticación HTTP básica
                    try {
                        Write-Host "Intentando descarga con credenciales predefinidas..." -ForegroundColor Gray
                        $antivirusUrl1 = "https://www.uv.es/antivirus/privado/win_installer.exe"
                        
                        # Configurar autenticación HTTP básica
                        $webClient1 = New-Object System.Net.WebClient
                        $webClient1.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
                        
                        # Crear credenciales de red
                        $credentials = New-Object System.Net.NetworkCredential("capea6", "trurozock")
                        $webClient1.Credentials = $credentials
                        
                        $webClient1.DownloadFile($antivirusUrl1, $antivirusPath)
                        $webClient1.Dispose()
                        $antivirusDownloaded = $true
                        Write-Host "✓ Descarga exitosa con credenciales predefinidas" -ForegroundColor Green
                    } catch {
                        Write-Host "✗ Falló con credenciales predefinidas: $($_.Exception.Message)" -ForegroundColor Yellow
                    }
                    
                    # Método 2: Con credenciales del usuario usando autenticación HTTP básica
                    if (-not $antivirusDownloaded) {
                        try {
                            Write-Host "Intentando descarga con credenciales del usuario..." -ForegroundColor Gray
                            $antivirusUrl2 = "https://www.uv.es/antivirus/privado/win_installer.exe"
                            
                            # Configurar autenticación HTTP básica con credenciales del usuario
                            $webClient2 = New-Object System.Net.WebClient
                            $webClient2.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
                            
                            # Crear credenciales de red con datos del usuario
                            $userCredentials = New-Object System.Net.NetworkCredential($username, $password)
                            $webClient2.Credentials = $userCredentials
                            
                            $webClient2.DownloadFile($antivirusUrl2, $antivirusPath)
                            $webClient2.Dispose()
                            $antivirusDownloaded = $true
                            Write-Host "✓ Descarga exitosa con credenciales del usuario" -ForegroundColor Green
                        } catch {
                            Write-Host "✗ Falló con credenciales del usuario: $($_.Exception.Message)" -ForegroundColor Yellow
                        }
                    }
                    
                    if ($antivirusDownloaded) {
                        $downloadedFiles += "win_installer.exe"
                        Write-Host "✓ Antivirus UV descargado correctamente" -ForegroundColor Green
                    } else {
                        Write-Host "ℹ️ No se pudo descargar el antivirus UV" -ForegroundColor Yellow
                        Write-Host "Posibles causas:" -ForegroundColor Gray
                        Write-Host "- URL del antivirus ha cambiado" -ForegroundColor Gray
                        Write-Host "- Credenciales han sido actualizadas" -ForegroundColor Gray
                        Write-Host "- Servicio temporalmente no disponible" -ForegroundColor Gray
                        Write-Host "- Restricciones de acceso desde este equipo" -ForegroundColor Gray
                        Write-Host ""
                        Write-Host "El script continuará con las descargas de disco.uv.es" -ForegroundColor Cyan
                    }
                    
                } catch {
                    Write-Host "✗ Error general descargando antivirus UV: $($_.Exception.Message)" -ForegroundColor Red
                    Write-Host "Continuando con el resto de descargas..." -ForegroundColor Cyan
                }
                
                # Descargar Java (opcional)
                Write-Host ""
                Write-Host "=== DESCARGA DE JAVA ===" -ForegroundColor Cyan
                Write-Host "¿Desea descargar Java?" -ForegroundColor Yellow
                Write-Host "1. Descargar la última versión de Java (Recomendado)" -ForegroundColor White
                Write-Host "2. No descargar Java (Se instalará manualmente)" -ForegroundColor White
                Write-Host ""
                
                $javaChoice = ""
                do {
                    $javaChoice = Read-Host "Seleccione una opción (1 o 2)"
                } while ($javaChoice -notin @("1", "2"))
                
                if ($javaChoice -eq "1") {
                    Write-Host ""
                    Write-Host "Descargando Java desde el sitio oficial de Oracle..." -ForegroundColor Cyan
                    
                    try {
                        # Usar enlace directo de descarga de Java (más confiable)
                        Write-Host "Descargando Java desde enlace directo de Oracle..." -ForegroundColor Gray
                        $javaDownloadUrl = "https://javadl.oracle.com/webapps/download/AutoDL?BundleId=252320_68ce765258164726922591683c51982c"
                        
                        Write-Host "Descargando Java desde: $javaDownloadUrl" -ForegroundColor Cyan
                        
                        # Nombre del archivo de Java
                        $javaFileName = "JavaSetup.exe"
                        $javaPath = Join-Path $downloadPath $javaFileName
                        
                        # Si ya existe, lo sobreescribimos
                        if (Test-Path $javaPath) {
                            Write-Host "Sobreescribiendo $javaFileName existente" -ForegroundColor Yellow
                        }
                        
                        # Descargar Java con optimización
                        $javaWebClient = New-Object System.Net.WebClient
                        $javaWebClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36")
                        $javaWebClient.Headers.Add("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
                        $javaWebClient.Headers.Add("Accept-Language", "es-ES,es;q=0.9,en;q=0.8")
                        $javaWebClient.Headers.Add("Accept-Encoding", "gzip, deflate")
                        
                        try {
                            Write-Host "Iniciando descarga de Java..." -ForegroundColor Gray
                            $javaWebClient.DownloadFile($javaDownloadUrl, $javaPath)
                            $javaWebClient.Dispose()
                            
                            $downloadedFiles += $javaFileName
                            Write-Host "✓ Java descargado correctamente: $javaFileName" -ForegroundColor Green
                            
                            # Verificar el tamaño del archivo descargado
                            $fileInfo = Get-Item $javaPath
                            $fileSizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
                            Write-Host "  Tamaño del archivo: $fileSizeMB MB" -ForegroundColor Gray
                            
                        } catch {
                            Write-Host "✗ Error descargando Java: $($_.Exception.Message)" -ForegroundColor Red
                            
                            # Intentar con URL alternativa más antigua pero funcional
                            Write-Host "Intentando descarga con URL de respaldo..." -ForegroundColor Gray
                            try {
                                $alternativeUrl = "https://javadl.oracle.com/webapps/download/AutoDL?BundleId=248240_8ac9e9fe04f44b7efafd3e3fb4659763"
                                $javaWebClient2 = New-Object System.Net.WebClient
                                $javaWebClient2.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
                                $javaWebClient2.Headers.Add("Accept", "application/octet-stream,*/*")
                                $javaWebClient2.DownloadFile($alternativeUrl, $javaPath)
                                $javaWebClient2.Dispose()
                                
                                $downloadedFiles += $javaFileName
                                Write-Host "✓ Java descargado con URL de respaldo: $javaFileName" -ForegroundColor Green
                                
                                # Verificar el tamaño del archivo descargado
                                $fileInfo = Get-Item $javaPath
                                $fileSizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
                                Write-Host "  Tamaño del archivo: $fileSizeMB MB" -ForegroundColor Gray
                            } catch {
                                Write-Host "✗ Error en descarga alternativa de Java: $($_.Exception.Message)" -ForegroundColor Red
                                Write-Host "Puede descargar Java manualmente desde: https://www.java.com/es/download/" -ForegroundColor Cyan
                            }
                        }
                        
                    } catch {
                        Write-Host "✗ Error accediendo a la página de Java: $($_.Exception.Message)" -ForegroundColor Red
                        Write-Host "Puede descargar Java manualmente desde: https://www.java.com/es/download/" -ForegroundColor Cyan
                    }
                } else {
                    Write-Host "Java no será descargado. Puede instalarlo manualmente más tarde." -ForegroundColor Yellow
                    Write-Host "Enlace de descarga: https://www.java.com/es/download/" -ForegroundColor Cyan
                }
                
                # Descargar Adobe Acrobat (opcional)
                Write-Host ""
                Write-Host "=== DESCARGA DE ADOBE ACROBAT ===" -ForegroundColor Cyan
                Write-Host "¿Desea descargar Adobe Acrobat?" -ForegroundColor Yellow
                Write-Host "1. Descargar Adobe Acrobat Pro (Versión de prueba completa)" -ForegroundColor White
                Write-Host "2. Descargar Adobe Reader Free (Gratuito)" -ForegroundColor White
                Write-Host "3. No descargar Adobe (Se instalará manualmente)" -ForegroundColor White
                Write-Host ""
                
                $adobeChoice = ""
                do {
                    $adobeChoice = Read-Host "Seleccione una opción (1, 2 o 3)"
                } while ($adobeChoice -notin @("1", "2", "3"))
                
                if ($adobeChoice -eq "1") {
                    Write-Host ""
                    Write-Host "Descargando Adobe Acrobat Pro (Versión de prueba)..." -ForegroundColor Cyan
                    
                    try {
                        # Enlace directo para Adobe Acrobat Pro
                        $adobeProUrl = "https://trials.adobe.com/AdobeProducts/APRO/Acrobat_HelpX/win32/Acrobat_DC_Web_x64_WWMUI.zip"
                        Write-Host "Descargando Adobe Pro desde: $adobeProUrl" -ForegroundColor Gray
                        
                        $adobeProFileName = "Acrobat_DC_Pro_x64.zip"
                        $adobeProPath = Join-Path $downloadPath $adobeProFileName
                        
                        # Si ya existe, lo sobreescribimos
                        if (Test-Path $adobeProPath) {
                            Write-Host "Sobreescribiendo $adobeProFileName existente" -ForegroundColor Yellow
                        }
                        
                        # Configurar WebClient para Adobe Pro
                        $adobeProWebClient = New-Object System.Net.WebClient
                        $adobeProWebClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36")
                        $adobeProWebClient.Headers.Add("Accept", "application/zip,application/octet-stream,*/*;q=0.8")
                        $adobeProWebClient.Headers.Add("Accept-Language", "en-US,en;q=0.9,es;q=0.8")
                        $adobeProWebClient.Headers.Add("Referer", "https://www.adobe.com/")
                        
                        Write-Host "Iniciando descarga de Adobe Acrobat Pro..." -ForegroundColor Gray
                        Write-Host "Nota: Este es un archivo grande, la descarga puede tomar varios minutos." -ForegroundColor Yellow
                        
                        $adobeProWebClient.DownloadFile($adobeProUrl, $adobeProPath)
                        $adobeProWebClient.Dispose()
                        
                        $downloadedFiles += $adobeProFileName
                        Write-Host "✓ Adobe Acrobat Pro descargado correctamente: $adobeProFileName" -ForegroundColor Green
                        
                        # Verificar el tamaño del archivo descargado
                        $fileInfo = Get-Item $adobeProPath
                        $fileSizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
                        Write-Host "  Tamaño del archivo: $fileSizeMB MB" -ForegroundColor Gray
                        Write-Host "  Nota: Descomprima el archivo ZIP para acceder al instalador" -ForegroundColor Cyan
                        
                    } catch {
                        Write-Host "✗ Error descargando Adobe Acrobat Pro: $($_.Exception.Message)" -ForegroundColor Red
                        Write-Host "Puede descargar Adobe Pro manualmente desde: https://www.adobe.com/acrobat/pdf-reader.html" -ForegroundColor Cyan
                    }
                    
                } elseif ($adobeChoice -eq "2") {
                    Write-Host ""
                    Write-Host "Descargando Adobe Reader Free..." -ForegroundColor Cyan
                    
                    try {
                        # Acceder a la página española de Adobe Reader
                        Write-Host "Accediendo a la página española de Adobe Reader..." -ForegroundColor Gray
                        $adobeReaderPageUrl = "https://get.adobe.com/es/reader/"
                        
                        # Crear una sesión web para mantener cookies
                        $adobeSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
                        
                        # Obtener la página principal en español
                        Write-Host "Obteniendo página de descarga en español..." -ForegroundColor Gray
                        $pageResponse = Invoke-WebRequest -Uri $adobeReaderPageUrl -SessionVariable adobeSession -UseBasicParsing
                        
                        Write-Host "Buscando botón de descarga específico..." -ForegroundColor Gray
                        
                        # Buscar el enlace de descarga directa basado en el contenido de la página
                        $downloadUrl = ""
                        
                        # Método 1: Buscar enlaces directos de descarga
                        $downloadPattern1 = 'href="([^"]*download[^"]*\.exe[^"]*)"'
                        if ($pageResponse.Content -match $downloadPattern1) {
                            $downloadUrl = $matches[1]
                            Write-Host "Encontrado enlace directo método 1: $downloadUrl" -ForegroundColor Gray
                        }
                        
                        # Método 2: Buscar patrón típico de Adobe
                        if (-not $downloadUrl) {
                            $downloadPattern2 = 'href="([^"]*AcroRdrDC[^"]*\.exe[^"]*)"'
                            if ($pageResponse.Content -match $downloadPattern2) {
                                $downloadUrl = $matches[1]
                                Write-Host "Encontrado enlace método 2: $downloadUrl" -ForegroundColor Gray
                            }
                        }
                        
                        # Método 3: Buscar formularios y botones
                        if (-not $downloadUrl) {
                            # Buscar formulario de descarga
                            $formPattern = '<form[^>]*action="([^"]*)"[^>]*>'
                            if ($pageResponse.Content -match $formPattern) {
                                $formAction = $matches[1]
                                Write-Host "Encontrado formulario de descarga: $formAction" -ForegroundColor Gray
                                
                                # Si es una URL relativa, hacerla absoluta
                                if ($formAction -match "^/") {
                                    $downloadUrl = "https://get.adobe.com" + $formAction
                                } elseif ($formAction -notmatch "^https?://") {
                                    $downloadUrl = "https://get.adobe.com/es/" + $formAction
                                } else {
                                    $downloadUrl = $formAction
                                }
                            }
                        }
                        
                        # Método 4: URL de descarga directa más confiable (fallback)
                        if (-not $downloadUrl) {
                            Write-Host "Usando URL de descarga directa confiable..." -ForegroundColor Yellow
                            $downloadUrl = "https://get.adobe.com/reader/download/?installer=Reader_DC_2023_008_20360_Spanish_for_Windows&os=Windows%2010&browser_type=KHTML&browser_dist=Chrome"
                        }
                        
                        $adobeReaderFileName = "AdobeReader_Installer.exe"
                        $adobeReaderPath = Join-Path $downloadPath $adobeReaderFileName
                        
                        # Si ya existe, lo sobreescribimos
                        if (Test-Path $adobeReaderPath) {
                            Write-Host "Sobreescribiendo $adobeReaderFileName existente" -ForegroundColor Yellow
                        }
                        
                        Write-Host "Descargando Adobe Reader desde: $downloadUrl" -ForegroundColor Cyan
                        
                        # Configurar WebClient con headers españoles
                        $adobeReaderWebClient = New-Object System.Net.WebClient
                        $adobeReaderWebClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
                        $adobeReaderWebClient.Headers.Add("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8")
                        $adobeReaderWebClient.Headers.Add("Accept-Language", "es-ES,es;q=0.9,en;q=0.8")
                        $adobeReaderWebClient.Headers.Add("Accept-Encoding", "gzip, deflate, br")
                        $adobeReaderWebClient.Headers.Add("Referer", "https://get.adobe.com/es/reader/")
                        $adobeReaderWebClient.Headers.Add("Sec-Fetch-Dest", "document")
                        $adobeReaderWebClient.Headers.Add("Sec-Fetch-Mode", "navigate")
                        $adobeReaderWebClient.Headers.Add("Sec-Fetch-Site", "same-origin")
                        
                        # Copiar cookies de la sesión
                        if ($adobeSession.Cookies) {
                            $cookieHeader = ""
                            foreach ($cookie in $adobeSession.Cookies.GetCookies($downloadUrl)) {
                                $cookieHeader += "$($cookie.Name)=$($cookie.Value); "
                            }
                            if ($cookieHeader) {
                                $adobeReaderWebClient.Headers.Add("Cookie", $cookieHeader.TrimEnd("; "))
                            }
                        }
                        
                        try {
                            Write-Host "Iniciando descarga de Adobe Reader Free..." -ForegroundColor Gray
                            $adobeReaderWebClient.DownloadFile($downloadUrl, $adobeReaderPath)
                            $adobeReaderWebClient.Dispose()
                            
                            # Verificar que se descargó correctamente
                            if (Test-Path $adobeReaderPath) {
                                $fileInfo = Get-Item $adobeReaderPath
                                $fileSizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
                                
                                if ($fileInfo.Length -gt 1MB) {
                                    $downloadedFiles += $adobeReaderFileName
                                    Write-Host "✓ Adobe Reader Free descargado correctamente: $adobeReaderFileName" -ForegroundColor Green
                                    Write-Host "  Tamaño del archivo: $fileSizeMB MB" -ForegroundColor Gray
                                } else {
                                    Write-Host "⚠ Archivo descargado es muy pequeño ($fileSizeMB MB), podría ser un error" -ForegroundColor Yellow
                                    Remove-Item $adobeReaderPath -Force
                                    throw "Archivo descargado inválido"
                                }
                            } else {
                                throw "No se pudo descargar el archivo"
                            }
                            
                        } catch {
                            Write-Host "✗ Error en descarga principal, intentando método alternativo..." -ForegroundColor Yellow
                            
                            # Método alternativo con enlace directo de respaldo
                            try {
                                Write-Host "Intentando con enlace alternativo..." -ForegroundColor Gray
                                $alternativeReaderUrl = "https://ardownload2.adobe.com/pub/adobe/reader/win/AcrobatDC/2300820360/AcroRdrDC2300820360_es_ES.exe"
                                
                                $adobeReaderWebClient2 = New-Object System.Net.WebClient
                                $adobeReaderWebClient2.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
                                $adobeReaderWebClient2.Headers.Add("Accept", "application/octet-stream,*/*")
                                $adobeReaderWebClient2.Headers.Add("Referer", "https://get.adobe.com/")
                                
                                $adobeReaderWebClient2.DownloadFile($alternativeReaderUrl, $adobeReaderPath)
                                $adobeReaderWebClient2.Dispose()
                                
                                if (Test-Path $adobeReaderPath) {
                                    $fileInfo = Get-Item $adobeReaderPath
                                    $fileSizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
                                    
                                    if ($fileInfo.Length -gt 1MB) {
                                        $downloadedFiles += $adobeReaderFileName
                                        Write-Host "✓ Adobe Reader descargado con método alternativo: $adobeReaderFileName" -ForegroundColor Green
                                        Write-Host "  Tamaño del archivo: $fileSizeMB MB" -ForegroundColor Gray
                                    } else {
                                        Remove-Item $adobeReaderPath -Force
                                        throw "Archivo alternativo inválido"
                                    }
                                }
                                
                            } catch {
                                Write-Host "✗ Error en descarga alternativa de Adobe Reader: $($_.Exception.Message)" -ForegroundColor Red
                                Write-Host "Puede descargar Adobe Reader manualmente desde: https://get.adobe.com/es/reader/" -ForegroundColor Cyan
                                Write-Host "Use el botón de descarga en la página web." -ForegroundColor Cyan
                            }
                        }
                        
                    } catch {
                        Write-Host "✗ Error general descargando Adobe Reader: $($_.Exception.Message)" -ForegroundColor Red
                        Write-Host "Puede descargar Adobe Reader manualmente desde: https://get.adobe.com/reader/" -ForegroundColor Cyan
                    }
                    
                } else {
                    Write-Host "Adobe Acrobat no será descargado. Puede instalarlo manualmente más tarde." -ForegroundColor Yellow
                    Write-Host "Enlaces de descarga:" -ForegroundColor Cyan
                    Write-Host "  - Adobe Reader Free: https://get.adobe.com/reader/" -ForegroundColor Cyan
                    Write-Host "  - Adobe Acrobat Pro: https://www.adobe.com/acrobat/pdf-reader.html" -ForegroundColor Cyan
                }
                
                # Mostrar resumen
                Write-Host ""
                Write-Host "=== RESUMEN DE DESCARGA ===" -ForegroundColor Green
                Write-Host "Archivos descargados: $($downloadedFiles.Count)" -ForegroundColor Green
                Write-Host "Archivos omitidos: $($skippedFiles.Count)" -ForegroundColor Yellow
                Write-Host "Carpeta de descarga: $downloadPath" -ForegroundColor Cyan
                
                if ($downloadedFiles.Count -gt 0) {
                    Write-Host ""
                    Write-Host "Archivos descargados:" -ForegroundColor Green
                    foreach ($file in $downloadedFiles) {
                        Write-Host "  - $file" -ForegroundColor White
                    }
                    
                    # Preguntar si desea instalar automáticamente
                    Write-Host ""
                    Write-Host "=== INSTALACIÓN AUTOMÁTICA ===" -ForegroundColor Cyan
                    Write-Host "¿Desea instalar automáticamente todos los programas descargados?" -ForegroundColor Yellow
                    Write-Host "1. Sí, instalar todo automáticamente (Recomendado)" -ForegroundColor White
                    Write-Host "2. No, instalar manualmente más tarde" -ForegroundColor White
                    Write-Host ""
                    
                    $installChoice = ""
                    do {
                        $installChoice = Read-Host "Seleccione una opción (1 o 2)"
                    } while ($installChoice -notin @("1", "2"))
                    
                    if ($installChoice -eq "1") {
                        Write-Host ""
                        Write-Host "=== INICIANDO PROCESO AUTOMATIZADO ===" -ForegroundColor Green
                        Write-Host ""
                        
                        # ==============================
                        # PREGUNTA SOBRE DEBLOAT
                        # ==============================
                        
                        Write-Host "=== DEBLOAT DEL SISTEMA ===" -ForegroundColor Cyan
                        Write-Host "¿Desea ejecutar el debloat del sistema antes de las instalaciones?" -ForegroundColor Yellow
                        Write-Host ""
                        Write-Host "El debloat eliminará aplicaciones innecesarias de Windows y optimizará el sistema." -ForegroundColor White
                        Write-Host "Esto es RECOMENDADO para tener un sistema más limpio y rápido." -ForegroundColor Green
                        Write-Host ""
                        Write-Host "1. Sí, ejecutar debloat ANTES de las instalaciones (Recomendado)" -ForegroundColor White
                        Write-Host "2. No, solo instalar programas sin debloat" -ForegroundColor White
                        Write-Host ""
                        
                        $debloatChoice = ""
                        do {
                            $debloatChoice = Read-Host "Seleccione una opción (1 o 2)"
                        } while ($debloatChoice -notin @("1", "2"))
                        
                        if ($debloatChoice -eq "1") {
                            Write-Host ""
                            Write-Host "Secuencia: 1) Debloat del sistema → 2) Instalación de programas" -ForegroundColor Cyan
                            Write-Host ""
                            
                            # ==============================
                            # PASO 1: EJECUTAR DEBLOAT PRIMERO
                            # ==============================
                            
                            Write-Host "========================================" -ForegroundColor Cyan
                            Write-Host "    AUTO-DEBLOAT PARA WINDOWS" -ForegroundColor White
                            Write-Host "========================================" -ForegroundColor Cyan
                            Write-Host ""
                            Write-Host "Ejecutando debloat ANTES de las instalaciones para tener un sistema limpio" -ForegroundColor Yellow
                            Write-Host ""

                        # Cargar System.Windows.Forms para SendKeys
                        try {
                            Add-Type -AssemblyName System.Windows.Forms
                            Write-Host "Sistema de automatizacion cargado correctamente" -ForegroundColor Green
                        } catch {
                            Write-Host "ERROR: No se pudo cargar System.Windows.Forms" -ForegroundColor Red
                            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
                            Write-Host "Continuando sin automatización de teclas..." -ForegroundColor Yellow
                        }

                        Write-Host ""
                        Write-Host "=== INICIANDO DEBLOAT AUTOMATIZADO ===" -ForegroundColor Green
                        Write-Host ""

                        try {
                            Write-Host "Descargando y ejecutando debloat desde: https://debloat.raphi.re/" -ForegroundColor Cyan
                            Write-Host "Esto puede tomar unos momentos..." -ForegroundColor Gray
                            Write-Host ""
                            
                            # Obtener procesos de PowerShell actuales antes del debloat
                            $initialPowerShellProcesses = Get-Process -Name "powershell" -ErrorAction SilentlyContinue | Select-Object Id
                            
                            Write-Host "=== EJECUTANDO DEBLOAT DIRECTAMENTE ===" -ForegroundColor Cyan
                            Write-Host "Descargando script y ejecutando en nueva ventana..." -ForegroundColor Gray
                            
                            # Ejecutar el debloat en una nueva ventana de PowerShell como administrador
                            $debloatCommand = "& ([scriptblock]::Create((Invoke-RestMethod 'https://debloat.raphi.re/')))"
                            $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-Command", $debloatCommand -Verb runAs -PassThru
                            
                            Write-Host "Proceso de debloat iniciado (PID: $($process.Id))" -ForegroundColor Yellow
                            Write-Host ""
                            
                            # Detectar cuando se abre la nueva ventana de PowerShell del debloat
                            Write-Host "=== DETECTANDO VENTANA DE DEBLOAT ===" -ForegroundColor Cyan
                            Write-Host "Esperando a que se abra la ventana de PowerShell del debloat..." -ForegroundColor Gray
                            
                            # Esperar hasta detectar la ventana de PowerShell del debloat
                            $debloatWindowReady = $false
                            $waitTimeout = 0
                            $maxWaitTime = 120 # 2 minutos máximo para detectar ventana
                            
                            Write-Host "Esperando a que se abra la ventana de PowerShell del debloat..." -ForegroundColor Gray
                            
                            # Definir API de Windows una sola vez
                            try {
                                Add-Type -TypeDefinition @"
                                    using System;
                                    using System.Runtime.InteropServices;
                                    using System.Text;
                                    public class WindowAPI {
                                        [DllImport("user32.dll")]
                                        public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
                                        [DllImport("user32.dll")]
                                        public static extern bool SetForegroundWindow(IntPtr hWnd);
                                        [DllImport("user32.dll")]
                                        public static extern IntPtr GetForegroundWindow();
                                        [DllImport("user32.dll")]
                                        public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
                                    }
"@
                            } catch {
                                Write-Host "API ya cargada o error cargándola" -ForegroundColor Gray
                            }
                            
                            while (-not $debloatWindowReady -and $waitTimeout -lt $maxWaitTime) {
                                Start-Sleep -Seconds 3
                                $waitTimeout += 3
                                
                                # Contar procesos de PowerShell actuales (excluyendo el script actual)
                                $currentPowerShellProcesses = Get-Process -Name "powershell" -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $PID }
                                $newProcessCount = $currentPowerShellProcesses.Count - $initialPowerShellProcesses.Count
                                
                                Write-Host "Ventanas detectadas: $newProcessCount (esperando al menos 1 ventana del debloat)" -ForegroundColor Gray
                                
                                # Verificar si tenemos al menos 1 nueva ventana de PowerShell del debloat
                                if ($newProcessCount -ge 1) {
                                    Write-Host "✓ Se detectó $newProcessCount nueva(s) ventana(s) de PowerShell" -ForegroundColor Green
                                    
                                    # Verificar que tenga una ventana visible y buscar la del debloat específicamente
                                    $debloatWindowFound = $false
                                    foreach ($proc in $currentPowerShellProcesses) {
                                        if ($proc.MainWindowHandle -ne [IntPtr]::Zero) {
                                            # Verificar si esta ventana parece ser del debloat
                                            try {
                                                $windowTitle = New-Object System.Text.StringBuilder 256
                                                [WindowAPI]::GetWindowText($proc.MainWindowHandle, $windowTitle, $windowTitle.Capacity) | Out-Null
                                                Write-Host "  -> Ventana encontrada: '$($windowTitle.ToString())' (PID: $($proc.Id))" -ForegroundColor Gray
                                                
                                                # Si es una ventana de PowerShell nueva, asumimos que es del debloat
                                                if ($windowTitle.ToString() -like "*PowerShell*" -or $windowTitle.ToString() -like "*Windows PowerShell*") {
                                                    $debloatWindowFound = $true
                                                    break
                                                }
                                            } catch {
                                                # Si hay error obteniendo el título, pero hay ventana visible, continuar
                                                Write-Host "  -> Ventana visible detectada (sin título)" -ForegroundColor Gray
                                                $debloatWindowFound = $true
                                                break
                                            }
                                        }
                                    }
                                    
                                    if ($debloatWindowFound) {
                                        Write-Host "✓ Ventana del debloat detectada y visible" -ForegroundColor Green
                                        $debloatWindowReady = $true
                                        
                                        Write-Host "Esperando 8 segundos adicionales para que la ventana del debloat se estabilice..." -ForegroundColor Yellow
                                        Start-Sleep -Seconds 8
                                        
                                        Write-Host "✓ Ventana del debloat lista para recibir comandos" -ForegroundColor Green
                                    } else {
                                        Write-Host "Esperando ventana visible del debloat... ($waitTimeout segundos)" -ForegroundColor Gray
                                    }
                                } else {
                                    Write-Host "Esperando ventana del debloat... ($waitTimeout segundos)" -ForegroundColor Gray
                                }
                            }
                            
                            if ($debloatWindowReady) {
                                Write-Host ""
                                Write-Host "=== INICIANDO AUTOMATIZACION DE RESPUESTAS ===" -ForegroundColor Cyan
                                Write-Host "Ventana del debloat detectada y estabilizada" -ForegroundColor Green
                                Write-Host "Secuencia automatica: 1 -> 1 -> Enter -> n -> Enter" -ForegroundColor Gray
                                Write-Host ""
                            } else {
                                Write-Host ""
                                Write-Host "⚠ TIMEOUT: No se detectó la ventana del debloat en el tiempo esperado" -ForegroundColor Yellow
                                Write-Host "Intentando enviar respuestas de todos modos..." -ForegroundColor Yellow
                                Write-Host "Asegúrese de que la ventana del debloat esté activa." -ForegroundColor Yellow
                                Write-Host ""
                            }
                            
                            # Función avanzada para encontrar y enfocar ventana del debloat
                            function Focus-DebloatWindow {
                                try {
                                    Write-Host "  -> Buscando ventana del debloat..." -ForegroundColor Gray
                                    
                                    # Buscar todas las ventanas de PowerShell (excluyendo la actual)
                                    $powerShellProcesses = Get-Process -Name "powershell" -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $PID }
                                    
                                    # Ordenar por fecha de creación (más reciente primero)
                                    $powerShellProcesses = $powerShellProcesses | Sort-Object StartTime -Descending
                                    
                                    foreach ($proc in $powerShellProcesses) {
                                        if ($proc.MainWindowHandle -ne [IntPtr]::Zero) {
                                            $windowTitle = New-Object System.Text.StringBuilder 256
                                            [WindowAPI]::GetWindowText($proc.MainWindowHandle, $windowTitle, $windowTitle.Capacity) | Out-Null
                                            
                                            Write-Host "  -> Encontrada ventana: '$($windowTitle.ToString())' (PID: $($proc.Id))" -ForegroundColor Gray
                                            
                                            # Enfocar la ventana más reciente de PowerShell
                                            if ($windowTitle.ToString() -like "*PowerShell*" -or $windowTitle.ToString() -like "*Windows PowerShell*") {
                                                Write-Host "  -> Enfocando ventana del debloat: $($windowTitle.ToString())" -ForegroundColor Green
                                                
                                                # Enfocar la ventana usando múltiples métodos
                                                [WindowAPI]::SetForegroundWindow($proc.MainWindowHandle) | Out-Null
                                                Start-Sleep -Milliseconds 200
                                                
                                                # Verificar si se enfocó correctamente
                                                $currentForeground = [WindowAPI]::GetForegroundWindow()
                                                if ($currentForeground -eq $proc.MainWindowHandle) {
                                                    Write-Host "  -> ✓ Ventana enfocada correctamente" -ForegroundColor Green
                                                    return $proc.MainWindowHandle
                                                } else {
                                                    Write-Host "  -> Intentando método alternativo..." -ForegroundColor Yellow
                                                    # Método alternativo: hacer clic en la ventana
                                                    Add-Type -AssemblyName System.Windows.Forms
                                                    [System.Windows.Forms.Application]::DoEvents()
                                                    Start-Sleep -Milliseconds 100
                                                    [WindowAPI]::SetForegroundWindow($proc.MainWindowHandle) | Out-Null
                                                    Start-Sleep -Milliseconds 300
                                                    return $proc.MainWindowHandle
                                                }
                                            }
                                        }
                                    }
                                    
                                    Write-Host "  -> No se encontró ventana específica del debloat" -ForegroundColor Yellow
                                    return [IntPtr]::Zero
                                } catch {
                                    Write-Host "  -> Error enfocando ventana: $($_.Exception.Message)" -ForegroundColor Red
                                    return [IntPtr]::Zero
                                }
                            }
                            
                            # Función para enviar teclas a ventana específica
                            function Send-KeyToWindow {
                                param(
                                    [string]$Key,
                                    [IntPtr]$WindowHandle
                                )
                                
                                try {
                                    # Enfocar ventana antes de enviar tecla
                                    if ($WindowHandle -ne [IntPtr]::Zero) {
                                        [WindowAPI]::SetForegroundWindow($WindowHandle) | Out-Null
                                        Start-Sleep -Milliseconds 100
                                    }
                                    
                                    # Verificar que la ventana esté enfocada
                                    $currentWindow = [WindowAPI]::GetForegroundWindow()
                                    if ($WindowHandle -eq [IntPtr]::Zero -or $currentWindow -eq $WindowHandle) {
                                        [System.Windows.Forms.SendKeys]::SendWait($Key)
                                        return $true
                                    } else {
                                        Write-Host "  -> Ventana no enfocada correctamente" -ForegroundColor Yellow
                                        return $false
                                    }
                                } catch {
                                    Write-Host "  -> Error enviando tecla: $($_.Exception.Message)" -ForegroundColor Red
                                    return $false
                                }
                            }
                            
                            # Secuencia de automatizacion con enfoque de ventana
                            $responses = @("1", "1", "{ENTER}", "n", "{ENTER}")
                            $responseNames = @("Opcion 1", "Opcion 1", "Enter", "Confirmacion (n)", "Enter final")
                            
                            for ($i = 0; $i -lt $responses.Length; $i++) {
                                $response = $responses[$i]
                                $name = $responseNames[$i]
                                
                                Write-Host "Enviando respuesta $($i + 1)/5: $name" -ForegroundColor Yellow
                                
                                # Buscar y enfocar la ventana del debloat
                                $debloatWindow = Focus-DebloatWindow
                                
                                if ($debloatWindow -eq [IntPtr]::Zero) {
                                    Write-Host "  -> Advertencia: No se pudo identificar ventana específica" -ForegroundColor Yellow
                                    Write-Host "  -> Intentando enviar a ventana activa..." -ForegroundColor Gray
                                }
                                
                                $success = $false
                                $attempts = 0
                                $maxAttempts = 3
                                
                                while (-not $success -and $attempts -lt $maxAttempts) {
                                    $attempts++
                                    Write-Host "  -> Intento $attempts de $maxAttempts" -ForegroundColor Gray
                                    
                                    try {
                                        # Enviar la respuesta usando la función específica
                                        if ($response -eq "{ENTER}") {
                                            $success = Send-KeyToWindow -Key "{ENTER}" -WindowHandle $debloatWindow
                                        } else {
                                            # Enviar la tecla
                                            $success = Send-KeyToWindow -Key $response -WindowHandle $debloatWindow
                                            
                                            if ($success) {
                                                # Más tiempo para el primer paso (6 segundos para el primer "1")
                                                if ($i -eq 0) {
                                                    Write-Host "  -> Esperando 6 segundos para el primer paso..." -ForegroundColor Gray
                                                    Start-Sleep -Milliseconds 6000
                                                } else {
                                                    Start-Sleep -Milliseconds 1200
                                                }
                                                
                                                # Enviar Enter
                                                $success = Send-KeyToWindow -Key "{ENTER}" -WindowHandle $debloatWindow
                                            }
                                        }
                                        
                                        if ($success) {
                                            Write-Host "  -> ✓ Respuesta enviada exitosamente: $response" -ForegroundColor Green
                                        } else {
                                            Write-Host "  -> ✗ Fallo enviando respuesta, reintentando..." -ForegroundColor Yellow
                                            Start-Sleep -Milliseconds 1000
                                        }
                                        
                                    } catch {
                                        $errorMsg = $_.Exception.Message
                                        Write-Host "  -> Error en intento $attempts`: $errorMsg" -ForegroundColor Red
                                        Start-Sleep -Milliseconds 1000
                                    }
                                }
                                
                                if (-not $success) {
                                    Write-Host "  -> ⚠ No se pudo enviar la respuesta después de $maxAttempts intentos" -ForegroundColor Red
                                }
                                
                                # Esperar entre respuestas
                                Start-Sleep -Seconds 15
                            }
                            
                            Write-Host ""
                            Write-Host "=== MONITOREANDO PROGRESO ===" -ForegroundColor Cyan
                            
                            # Monitorear el proceso hasta completarse
                            $timeout = 0
                            $maxTimeout = 1800 # 30 minutos
                            
                            while (-not $process.HasExited -and $timeout -lt $maxTimeout) {
                                Start-Sleep -Seconds 30
                                $timeout += 30
                                $minutesElapsed = [math]::Round($timeout / 60, 1)
                                Write-Host "Proceso en ejecucion... ($minutesElapsed minutos transcurridos)" -ForegroundColor Gray
                                
                                # Verificar cada 2 minutos si necesita mas interaccion
                                if ($timeout % 120 -eq 0) {
                                    Write-Host "Enviando Enter adicional por seguridad..." -ForegroundColor Yellow
                                    try {
                                        [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
                                    } catch {
                                        Write-Host "Error enviando Enter adicional: $($_.Exception.Message)" -ForegroundColor Red
                                    }
                                }
                            }
                            
                            # Verificar resultado del proceso
                            if ($process.HasExited) {
                                Write-Host ""
                                if ($process.ExitCode -eq 0) {
                                    Write-Host "DEBLOAT COMPLETADO EXITOSAMENTE" -ForegroundColor Green
                                } else {
                                    Write-Host "DEBLOAT COMPLETADO CON CÓDIGO: $($process.ExitCode)" -ForegroundColor Yellow
                                }
                            } else {
                                Write-Host ""
                                Write-Host "TIMEOUT: El debloat excedio el tiempo maximo (30 minutos)" -ForegroundColor Red
                                Write-Host "Terminando proceso de debloat..." -ForegroundColor Yellow
                                try {
                                    $process.Kill()
                                    Write-Host "Proceso terminado." -ForegroundColor Gray
                                } catch {
                                    Write-Host "Error terminando proceso: $($_.Exception.Message)" -ForegroundColor Red
                                }
                            }
                            
                        } catch {
                            Write-Host ""
                            Write-Host "ERROR GENERAL: $($_.Exception.Message)" -ForegroundColor Red
                            Write-Host ""
                            Write-Host "Soluciones alternativas:" -ForegroundColor Cyan
                            Write-Host "1. Ejecutar manualmente:" -ForegroundColor White
                            Write-Host '   & ([scriptblock]::Create((irm "https://debloat.raphi.re/")))' -ForegroundColor Gray
                            Write-Host "2. Verificar conexion a internet" -ForegroundColor White
                            Write-Host "3. Ejecutar como administrador" -ForegroundColor White
                        }

                            Write-Host ""
                            Write-Host "========================================" -ForegroundColor Cyan
                            Write-Host "     DEBLOAT FINALIZADO - SISTEMA LIMPIO" -ForegroundColor White
                            Write-Host "========================================" -ForegroundColor Cyan
                            Write-Host ""
                            
                            # ==============================
                            # PASO 2: INSTALAR PROGRAMAS DESPUÉS DEL DEBLOAT
                            # ==============================
                            
                            Write-Host "=== INICIANDO INSTALACIÓN EN SISTEMA LIMPIO ===" -ForegroundColor Green
                            Write-Host "Ahora se procederá a instalar los programas necesarios..." -ForegroundColor Cyan
                            Write-Host ""
                        } else {
                            Write-Host ""
                            Write-Host "=== OMITIENDO DEBLOAT ===" -ForegroundColor Yellow
                            Write-Host "Continuando directamente con la instalación de programas..." -ForegroundColor Cyan
                            Write-Host ""
                            
                            Write-Host "=== INICIANDO INSTALACIÓN DE PROGRAMAS ===" -ForegroundColor Green
                            Write-Host "Instalando programas en el sistema actual..." -ForegroundColor Cyan
                            Write-Host ""
                        }
                        
                        # Fase 1: Instalar ejecutables (.exe y .msi) - JAVA PRIMERO
                        Write-Host "FASE 1: Instalando archivos ejecutables (.exe y .msi)..." -ForegroundColor Cyan
                        Write-Host "IMPORTANTE: Java se instalará ANTES que AutoFirma (dependencia requerida)" -ForegroundColor Yellow
                        Write-Host ""
                        Write-Host "ℹ️  INFORMACIÓN IMPORTANTE:" -ForegroundColor Yellow
                        Write-Host "Si la consola se queda SIN MOSTRAR cambios por más de 2 minutos," -ForegroundColor White
                        Write-Host "presione ENTER para que el proceso continúe." -ForegroundColor Green
                        Write-Host "Esto puede ocurrir si algún instalador necesita confirmación adicional." -ForegroundColor Gray
                        Write-Host ""
                        
                        $executableFiles = Get-ChildItem $downloadPath -Filter "*.exe" | Where-Object { $_.Name -ne "setup.exe" }
                        $msiFiles = Get-ChildItem $downloadPath -Filter "*.msi"
                        
                        # Ordenar archivos: Java primero, luego AutoFirma, después el resto
                        $javaFile = $executableFiles | Where-Object { $_.Name -like "*Java*" }
                        $autofirmaFile = $executableFiles | Where-Object { $_.Name -like "*AutoFirma*" -or $_.Name -like "*autofirma*" }
                        $otherFiles = $executableFiles | Where-Object { $_.Name -notlike "*Java*" -and $_.Name -notlike "*AutoFirma*" -and $_.Name -notlike "*autofirma*" }
                        
                        # Verificar dependencia Java-AutoFirma
                        if ($javaChoice -eq "2" -and $autofirmaFile) {
                            Write-Host ""
                            Write-Host "⚠ ADVERTENCIA: AutoFirma detectado pero Java será instalado manualmente" -ForegroundColor Yellow
                            Write-Host "AutoFirma requiere Java para funcionar correctamente." -ForegroundColor Yellow
                            Write-Host "AutoFirma se omitirá de la instalación automática." -ForegroundColor Red
                            Write-Host "Instale Java manualmente ANTES de instalar AutoFirma." -ForegroundColor Cyan
                            Write-Host ""
                            
                            # Mover AutoFirma a otros archivos para que no se instale automáticamente
                            $otherFiles = @($otherFiles) + @($autofirmaFile)
                            $autofirmaFile = $null
                        }
                        
                        # Crear orden de instalación: Java → AutoFirma → Otros EXE → MSI
                        $allExecutables = @()
                        if ($javaFile) { 
                            $allExecutables += $javaFile 
                            Write-Host "✓ Java incluido en instalación automática" -ForegroundColor Green
                        }
                        if ($autofirmaFile) { 
                            $allExecutables += $autofirmaFile 
                            Write-Host "✓ AutoFirma incluido en instalación automática (después de Java)" -ForegroundColor Green
                        }
                        
                        $allExecutables += $otherFiles
                        $allExecutables += $msiFiles
                        
                        foreach ($file in $allExecutables) {
                            Write-Host ""
                            Write-Host "Instalando: $($file.Name)" -ForegroundColor Yellow
                            
                            try {
                                if ($file.Extension.ToLower() -eq ".exe") {
                                    # Instalar archivo .exe con interfaz visible
                                    Write-Host "  Abriendo instalador de EXE..." -ForegroundColor Gray
                                    Write-Host "  POR FAVOR: Complete la instalación manualmente en la ventana que se abre" -ForegroundColor Yellow
                                    
                                    # Abrir instalador sin parámetros silenciosos para que sea visible
                                    $process = Start-Process -FilePath $file.FullName -PassThru
                                    
                                    Write-Host "  Instalador iniciado con PID: $($process.Id)" -ForegroundColor Cyan
                                    Write-Host "  Monitoreando proceso hasta que termine..." -ForegroundColor Gray
                                    
                                    # Monitorear el proceso hasta que termine
                                    do {
                                        Start-Sleep -Seconds 5
                                        $processStillRunning = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
                                        if ($processStillRunning) {
                                            Write-Host "  -> Instalación en curso (PID: $($process.Id))..." -ForegroundColor Gray
                                        }
                                    } while ($processStillRunning)
                                    
                                    Write-Host "  ✓ Proceso de instalación finalizado (PID: $($process.Id))" -ForegroundColor Green
                                    
                                } elseif ($file.Extension.ToLower() -eq ".msi") {
                                    # Instalar archivo .msi con interfaz visible
                                    Write-Host "  Abriendo instalador de MSI..." -ForegroundColor Gray
                                    Write-Host "  POR FAVOR: Complete la instalación manualmente en la ventana que se abre" -ForegroundColor Yellow
                                    
                                    # Abrir instalador MSI con interfaz visible
                                    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", "`"$($file.FullName)`"" -PassThru
                                    
                                    Write-Host "  Instalador MSI iniciado con PID: $($process.Id)" -ForegroundColor Cyan
                                    Write-Host "  Monitoreando proceso hasta que termine..." -ForegroundColor Gray
                                    
                                    # Monitorear el proceso hasta que termine
                                    do {
                                        Start-Sleep -Seconds 5
                                        $processStillRunning = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
                                        if ($processStillRunning) {
                                            Write-Host "  -> Instalación en curso (PID: $($process.Id))..." -ForegroundColor Gray
                                        }
                                    } while ($processStillRunning)
                                    
                                    Write-Host "  ✓ Proceso de instalación MSI finalizado (PID: $($process.Id))" -ForegroundColor Green
                                }
                                
                                Write-Host "  ✓ $($file.Name) - Instalación completada" -ForegroundColor Green
                                
                            } catch {
                                Write-Host "  ✗ Error instalando $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
                            }
                            
                            # Pequeña pausa entre instalaciones
                            Start-Sleep -Seconds 2
                        }
                        
                        # Fase 2: Descomprimir y manejar archivos ZIP (Adobe Acrobat)
                        Write-Host ""
                        Write-Host "FASE 2: Procesando archivos ZIP (Adobe Acrobat)..." -ForegroundColor Cyan
                        
                        $zipFiles = Get-ChildItem $downloadPath -Filter "*.zip"
                        foreach ($zipFile in $zipFiles) {
                            Write-Host ""
                            Write-Host "Procesando: $($zipFile.Name)" -ForegroundColor Yellow
                            
                            try {
                                # Crear carpeta temporal para extracción
                                $extractPath = Join-Path $downloadPath ($zipFile.BaseName + "_extracted")
                                if (Test-Path $extractPath) {
                                    Remove-Item $extractPath -Recurse -Force
                                }
                                New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
                                
                                # Descomprimir usando PowerShell nativo
                                Write-Host "  Descomprimiendo archivo ZIP..." -ForegroundColor Gray
                                Add-Type -AssemblyName System.IO.Compression.FileSystem
                                [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFile.FullName, $extractPath)
                                
                                Write-Host "  ✓ Archivo descomprimido en: $extractPath" -ForegroundColor Green
                                
                                # Buscar setup.exe en las carpetas extraídas
                                $setupFiles = Get-ChildItem $extractPath -Filter "setup.exe" -Recurse
                                
                                foreach ($setupFile in $setupFiles) {
                                    Write-Host "  Instalando setup.exe encontrado: $($setupFile.FullName)" -ForegroundColor Yellow
                                    
                                    try {
                                        # Instalar Adobe setup VISIBLE (no silencioso)
                                        Write-Host "    Abriendo instalador de Adobe (VISIBLE)..." -ForegroundColor Gray
                                        Write-Host "    El instalador de Adobe se abrirá para que pueda revisar la instalación." -ForegroundColor Cyan
                                        
                                        # Iniciar proceso visible
                                        $process = Start-Process -FilePath $setupFile.FullName -PassThru
                                        
                                        Write-Host "    Proceso de Adobe iniciado (PID: $($process.Id))" -ForegroundColor Yellow
                                        Write-Host "    Verificando que el proceso esté ejecutándose..." -ForegroundColor Gray
                                        
                                        # Verificar que el proceso se está ejecutando
                                        Start-Sleep -Seconds 3
                                        
                                        if (-not $process.HasExited) {
                                            Write-Host "    ✓ Instalador de Adobe abierto correctamente" -ForegroundColor Green
                                            Write-Host "    ℹ️  Complete la instalación manualmente en la ventana que se abrió." -ForegroundColor Cyan
                                        } else {
                                            Write-Host "    ⚠ El proceso de Adobe se cerró inmediatamente" -ForegroundColor Yellow
                                            Write-Host "    Esto puede ser normal si ya está instalado o hay un problema." -ForegroundColor Gray
                                        }
                                        
                                    } catch {
                                        Write-Host "    ✗ Error abriendo instalador de Adobe: $($_.Exception.Message)" -ForegroundColor Red
                                    }
                                }
                                
                                if ($setupFiles.Count -eq 0) {
                                    Write-Host "  ⚠ No se encontró setup.exe en el archivo ZIP" -ForegroundColor Yellow
                                }
                                
                            } catch {
                                Write-Host "  ✗ Error procesando ZIP $($zipFile.Name): $($_.Exception.Message)" -ForegroundColor Red
                            }
                        }
                        
                        # Fase 3: Ejecutar scripts (.bat, .cmd, .ps1)
                        Write-Host ""
                        Write-Host "FASE 3: Ejecutando scripts de configuración..." -ForegroundColor Cyan
                        
                        # Obtener archivos de script
                        $batFiles = Get-ChildItem $downloadPath -Filter "*.bat"
                        $cmdFiles = Get-ChildItem $downloadPath -Filter "*.cmd"
                        $ps1Files = Get-ChildItem $downloadPath -Filter "*.ps1"
                        $allScripts = @($batFiles) + @($cmdFiles) + @($ps1Files)
                        
                        foreach ($script in $allScripts) {
                            Write-Host ""
                            Write-Host "Ejecutando: $($script.Name)" -ForegroundColor Yellow
                            
                            try {
                                if ($script.Extension.ToLower() -in @(".bat", ".cmd")) {
                                    # Ejecutar archivos batch/cmd
                                    Write-Host "  Ejecutando archivo batch/cmd..." -ForegroundColor Gray
                                    $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "`"$($script.FullName)`"" -Wait -PassThru -NoNewWindow
                                    
                                } elseif ($script.Extension.ToLower() -eq ".ps1") {
                                    # Ejecutar archivos PowerShell
                                    Write-Host "  Ejecutando script PowerShell..." -ForegroundColor Gray
                                    $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass", "-File", "`"$($script.FullName)`"" -Wait -PassThru -NoNewWindow
                                }
                                
                                if ($process.ExitCode -eq 0) {
                                    Write-Host "  ✓ $($script.Name) ejecutado correctamente" -ForegroundColor Green
                                } else {
                                    Write-Host "  ⚠ $($script.Name) completado con código: $($process.ExitCode)" -ForegroundColor Yellow
                                }
                                
                            } catch {
                                Write-Host "  ✗ Error ejecutando $($script.Name): $($_.Exception.Message)" -ForegroundColor Red
                            }
                            
                            # Pequeña pausa entre ejecuciones
                            Start-Sleep -Seconds 1
                        }
                        
                        # Resumen final
                        Write-Host ""
                        Write-Host "=== INSTALACIÓN AUTOMÁTICA COMPLETADA ===" -ForegroundColor Green
                        Write-Host ""
                        Write-Host "Proceso de instalación finalizado." -ForegroundColor Cyan
                        Write-Host "Ejecutables procesados: $($allExecutables.Count)" -ForegroundColor Gray
                        Write-Host "Archivos ZIP procesados: $($zipFiles.Count)" -ForegroundColor Gray
                        Write-Host "Scripts ejecutados: $($allScripts.Count)" -ForegroundColor Gray
                        Write-Host ""
                        Write-Host "Revise los mensajes anteriores para verificar el estado de cada instalación." -ForegroundColor Yellow
                        
                    } else {
                        Write-Host ""
                        Write-Host "Instalación manual seleccionada." -ForegroundColor Yellow
                        Write-Host "Los archivos están disponibles en: $downloadPath" -ForegroundColor Cyan
                        Write-Host ""
                        Write-Host "Para instalar manualmente:" -ForegroundColor Cyan
                        Write-Host "1. Ejecute los archivos .exe y .msi" -ForegroundColor White
                        Write-Host "2. Descomprima los .zip y ejecute setup.exe" -ForegroundColor White
                        Write-Host "3. Ejecute los archivos .bat, .cmd y .ps1" -ForegroundColor White
                    }
                }
            }
            
        } catch {
            Write-Host "Error accediendo a la carpeta de software:" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
        
    } else {
        Write-Host ""
        Write-Host "Error en el inicio de sesión" -ForegroundColor Red
        Write-Host "=== ERROR EN EL INICIO DE SESIÓN ===" -ForegroundColor Red
        Write-Host "Verifique sus credenciales" -ForegroundColor Red
    }
    
} catch {
    Write-Host ""
    Write-Host "Error durante el proceso:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

# ==============================
# CREAR USUARIO LOCAL
# ==============================

Write-Host ""
Write-Host "=== CREACIÓN DE USUARIO LOCAL ===" -ForegroundColor Cyan
Write-Host "Abriendo ventana para crear un usuario local en el sistema..." -ForegroundColor Yellow
Write-Host ""

try {
    Write-Host "Ejecutando comando: start ms-cxh:localonly" -ForegroundColor Gray
    Start-Process "ms-cxh:localonly"
    Write-Host "✓ Ventana de creación de usuario local abierta correctamente" -ForegroundColor Green
    Write-Host "Complete la configuración en la ventana que se abrió." -ForegroundColor Cyan
} catch {
    Write-Host "✗ Error abriendo ventana de usuario local: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Puede abrir manualmente la configuración desde:" -ForegroundColor Yellow
    Write-Host "Configuración → Cuentas → Familia y otros usuarios → Agregar otra persona" -ForegroundColor White
}

Write-Host ""
Write-Host "=== PROCESO COMPLETADO ===" -ForegroundColor Green
Write-Host "Todas las tareas han sido ejecutadas:" -ForegroundColor White
Write-Host "✓ Descarga de software desde disco.uv.es" -ForegroundColor Green
Write-Host "✓ Instalación de programas (si se seleccionó)" -ForegroundColor Green
Write-Host "✓ Debloat del sistema (si se seleccionó)" -ForegroundColor Green
Write-Host "✓ Ventana de creación de usuario local abierta" -ForegroundColor Green
Write-Host ""
Read-Host "Presione Enter para salir"
