$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Read-Utf8Json {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    $raw = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    return ($raw | ConvertFrom-Json)
}

function Write-Utf8Json {
    param([string]$Path, $Object, [int]$Depth = 10)
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $json = ConvertTo-Json -InputObject $Object -Depth $Depth
    [System.IO.File]::WriteAllText($Path, $json, $script:Utf8NoBom)
}

function Get-Sha256Hex {
    param([string]$Text)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes([string]$Text)
    $hash = ([System.Security.Cryptography.SHA256]::Create()).ComputeHash($bytes)
    return ([System.BitConverter]::ToString($hash)).Replace("-", "").ToLowerInvariant()
}

function Convert-PropsToHashtable {
    param($Obj)
    $map = @{}
    if ($null -eq $Obj) { return $map }
    if ($Obj -is [System.Collections.IDictionary]) {
        foreach ($k in $Obj.Keys) { $map[[string]$k] = $Obj[$k] }
        return $map
    }
    foreach ($p in $Obj.PSObject.Properties) {
        $map[$p.Name] = $p.Value
    }
    return $map
}

function Get-SiteConfig {
    param([string]$ProjectRoot)
    $path = Join-Path $ProjectRoot "config\site.json"
    $cfg = Read-Utf8Json -Path $path
    if ($null -eq $cfg) {
        $cfg = [PSCustomObject]@{
            siteTitleFr = "Club Africain News"
            siteTitleAr = "أخبار النادي الإفريقي"
            siteSubtitleFr = "Le portail d'actualités football des supporters clubistes"
            siteSubtitleAr = "بوابة أخبار كرة القدم لجماهير النادي الإفريقي"
            breakingEnabled = $false
            breakingFr = ""
            breakingAr = ""
            breakingUrl = ""
            matchBanner = [PSCustomObject]@{
                enabled = $true
                badgeFr = "À SUIVRE"
                badgeAr = "الموعد القادم"
                titleFr = "Club Africain"
                titleAr = "النادي الإفريقي"
                metaFr = ""
                metaAr = ""
                ticketUrl = "https://passeportenligne.clubafricain.com"
            }
            moderation = [PSCustomObject]@{
                autoPublishMinScore = 0
                hideRumorsByDefault = $false
            }
            adminPasswordSha256 = (Get-Sha256Hex -Text "ca1920")
        }
        Write-Utf8Json -Path $path -Object $cfg
    }
    return $cfg
}

function Get-PublicSiteConfig {
    param([string]$ProjectRoot)
    $cfg = Get-SiteConfig -ProjectRoot $ProjectRoot
    return [PSCustomObject]@{
        siteTitleFr = $cfg.siteTitleFr
        siteTitleAr = $cfg.siteTitleAr
        siteSubtitleFr = $cfg.siteSubtitleFr
        siteSubtitleAr = $cfg.siteSubtitleAr
        breakingEnabled = [bool]$cfg.breakingEnabled
        breakingFr = [string]$cfg.breakingFr
        breakingAr = [string]$cfg.breakingAr
        breakingUrl = [string]$cfg.breakingUrl
        matchBanner = $cfg.matchBanner
        moderation = $cfg.moderation
    }
}

function Get-CmsData {
    param([string]$ProjectRoot)
    $path = Join-Path $ProjectRoot "data\cms.json"
    $cms = Read-Utf8Json -Path $path
    if ($null -eq $cms) {
        $cms = [PSCustomObject]@{
            manualArticles = @()
            overrides = [PSCustomObject]@{}
            deletedIds = @()
        }
        Write-Utf8Json -Path $path -Object $cms
    }
    return $cms
}

function Save-CmsData {
    param([string]$ProjectRoot, $ManualList, $OverridesMap, $DeletedList)
    $path = Join-Path $ProjectRoot "data\cms.json"
    $overridesObj = New-Object PSObject
    foreach ($k in $OverridesMap.Keys) {
        Add-Member -InputObject $overridesObj -MemberType NoteProperty -Name $k -Value $OverridesMap[$k] -Force
    }
    $payload = [PSCustomObject]@{
        manualArticles = [object[]]@($ManualList)
        overrides = $overridesObj
        deletedIds = [object[]]@($DeletedList)
    }
    Write-Utf8Json -Path $path -Object $payload -Depth 10
}

function Get-MergedArticles {
    param([string]$ProjectRoot)
    $site = Get-SiteConfig -ProjectRoot $ProjectRoot
    $news = Read-Utf8Json -Path (Join-Path $ProjectRoot "data\news.json")
    $cms = Get-CmsData -ProjectRoot $ProjectRoot

    $deletedSet = @{}
    foreach ($did in @($cms.deletedIds)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$did)) {
            $deletedSet[[string]$did] = $true
        }
    }

    $overrides = Convert-PropsToHashtable -Obj $cms.overrides
    $minScore = if ($site.moderation -and $null -ne $site.moderation.autoPublishMinScore) { [int]$site.moderation.autoPublishMinScore } else { 0 }
    $hideRumors = if ($site.moderation -and $null -ne $site.moderation.hideRumorsByDefault) { [bool]$site.moderation.hideRumorsByDefault } else { $false }

    $merged = New-Object System.Collections.Generic.List[object]

    # 1. Manual articles first
    foreach ($m in @($cms.manualArticles)) {
        if ($null -eq $m) { continue }
        $id = [string]$m.id
        if ($deletedSet.ContainsKey($id)) { continue }

        $ov = if ($overrides.ContainsKey($id)) { $overrides[$id] } else { $null }
        $status = if ($ov -and $ov.status) { [string]$ov.status } elseif ($m.status) { [string]$m.status } else { "published" }
        $featured = if ($ov -and $null -ne $ov.featured) { [bool]$ov.featured } elseif ($null -ne $m.featured) { [bool]$m.featured } else { $false }

        $merged.Add([PSCustomObject]@{
            id = $id
            title = if ($ov -and $null -ne $ov.title) { [string]$ov.title } else { [string]$m.title }
            summary = if ($ov -and $null -ne $ov.summary) { [string]$ov.summary } else { [string]$m.summary }
            body = if ($ov -and $null -ne $ov.body) { [string]$ov.body } else { [string]$m.body }
            url = if ($ov -and $null -ne $ov.url) { [string]$ov.url } else { [string]$m.url }
            thumbnail = if ($ov -and $null -ne $ov.thumbnail) { [string]$ov.thumbnail } else { [string]$m.thumbnail }
            publishedAt = [string]$m.publishedAt
            lang = if ($ov -and $ov.lang) { [string]$ov.lang } else { [string]$m.lang }
            topic = if ($ov -and $ov.topic) { [string]$ov.topic } else { [string]$m.topic }
            isVideo = [bool]$m.isVideo
            sourceId = if ($m.sourceId) { [string]$m.sourceId } else { "ca_editorial" }
            sourceName = if ($m.sourceName) { [string]$m.sourceName } else { "Rédaction Club Africain News" }
            sourceNameAr = if ($m.sourceNameAr) { [string]$m.sourceNameAr } else { "تحرير أخبار النادي الإفريقي" }
            sourceDomain = if ($m.sourceDomain) { [string]$m.sourceDomain } else { "clubafricain.news" }
            sourceCategory = "official"
            score = if ($null -ne $m.score) { [int]$m.score } else { 98 }
            verification = if ($ov -and $ov.verification) { [string]$ov.verification } elseif ($m.verification) { [string]$m.verification } else { "official" }
            corroborationCount = 0
            scoreBreakdown = [PSCustomObject]@{
                baseScore = 98
                corroborationBonus = 0
                freshnessDelta = 0
                rumorPenalty = 0
            }
            status = $status
            featured = $featured
            isManual = $true
        })
    }

    # 2. Aggregated articles
    if ($news -and $news.articles) {
        foreach ($a in @($news.articles)) {
            $id = [string]$a.id
            if ($deletedSet.ContainsKey($id)) { continue }

            $defaultStatus = "published"
            if ($hideRumors -and $a.verification -eq "rumor") {
                $defaultStatus = "hidden"
            } elseif ([int]$a.score -lt $minScore) {
                $defaultStatus = "hidden"
            }

            $ov = if ($overrides.ContainsKey($id)) { $overrides[$id] } else { $null }
            $status = if ($ov -and $ov.status) { [string]$ov.status } else { $defaultStatus }
            $featured = if ($ov -and $null -ne $ov.featured) { [bool]$ov.featured } else { $false }

            $merged.Add([PSCustomObject]@{
                id = $id
                title = if ($ov -and $null -ne $ov.title) { [string]$ov.title } else { [string]$a.title }
                summary = if ($ov -and $null -ne $ov.summary) { [string]$ov.summary } else { [string]$a.summary }
                body = if ($ov -and $null -ne $ov.body) { [string]$ov.body } else { "" }
                url = if ($ov -and $null -ne $ov.url) { [string]$ov.url } else { [string]$a.url }
                thumbnail = if ($ov -and $null -ne $ov.thumbnail) { [string]$ov.thumbnail } else { [string]$a.thumbnail }
                publishedAt = [string]$a.publishedAt
                lang = if ($ov -and $ov.lang) { [string]$ov.lang } else { [string]$a.lang }
                topic = if ($ov -and $ov.topic) { [string]$ov.topic } else { [string]$a.topic }
                isVideo = [bool]$a.isVideo
                sourceId = [string]$a.sourceId
                sourceName = [string]$a.sourceName
                sourceNameAr = [string]$a.sourceNameAr
                sourceDomain = [string]$a.sourceDomain
                sourceCategory = [string]$a.sourceCategory
                score = [int]$a.score
                verification = if ($ov -and $ov.verification) { [string]$ov.verification } else { [string]$a.verification }
                corroborationCount = [int]$a.corroborationCount
                scoreBreakdown = $a.scoreBreakdown
                status = $status
                featured = $featured
                isManual = $false
            })
        }
    }

    if ($merged.Count -eq 0) {
        return ,@()
    }
    $sorted = @($merged | Sort-Object @{Expression = "featured"; Descending = $true}, @{Expression = "publishedAt"; Descending = $true}, @{Expression = "score"; Descending = $true})
    return ,$sorted
}

function Build-PublicPayload {
    param([string]$ProjectRoot)
    $news = Read-Utf8Json -Path (Join-Path $ProjectRoot "data\news.json")
    $sourcesCfg = Read-Utf8Json -Path (Join-Path $ProjectRoot "config\sources.json")
    $publicSite = Get-PublicSiteConfig -ProjectRoot $ProjectRoot
    $allArticles = Get-MergedArticles -ProjectRoot $ProjectRoot

    $published = @($allArticles | Where-Object { $_.status -eq "published" } | ForEach-Object {
        [PSCustomObject]@{
            id = $_.id
            title = $_.title
            summary = $_.summary
            body = $_.body
            url = $_.url
            thumbnail = $_.thumbnail
            publishedAt = $_.publishedAt
            lang = $_.lang
            topic = $_.topic
            isVideo = $_.isVideo
            sourceId = $_.sourceId
            sourceName = $_.sourceName
            sourceNameAr = $_.sourceNameAr
            sourceDomain = $_.sourceDomain
            sourceCategory = $_.sourceCategory
            verification = $_.verification
            featured = $_.featured
            isManual = $_.isManual
            score = $_.score
        }
    })

    $officialLinks = @()
    if ($sourcesCfg -and $sourcesCfg.sources) {
        $officialLinks = @($sourcesCfg.sources | Where-Object {
            $_.category -eq "official" -or $_.id -in @("x_twitter", "sofascore", "transfermarkt")
        } | ForEach-Object {
            [PSCustomObject]@{
                id = $_.id
                name = $_.name
                nameAr = $_.nameAr
                domain = $_.domain
                url = $_.url
                category = $_.category
            }
        })
    }

    return [PSCustomObject]@{
        generatedAt = if ($news) { [string]$news.generatedAt } else { (Get-Date).ToString("o") }
        scope = "football-v1"
        totalArticles = $published.Count
        site = $publicSite
        officialLinks = [object[]]$officialLinks
        articles = [object[]]$published
    }
}

function Build-AdminPayload {
    param([string]$ProjectRoot)
    $news = Read-Utf8Json -Path (Join-Path $ProjectRoot "data\news.json")
    $sourcesCfg = Read-Utf8Json -Path (Join-Path $ProjectRoot "config\sources.json")
    $publicSite = Get-PublicSiteConfig -ProjectRoot $ProjectRoot
    $allArticles = @(Get-MergedArticles -ProjectRoot $ProjectRoot)

    $publishedCount = @($allArticles | Where-Object { $_.status -eq "published" }).Count
    $hiddenCount = @($allArticles | Where-Object { $_.status -eq "hidden" }).Count
    $featuredCount = @($allArticles | Where-Object { $_.featured -eq $true }).Count
    $manualCount = @($allArticles | Where-Object { $_.isManual -eq $true }).Count
    $rumorCount = @($allArticles | Where-Object { $_.verification -eq "rumor" }).Count

    $feeds = if ($sourcesCfg -and $sourcesCfg.feeds) { @($sourcesCfg.feeds) } else { @() }
    $feedStatuses = if ($news -and $news.feeds) { @($news.feeds) } else { @() }
    $statusById = @{}
    foreach ($fs in $feedStatuses) { $statusById[[string]$fs.id] = $fs }

    $mergedFeeds = @($feeds | ForEach-Object {
        $fs = $statusById[[string]$_.id]
        [PSCustomObject]@{
            id = $_.id
            type = $_.type
            lang = $_.lang
            url = $_.url
            sourceId = $_.sourceId
            filterRequired = [bool]$_.filterRequired
            enabled = if ($null -ne $_.enabled) { [bool]$_.enabled } else { $true }
            ok = if ($fs) { [bool]$fs.ok } else { $null }
            fetchedCount = if ($fs) { [int]$fs.fetchedCount } else { 0 }
            keptCount = if ($fs) { [int]$fs.keptCount } else { 0 }
            error = if ($fs) { $fs.error } else { $null }
        }
    })

    $sources = if ($news -and $news.sources) { @($news.sources) } elseif ($sourcesCfg -and $sourcesCfg.sources) { @($sourcesCfg.sources) } else { @() }

    return [PSCustomObject]@{
        generatedAt = if ($news) { [string]$news.generatedAt } else { (Get-Date).ToString("o") }
        stats = [PSCustomObject]@{
            total = $allArticles.Count
            published = $publishedCount
            hidden = $hiddenCount
            featured = $featuredCount
            manual = $manualCount
            rumors = $rumorCount
        }
        site = $publicSite
        feeds = [object[]]$mergedFeeds
        sources = [object[]]$sources
        articles = [object[]]$allArticles
    }
}

function Sync-PublicJsBundle {
    param([string]$ProjectRoot)
    $payload = Build-PublicPayload -ProjectRoot $ProjectRoot
    $json = ConvertTo-Json -InputObject $payload -Depth 10
    $jsPath = Join-Path $ProjectRoot "data\news.js"
    [System.IO.File]::WriteAllText($jsPath, "window.__CA_NEWS_DATA__ = " + $json + ";", $script:Utf8NoBom)
}
