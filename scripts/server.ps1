param(
    [int]$Port = 8088,
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "cms_helper.ps1")

$PublicDir = Join-Path $ProjectRoot "public"
$DataDir = Join-Path $ProjectRoot "data"
$CollectScript = Join-Path $PSScriptRoot "collect.ps1"
$SessionsPath = Join-Path $DataDir "sessions.json"

if (-not (Test-Path (Join-Path $DataDir "news.json"))) {
    & $CollectScript -ProjectRoot $ProjectRoot | Out-Null
} else {
    Sync-PublicJsBundle -ProjectRoot $ProjectRoot
}

$script:Sessions = @{}
if (Test-Path $SessionsPath) {
    $savedSessions = Read-Utf8Json -Path $SessionsPath
    if ($savedSessions) {
        $script:Sessions = Convert-PropsToHashtable -Obj $savedSessions
    }
}

function Save-Sessions {
    $obj = New-Object PSObject
    foreach ($k in $script:Sessions.Keys) {
        Add-Member -InputObject $obj -MemberType NoteProperty -Name $k -Value $script:Sessions[$k] -Force
    }
    Write-Utf8Json -Path $SessionsPath -Object $obj -Depth 4
}

function Read-RequestJson {
    param($Request)
    $reader = New-Object System.IO.StreamReader($Request.InputStream, [System.Text.Encoding]::UTF8)
    $raw = $reader.ReadToEnd()
    $reader.Close()
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    return ($raw | ConvertFrom-Json)
}

function Send-Json {
    param($Response, $Data, [int]$StatusCode = 200)
    $json = ConvertTo-Json -InputObject $Data -Depth 10
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $Response.ContentType = "application/json; charset=utf-8"
    $Response.Headers.Add("Cache-Control", "no-store")
    $Response.StatusCode = $StatusCode
    $Response.OutputStream.Write($bytes, 0, $bytes.Length)
}

function Get-RequestToken {
    param($Request)
    $tok = $Request.Headers["X-Admin-Token"]
    if (-not [string]::IsNullOrWhiteSpace($tok)) { return $tok.Trim() }
    $auth = $Request.Headers["Authorization"]
    if (-not [string]::IsNullOrWhiteSpace($auth) -and $auth.StartsWith("Bearer ")) {
        return $auth.Substring(7).Trim()
    }
    return $null
}

function Test-AdminAuthorized {
    param($Request)
    $tok = Get-RequestToken -Request $Request
    if ([string]::IsNullOrWhiteSpace($tok)) { return $false }
    return $script:Sessions.ContainsKey($tok)
}

$Listener = New-Object System.Net.HttpListener
$Prefix = "http://localhost:$Port/"
$Listener.Prefixes.Add($Prefix)
$Listener.Start()

Write-Host "Club Africain News server listening at $Prefix"
Write-Host "Public site: http://localhost:$Port/"
Write-Host "Admin console: http://localhost:$Port/admin"
Write-Host "Press Ctrl+C to stop."

$MimeTypes = @{
    ".html" = "text/html; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".svg"  = "image/svg+xml"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".webp" = "image/webp"
    ".ico"  = "image/x-icon"
}

try {
    while ($Listener.IsListening) {
        $Context = $Listener.GetContext()
        $Req = $Context.Request
        $Res = $Context.Response
        $Path = $Req.Url.AbsolutePath
        $Method = $Req.HttpMethod.ToUpperInvariant()

        try {
            # --- PUBLIC API ---
            if (($Path -eq "/api/public/news" -or $Path -eq "/api/news") -and $Method -eq "GET") {
                $payload = Build-PublicPayload -ProjectRoot $ProjectRoot
                Send-Json -Response $Res -Data $payload
            }

            # --- ADMIN AUTH ---
            elseif ($Path -eq "/api/admin/login" -and $Method -eq "POST") {
                $body = Read-RequestJson -Request $Req
                $site = Get-SiteConfig -ProjectRoot $ProjectRoot
                $pwd = if ($body -and $body.password) { [string]$body.password } else { "" }
                $hash = Get-Sha256Hex -Text $pwd
                if ($hash -eq [string]$site.adminPasswordSha256) {
                    $token = [guid]::NewGuid().ToString("N") + [guid]::NewGuid().ToString("N")
                    $script:Sessions[$token] = (Get-Date).ToString("o")
                    Save-Sessions
                    Send-Json -Response $Res -Data ([PSCustomObject]@{ ok = $true; token = $token })
                } else {
                    Send-Json -Response $Res -Data ([PSCustomObject]@{ ok = $false; error = "Mot de passe invalide." }) -StatusCode 401
                }
            }
            elseif ($Path -eq "/api/admin/logout" -and $Method -eq "POST") {
                $tok = Get-RequestToken -Request $Req
                if ($tok -and $script:Sessions.ContainsKey($tok)) {
                    $script:Sessions.Remove($tok)
                    Save-Sessions
                }
                Send-Json -Response $Res -Data ([PSCustomObject]@{ ok = $true })
            }
            elseif ($Path -eq "/api/admin/me" -and $Method -eq "GET") {
                if (Test-AdminAuthorized -Request $Req) {
                    Send-Json -Response $Res -Data ([PSCustomObject]@{ ok = $true })
                } else {
                    Send-Json -Response $Res -Data ([PSCustomObject]@{ ok = $false }) -StatusCode 401
                }
            }

            # --- PROTECTED ADMIN API ---
            elseif ($Path.StartsWith("/api/admin/")) {
                if (-not (Test-AdminAuthorized -Request $Req)) {
                    Send-Json -Response $Res -Data ([PSCustomObject]@{ ok = $false; error = "Authentification requise." }) -StatusCode 401
                }
                elseif ($Path -eq "/api/admin/state" -and $Method -eq "GET") {
                    Send-Json -Response $Res -Data (Build-AdminPayload -ProjectRoot $ProjectRoot)
                }
                elseif ($Path -eq "/api/admin/collect" -and $Method -eq "POST") {
                    $collectOutput = (& $CollectScript -ProjectRoot $ProjectRoot | Out-String)
                    $state = Build-AdminPayload -ProjectRoot $ProjectRoot
                    Add-Member -InputObject $state -MemberType NoteProperty -Name "collectLog" -Value $collectOutput -Force
                    Send-Json -Response $Res -Data $state
                }
                elseif ($Path -eq "/api/admin/articles" -and $Method -eq "POST") {
                    $body = Read-RequestJson -Request $Req
                    $cms = Get-CmsData -ProjectRoot $ProjectRoot
                    $manualList = New-Object System.Collections.Generic.List[object]
                    foreach ($m in @($cms.manualArticles)) { $manualList.Add($m) }
                    $overridesMap = Convert-PropsToHashtable -Obj $cms.overrides
                    $deletedList = @($cms.deletedIds)

                    $newId = "ed_" + ([guid]::NewGuid().ToString("N").Substring(0, 10))
                    $nowIso = (Get-Date).ToString("o")
                    $article = [PSCustomObject]@{
                        id = $newId
                        title = [string]$body.title
                        summary = [string]$body.summary
                        body = [string]$body.body
                        url = [string]$body.url
                        thumbnail = [string]$body.thumbnail
                        publishedAt = if ($body.publishedAt) { [string]$body.publishedAt } else { $nowIso }
                        lang = if ($body.lang) { [string]$body.lang } else { "fr" }
                        topic = if ($body.topic) { [string]$body.topic } else { "official" }
                        isVideo = [bool]$body.isVideo
                        sourceId = "ca_editorial"
                        sourceName = if ($body.sourceName) { [string]$body.sourceName } else { "Rédaction Club Africain News" }
                        sourceNameAr = if ($body.sourceNameAr) { [string]$body.sourceNameAr } else { "تحرير أخبار النادي الإفريقي" }
                        sourceDomain = "clubafricain.news"
                        score = 98
                        verification = if ($body.verification) { [string]$body.verification } else { "official" }
                        status = if ($body.status) { [string]$body.status } else { "published" }
                        featured = [bool]$body.featured
                    }
                    $manualList.Insert(0, $article)
                    Save-CmsData -ProjectRoot $ProjectRoot -ManualList $manualList.ToArray() -OverridesMap $overridesMap -DeletedList $deletedList
                    Sync-PublicJsBundle -ProjectRoot $ProjectRoot
                    Send-Json -Response $Res -Data (Build-AdminPayload -ProjectRoot $ProjectRoot)
                }
                elseif ($Path -eq "/api/admin/articles/bulk" -and $Method -eq "POST") {
                    $body = Read-RequestJson -Request $Req
                    $action = [string]$body.action
                    $cms = Get-CmsData -ProjectRoot $ProjectRoot
                    $manualList = @($cms.manualArticles)
                    $overridesMap = Convert-PropsToHashtable -Obj $cms.overrides
                    $deletedList = @($cms.deletedIds)
                    $all = @(Get-MergedArticles -ProjectRoot $ProjectRoot | Where-Object { $null -ne $_ })

                    foreach ($art in $all) {
                        $apply = $false
                        $newStatus = $art.status
                        $newFeatured = $art.featured

                        if ($action -eq "hide_rumors" -and $art.verification -eq "rumor") {
                            $apply = $true; $newStatus = "hidden"
                        } elseif ($action -eq "publish_verified" -and ($art.verification -eq "official" -or $art.verification -eq "verified")) {
                            $apply = $true; $newStatus = "published"
                        } elseif ($action -eq "publish_all") {
                            $apply = $true; $newStatus = "published"
                        } elseif ($action -eq "unfeature_all" -and $art.featured) {
                            $apply = $true; $newFeatured = $false
                        }

                        if ($apply) {
                            $existing = if ($overridesMap.ContainsKey($art.id)) { Convert-PropsToHashtable -Obj $overridesMap[$art.id] } else { @{} }
                            $existing["status"] = $newStatus
                            $existing["featured"] = $newFeatured
                            $ovObj = New-Object PSObject
                            foreach ($k in $existing.Keys) { Add-Member -InputObject $ovObj -MemberType NoteProperty -Name $k -Value $existing[$k] -Force }
                            $overridesMap[$art.id] = $ovObj
                        }
                    }

                    Save-CmsData -ProjectRoot $ProjectRoot -ManualList $manualList -OverridesMap $overridesMap -DeletedList $deletedList
                    Sync-PublicJsBundle -ProjectRoot $ProjectRoot
                    Send-Json -Response $Res -Data (Build-AdminPayload -ProjectRoot $ProjectRoot)
                }
                elseif ($Path -match "^/api/admin/articles/([^/]+)$") {
                    $artId = [System.Uri]::UnescapeDataString($Matches[1])
                    $cms = Get-CmsData -ProjectRoot $ProjectRoot
                    $manualList = New-Object System.Collections.Generic.List[object]
                    foreach ($m in @($cms.manualArticles)) { $manualList.Add($m) }
                    $overridesMap = Convert-PropsToHashtable -Obj $cms.overrides
                    $deletedList = New-Object System.Collections.Generic.List[string]
                    foreach ($d in @($cms.deletedIds)) { $deletedList.Add([string]$d) }

                    if ($Method -eq "PUT") {
                        $body = Read-RequestJson -Request $Req
                        $existing = if ($overridesMap.ContainsKey($artId)) { Convert-PropsToHashtable -Obj $overridesMap[$artId] } else { @{} }
                        foreach ($field in @("status", "featured", "title", "summary", "body", "url", "thumbnail", "topic", "verification", "lang")) {
                            if ($null -ne $body.PSObject.Properties[$field]) {
                                $existing[$field] = $body.$field
                            }
                        }
                        $existing["updatedAt"] = (Get-Date).ToString("o")
                        $ovObj = New-Object PSObject
                        foreach ($k in $existing.Keys) {
                            Add-Member -InputObject $ovObj -MemberType NoteProperty -Name $k -Value $existing[$k] -Force
                        }
                        $overridesMap[$artId] = $ovObj
                        Save-CmsData -ProjectRoot $ProjectRoot -ManualList $manualList.ToArray() -OverridesMap $overridesMap -DeletedList $deletedList.ToArray()
                        Sync-PublicJsBundle -ProjectRoot $ProjectRoot
                        Send-Json -Response $Res -Data (Build-AdminPayload -ProjectRoot $ProjectRoot)
                    }
                    elseif ($Method -eq "DELETE") {
                        $foundManual = $false
                        for ($i = $manualList.Count - 1; $i -ge 0; $i--) {
                            if ([string]$manualList[$i].id -eq $artId) {
                                $manualList.RemoveAt($i)
                                $foundManual = $true
                            }
                        }
                        if ($overridesMap.ContainsKey($artId)) {
                            $overridesMap.Remove($artId)
                        }
                        if (-not $foundManual -and -not ($deletedList -contains $artId)) {
                            $deletedList.Add($artId)
                        }
                        Save-CmsData -ProjectRoot $ProjectRoot -ManualList $manualList.ToArray() -OverridesMap $overridesMap -DeletedList $deletedList.ToArray()
                        Sync-PublicJsBundle -ProjectRoot $ProjectRoot
                        Send-Json -Response $Res -Data (Build-AdminPayload -ProjectRoot $ProjectRoot)
                    }
                    else {
                        Send-Json -Response $Res -Data ([PSCustomObject]@{ error = "Method Not Allowed" }) -StatusCode 405
                    }
                }
                elseif ($Path -eq "/api/admin/site" -and $Method -eq "PUT") {
                    $body = Read-RequestJson -Request $Req
                    $site = Get-SiteConfig -ProjectRoot $ProjectRoot
                    foreach ($field in @("siteTitleFr", "siteTitleAr", "siteSubtitleFr", "siteSubtitleAr", "breakingEnabled", "breakingFr", "breakingAr", "breakingUrl", "matchBanner", "moderation")) {
                        if ($null -ne $body.PSObject.Properties[$field]) {
                            Add-Member -InputObject $site -MemberType NoteProperty -Name $field -Value $body.$field -Force
                        }
                    }
                    if ($body.newPassword -and -not [string]::IsNullOrWhiteSpace([string]$body.newPassword)) {
                        $newHash = Get-Sha256Hex -Text ([string]$body.newPassword)
                        Add-Member -InputObject $site -MemberType NoteProperty -Name "adminPasswordSha256" -Value $newHash -Force
                    }
                    Write-Utf8Json -Path (Join-Path $ProjectRoot "config\site.json") -Object $site -Depth 10
                    Sync-PublicJsBundle -ProjectRoot $ProjectRoot
                    Send-Json -Response $Res -Data (Build-AdminPayload -ProjectRoot $ProjectRoot)
                }
                elseif ($Path -match "^/api/admin/sources/([^/]+)$" -and $Method -eq "PUT") {
                    $srcId = [System.Uri]::UnescapeDataString($Matches[1])
                    $body = Read-RequestJson -Request $Req
                    $sourcesPath = Join-Path $ProjectRoot "config\sources.json"
                    $sourcesCfg = Read-Utf8Json -Path $sourcesPath
                    $found = $false
                    foreach ($s in $sourcesCfg.sources) {
                        if ([string]$s.id -eq $srcId) {
                            foreach ($field in @("name", "nameAr", "url", "category", "lang", "accessMode", "accessModeAr", "F", "R", "C", "D", "B")) {
                                if ($null -ne $body.PSObject.Properties[$field]) {
                                    Add-Member -InputObject $s -MemberType NoteProperty -Name $field -Value $body.$field -Force
                                }
                            }
                            $base = [Math]::Round(([double]$s.F * 0.30) + ([double]$s.R * 0.25) + ([double]$s.C * 0.20) + ([double]$s.D * 0.15) + ([double]$s.B * 0.10))
                            Add-Member -InputObject $s -MemberType NoteProperty -Name "baseScore" -Value ([int]$base) -Force
                            $found = $true
                            break
                        }
                    }
                    if (-not $found) {
                        Send-Json -Response $Res -Data ([PSCustomObject]@{ error = "Source introuvable" }) -StatusCode 404
                    } else {
                        Write-Utf8Json -Path $sourcesPath -Object $sourcesCfg -Depth 10
                        Send-Json -Response $Res -Data (Build-AdminPayload -ProjectRoot $ProjectRoot)
                    }
                }
                elseif ($Path -eq "/api/admin/feeds" -and $Method -eq "POST") {
                    $body = Read-RequestJson -Request $Req
                    $sourcesPath = Join-Path $ProjectRoot "config\sources.json"
                    $sourcesCfg = Read-Utf8Json -Path $sourcesPath
                    $feedList = New-Object System.Collections.Generic.List[object]
                    foreach ($f in @($sourcesCfg.feeds)) { $feedList.Add($f) }
                    $feedId = if ($body.id) { ([string]$body.id).Trim() } else { "feed_" + ([guid]::NewGuid().ToString("N").Substring(0, 6)) }
                    $newFeed = [PSCustomObject]@{
                        id = $feedId
                        type = if ($body.type) { [string]$body.type } else { "rss" }
                        lang = if ($body.lang) { [string]$body.lang } else { "fr" }
                        url = [string]$body.url
                        sourceId = if ($body.sourceId) { [string]$body.sourceId } else { "google_news_fr" }
                        filterRequired = if ($null -ne $body.filterRequired) { [bool]$body.filterRequired } else { $true }
                        enabled = $true
                    }
                    $feedList.Add($newFeed)
                    Add-Member -InputObject $sourcesCfg -MemberType NoteProperty -Name "feeds" -Value ([object[]]$feedList.ToArray()) -Force
                    Write-Utf8Json -Path $sourcesPath -Object $sourcesCfg -Depth 10
                    Send-Json -Response $Res -Data (Build-AdminPayload -ProjectRoot $ProjectRoot)
                }
                elseif ($Path -match "^/api/admin/feeds/([^/]+)$") {
                    $feedId = [System.Uri]::UnescapeDataString($Matches[1])
                    $sourcesPath = Join-Path $ProjectRoot "config\sources.json"
                    $sourcesCfg = Read-Utf8Json -Path $sourcesPath
                    $feedList = New-Object System.Collections.Generic.List[object]
                    foreach ($f in @($sourcesCfg.feeds)) { $feedList.Add($f) }

                    if ($Method -eq "PUT") {
                        $body = Read-RequestJson -Request $Req
                        foreach ($f in $feedList) {
                            if ([string]$f.id -eq $feedId) {
                                foreach ($field in @("type", "lang", "url", "sourceId", "filterRequired", "enabled")) {
                                    if ($null -ne $body.PSObject.Properties[$field]) {
                                        Add-Member -InputObject $f -MemberType NoteProperty -Name $field -Value $body.$field -Force
                                    }
                                }
                                break
                            }
                        }
                    }
                    elseif ($Method -eq "DELETE") {
                        for ($i = $feedList.Count - 1; $i -ge 0; $i--) {
                            if ([string]$feedList[$i].id -eq $feedId) { $feedList.RemoveAt($i) }
                        }
                    }
                    Add-Member -InputObject $sourcesCfg -MemberType NoteProperty -Name "feeds" -Value ([object[]]$feedList.ToArray()) -Force
                    Write-Utf8Json -Path $sourcesPath -Object $sourcesCfg -Depth 10
                    Send-Json -Response $Res -Data (Build-AdminPayload -ProjectRoot $ProjectRoot)
                }
                else {
                    Send-Json -Response $Res -Data ([PSCustomObject]@{ error = "Not Found" }) -StatusCode 404
                }
            }

            # --- STATIC FILES & PAGE ROUTES ---
            else {
                if ($Path -eq "/") { $Path = "/index.html" }
                elseif ($Path -eq "/admin" -or $Path -eq "/admin/") { $Path = "/admin.html" }

                $rel = $Path.TrimStart("/").Replace("/", "\")
                $targetFile = if ($rel.StartsWith("data\")) {
                    Join-Path $ProjectRoot $rel
                } else {
                    Join-Path $PublicDir $rel
                }

                if ((Test-Path $targetFile) -and -not (Get-Item $targetFile).PSIsContainer) {
                    $ext = [System.IO.Path]::GetExtension($targetFile).ToLowerInvariant()
                    $Res.ContentType = if ($MimeTypes.ContainsKey($ext)) { $MimeTypes[$ext] } else { "application/octet-stream" }
                    $bytes = [System.IO.File]::ReadAllBytes($targetFile)
                    $Res.StatusCode = 200
                    $Res.OutputStream.Write($bytes, 0, $bytes.Length)
                } else {
                    $Res.StatusCode = 404
                    $msg = [System.Text.Encoding]::UTF8.GetBytes("Not Found")
                    $Res.OutputStream.Write($msg, 0, $msg.Length)
                }
            }
        } catch {
            $Res.StatusCode = 500
            $err = [System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject ([PSCustomObject]@{ error = $_.Exception.Message })))
            $Res.ContentType = "application/json; charset=utf-8"
            $Res.OutputStream.Write($err, 0, $err.Length)
        } finally {
            $Res.Close()
        }
    }
} finally {
    $Listener.Stop()
}
