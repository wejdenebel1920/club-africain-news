param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSVersion.Major -lt 6) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

$ConfigPath = [System.IO.Path]::Combine($ProjectRoot, "config", "sources.json")
$DataDir = Join-Path $ProjectRoot "data"
if (-not (Test-Path $DataDir)) {
    New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
}

$Config = Get-Content -Path $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$SourcesById = @{}
foreach ($s in $Config.sources) {
    $SourcesById[$s.id] = $s
}

function Clean-Html {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    $decoded = [System.Net.WebUtility]::HtmlDecode($Text)
    $noTags = [regex]::Replace($decoded, "<[^>]+>", " ")
    $collapsed = [regex]::Replace($noTags, "\s+", " ").Trim()
    if ($collapsed.Length -gt 280) {
        return $collapsed.Substring(0, 277) + "..."
    }
    return $collapsed
}

function Sanitize-FeedXml {
    param([string]$XmlText)
    if ([string]::IsNullOrWhiteSpace($XmlText)) { return $XmlText }
    $endFeed = $XmlText.LastIndexOf("</feed>")
    if ($endFeed -gt 0) {
        return $XmlText.Substring(0, $endFeed + 7)
    }
    $endRss = $XmlText.LastIndexOf("</rss>")
    if ($endRss -gt 0) {
        return $XmlText.Substring(0, $endRss + 6)
    }
    return $XmlText
}

function Fetch-Utf8Text {
    param([string]$Url)
    $wc = New-Object System.Net.WebClient
    $wc.Encoding = [System.Text.Encoding]::UTF8
    $wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) ClubAfricainNewsBot/1.0")
    $bytes = $wc.DownloadData($Url)
    return [System.Text.Encoding]::UTF8.GetString($bytes)
}

function Is-ClubAfricainFootball {
    param([string]$Title, [string]$Summary)
    $text = ($Title + " " + $Summary).ToLowerInvariant()
    $hasCA = $text -match "club africain|clubistes|bab jedid|النادي الإفريقي|النادي الافريقي|الإفريقي|الافريقي|باب جديد"
    if (-not $hasCA) { return $false }
    if ($text -match "meilleur club africain|best african club|trophée.*club africain" -and $text -notmatch "tunisie|tunis|bab jedid|kanzari|zamalek|radès|ligue 1") {
        return $false
    }
    $isOtherSport = $text -match "basket-ball|basketball|handball|volley-ball|volleyball|natation|كرة السلة|كرة اليد|الكرة الطائرة|السباحة"
    if ($isOtherSport) { return $false }
    return $true
}

function Resolve-PublisherSourceId {
    param([string]$PublisherName, [string]$PublisherUrl, [string]$DefaultSourceId)
    $hay = ($PublisherName + " " + $PublisherUrl).ToLowerInvariant()
    if ($hay -match "mosaique|موزاييك") { return "mosaiquefm" }
    if ($hay -match "kawarji|كوارجي") { return "kawarji" }
    if ($hay -match "diwan|ديوان") { return "diwanfm" }
    if ($hay -match "jawhara|جوهرة") { return "jawharafm" }
    if ($hay -match "lapresse|la presse") { return "lapresse" }
    if ($hay -match "lequotidien|le quotidien") { return "lequotidien" }
    if ($hay -match "tunisienumerique|tunisie numérique|تونس الرقمية") { return "tunisienumerique" }
    if ($hay -match "foot24|فوت 24|فوت24") { return "foot24" }
    if ($hay -match "footballtunisien") { return "footballtunisien" }
    if ($hay -match "cafonline|caf") { return "cafonline" }
    if ($hay -match "bein") { return "beinsports" }
    if ($hay -match "winwin|kooora|وين وين|كووورة") { return "winwin" }
    if ($hay -match "transfermarkt") { return "transfermarkt" }
    if ($hay -match "allafrica|ysscores|sofascore|flashscore") { return "allafrica" }
    if ($hay -match "nessma|tuniscope|gnet|نسمة|تونيسكوب") { return "nessma_tuniscope" }
    if ($hay -match "clubafricain") { return "ca_portal" }
    return $DefaultSourceId
}

function Classify-Topic {
    param([string]$Title, [string]$Summary, [string]$SourceId)
    $text = ($Title + " " + $Summary).ToLowerInvariant()
    if ($SourceId -eq "ca_youtube" -or $text -match "communiqué|بلاغ|officiel|رسمي|passeportenligne") {
        if ($text -match "ligue des champions|caf|zamalek|الزمالك|دوري أبطال") { return "caf" }
        return "official"
    }
    if ($text -match "ligue des champions|caf|zamalek|mc alger|الزمالك|دوري أبطال|إفريقيا|قاري") { return "caf" }
    if ($text -match "mercato|transfert|recrutement|contrat|signature|ميركاتو|انتداب|تعاقد|صفقة|رحيل") { return "mercato" }
    if ($text -match "blessure|infirmerie|forfait|kanzari|kanté|diatta|entraînement|compo|liste|إصابة|الكنزاري|قائمة|تدريبات|تشكيلة|عودة") { return "squad" }
    return "ligue1"
}

function Get-KeywordSignature {
    param([string]$Title)
    $clean = $Title.ToLowerInvariant()
    $clean = [regex]::Replace($clean, "[^\p{L}\p{N}\s]", " ")
    $words = $clean -split "\s+" | Where-Object {
        $_.Length -ge 4 -and $_ -notin @(
            "club", "africain", "tunisie", "football", "pour", "avec", "dans", "contre",
            "النادي", "الإفريقي", "الافريقي", "تونس", "مباراة", "فريق", "كرة", "القدم"
        )
    }
    return ($words | Select-Object -Unique)
}

function Parse-DateSafe {
    param([string]$DateStr)
    if ([string]::IsNullOrWhiteSpace($DateStr)) { return (Get-Date).ToUniversalTime() }
    $normalized = $DateStr.Trim()
    if ($normalized -match "^(\d{4}-\d{2}-\d{2})UTC(\d{2}:\d{2}):\d+$") {
        $normalized = "$($Matches[1])T$($Matches[2]):00Z"
    }
    try {
        return ([DateTimeOffset]::Parse($normalized)).UtcDateTime
    } catch {
        return (Get-Date).ToUniversalTime()
    }
}

$RawItems = New-Object System.Collections.Generic.List[object]
$FeedStatuses = New-Object System.Collections.Generic.List[object]

foreach ($feed in $Config.feeds) {
    if ($null -ne $feed.enabled -and -not [bool]$feed.enabled) {
        continue
    }
    $status = [ordered]@{
        id = $feed.id
        url = $feed.url
        lang = $feed.lang
        ok = $false
        fetchedCount = 0
        keptCount = 0
        error = $null
    }
    try {
        $xmlText = Sanitize-FeedXml (Fetch-Utf8Text -Url $feed.url)
        [xml]$doc = $xmlText

        $isAtom = ($null -ne $doc.DocumentElement -and $doc.DocumentElement.LocalName -eq "feed")

        if ($isAtom) {
            $ns = New-Object System.Xml.XmlNamespaceManager($doc.NameTable)
            $ns.AddNamespace("atom", "http://www.w3.org/2005/Atom")
            $ns.AddNamespace("media", "http://search.yahoo.com/mrss/")
            $entries = $doc.SelectNodes("//atom:entry", $ns)
            $status.fetchedCount = $entries.Count
            foreach ($entry in $entries) {
                $titleNode = $entry.SelectSingleNode("atom:title", $ns)
                $title = if ($titleNode) { $titleNode.InnerText } else { "" }
                $linkNode = $entry.SelectSingleNode("atom:link[@rel='alternate']", $ns)
                if (-not $linkNode) { $linkNode = $entry.SelectSingleNode("atom:link", $ns) }
                $link = if ($linkNode) { $linkNode.GetAttribute("href") } else { "" }
                $pubNode = $entry.SelectSingleNode("atom:published", $ns)
                if (-not $pubNode) { $pubNode = $entry.SelectSingleNode("atom:updated", $ns) }
                $pub = if ($pubNode) { $pubNode.InnerText } else { "" }

                $descNode = $entry.SelectSingleNode("media:group/media:description", $ns)
                if (-not $descNode) { $descNode = $entry.SelectSingleNode("atom:summary", $ns) }
                $thumbNode = $entry.SelectSingleNode("media:group/media:thumbnail", $ns)
                $summary = if ($descNode) { Clean-Html $descNode.InnerText } else { "" }
                $thumb = if ($thumbNode) { $thumbNode.GetAttribute("url") } else { "" }

                $cleanTitle = Clean-Html $title
                if ($feed.filterRequired -and -not (Is-ClubAfricainFootball -Title $cleanTitle -Summary $summary)) {
                    continue
                }

                $dt = Parse-DateSafe $pub
                $src = $SourcesById[$feed.sourceId]
                $RawItems.Add([PSCustomObject]@{
                    title = $cleanTitle
                    summary = $summary
                    url = $link
                    thumbnail = $thumb
                    publishedAt = $dt.ToString("o")
                    publishedUtc = $dt
                    lang = $feed.lang
                    sourceId = $feed.sourceId
                    sourceName = $src.name
                    sourceNameAr = $src.nameAr
                    sourceDomain = $src.domain
                    topic = (Classify-Topic -Title $cleanTitle -Summary $summary -SourceId $feed.sourceId)
                    isVideo = ($feed.type -eq "youtube_atom")
                })
                $status.keptCount++
            }
        } else {
            $items = $doc.SelectNodes("//item")
            $status.fetchedCount = $items.Count
            foreach ($item in $items) {
                $rawTitle = [string]$item.title
                $link = [string]$item.link
                $pub = [string]$item.pubDate
                $desc = Clean-Html ([string]$item.description)

                $resolvedSourceId = $feed.sourceId
                $cleanTitle = Clean-Html $rawTitle
                $publisherLabel = ""

                if ($feed.type -eq "google_news_rss") {
                    $pubNode = $item.SelectSingleNode("source")
                    $pubName = if ($pubNode) { $pubNode.InnerText } else { "" }
                    $pubUrl = if ($pubNode) { $pubNode.GetAttribute("url") } else { "" }
                    $publisherLabel = $pubName
                    if (-not [string]::IsNullOrWhiteSpace($pubName)) {
                        $suffix = " - " + $pubName
                        if ($cleanTitle.EndsWith($suffix)) {
                            $cleanTitle = $cleanTitle.Substring(0, $cleanTitle.Length - $suffix.Length).Trim()
                        }
                    }
                    $resolvedSourceId = Resolve-PublisherSourceId -PublisherName $pubName -PublisherUrl $pubUrl -DefaultSourceId $feed.sourceId
                    # Google News RSS description often repeats title + source; avoid noisy duplicate text
                    if ($desc.StartsWith($cleanTitle)) {
                        $desc = ""
                    }
                }

                if ($feed.filterRequired -and -not (Is-ClubAfricainFootball -Title $cleanTitle -Summary $desc)) {
                    continue
                }

                $dt = Parse-DateSafe $pub
                $src = if ($SourcesById.ContainsKey($resolvedSourceId)) { $SourcesById[$resolvedSourceId] } else { $SourcesById[$feed.sourceId] }
                $displaySourceName = if ($src.id -like "google_news_*" -and -not [string]::IsNullOrWhiteSpace($publisherLabel)) { $publisherLabel } else { $src.name }
                $displaySourceNameAr = if ($src.id -like "google_news_*" -and -not [string]::IsNullOrWhiteSpace($publisherLabel)) { $publisherLabel } else { $src.nameAr }

                $RawItems.Add([PSCustomObject]@{
                    title = $cleanTitle
                    summary = $desc
                    url = $link
                    thumbnail = ""
                    publishedAt = $dt.ToString("o")
                    publishedUtc = $dt
                    lang = $feed.lang
                    sourceId = $src.id
                    sourceName = $displaySourceName
                    sourceNameAr = $displaySourceNameAr
                    sourceDomain = $src.domain
                    topic = (Classify-Topic -Title $cleanTitle -Summary $desc -SourceId $src.id)
                    isVideo = $false
                })
                $status.keptCount++
            }
        }
        $status.ok = $true
    } catch {
        $status.error = $_.Exception.Message
    }
    $FeedStatuses.Add([PSCustomObject]$status)
}

# Deduplicate by URL and near-identical titles
$SeenUrls = @{}
$UniqueItems = New-Object System.Collections.Generic.List[object]
foreach ($it in ($RawItems | Sort-Object publishedUtc -Descending)) {
    if ([string]::IsNullOrWhiteSpace($it.url)) { continue }
    if ($SeenUrls.ContainsKey($it.url)) { continue }
    $SeenUrls[$it.url] = $true
    $UniqueItems.Add($it)
}

$NowUtc = (Get-Date).ToUniversalTime()
$KeywordsMap = @{}
for ($i = 0; $i -lt $UniqueItems.Count; $i++) {
    $KeywordsMap[$i] = Get-KeywordSignature -Title $UniqueItems[$i].title
}

$ScoredArticles = New-Object System.Collections.Generic.List[object]
$SourceArticleCounts = @{}

for ($i = 0; $i -lt $UniqueItems.Count; $i++) {
    $it = $UniqueItems[$i]
    $src = $SourcesById[$it.sourceId]
    $baseScore = [int]$src.baseScore

    $kwA = $KeywordsMap[$i]
    $corroboratingSources = New-Object System.Collections.Generic.HashSet[string]
    if ($kwA.Count -ge 2) {
        for ($j = 0; $j -lt $UniqueItems.Count; $j++) {
            if ($i -eq $j) { continue }
            $other = $UniqueItems[$j]
            if ($other.sourceId -eq $it.sourceId) { continue }
            $hoursDiff = [Math]::Abs(($it.publishedUtc - $other.publishedUtc).TotalHours)
            if ($hoursDiff -gt 72) { continue }
            $kwB = $KeywordsMap[$j]
            $overlap = ($kwA | Where-Object { $kwB -contains $_ }).Count
            if ($overlap -ge 2) {
                [void]$corroboratingSources.Add($other.sourceId)
            }
        }
    }
    $corroborationBonus = [Math]::Min(12, $corroboratingSources.Count * 4)

    $ageHours = ($NowUtc - $it.publishedUtc).TotalHours
    $freshnessDelta = if ($ageHours -le 6) { 4 }
        elseif ($ageHours -le 24) { 0 }
        elseif ($ageHours -le 48) { -4 }
        elseif ($ageHours -le 96) { -8 }
        else { -12 }

    $textCheck = ($it.title + " " + $it.summary).ToLowerInvariant()
    $isSpeculative = $textCheck -match "rumeur|selon nos informations|serait proche|piste|تقارير|أنباء|يقترب من|مفاوضات"
    $rumorPenalty = if ($isSpeculative -and $corroboratingSources.Count -eq 0 -and $src.category -ne "official") { 12 } else { 0 }

    $finalScore = [Math]::Max(0, [Math]::Min(100, $baseScore + $corroborationBonus + $freshnessDelta - $rumorPenalty))

    $verification = if ($src.category -eq "official" -or $it.topic -eq "official") { "official" }
        elseif ($corroboratingSources.Count -ge 1 -or $finalScore -ge 84) { "verified" }
        elseif ($finalScore -ge 72 -and $rumorPenalty -eq 0) { "press" }
        else { "rumor" }

    if (-not $SourceArticleCounts.ContainsKey($src.id)) { $SourceArticleCounts[$src.id] = 0 }
    $SourceArticleCounts[$src.id]++

    $ScoredArticles.Add([PSCustomObject]@{
        id = [System.BitConverter]::ToString(([System.Security.Cryptography.MD5]::Create()).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($it.url))).Replace("-", "").Substring(0, 12).ToLowerInvariant()
        title = $it.title
        summary = $it.summary
        url = $it.url
        thumbnail = $it.thumbnail
        publishedAt = $it.publishedAt
        lang = $it.lang
        topic = $it.topic
        isVideo = $it.isVideo
        sourceId = $src.id
        sourceName = $it.sourceName
        sourceNameAr = $it.sourceNameAr
        sourceDomain = $src.domain
        sourceCategory = $src.category
        score = $finalScore
        verification = $verification
        corroborationCount = $corroboratingSources.Count
        scoreBreakdown = [PSCustomObject]@{
            baseScore = $baseScore
            corroborationBonus = $corroborationBonus
            freshnessDelta = $freshnessDelta
            rumorPenalty = $rumorPenalty
        }
    })
}

$SortedArticles = $ScoredArticles | Sort-Object @{Expression="publishedAt";Descending=$true}, @{Expression="score";Descending=$true} | Select-Object -First 120

$EnrichedSources = foreach ($s in $Config.sources) {
    $cnt = if ($SourceArticleCounts.ContainsKey($s.id)) { $SourceArticleCounts[$s.id] } else { 0 }
    [PSCustomObject]@{
        id = $s.id
        name = $s.name
        nameAr = $s.nameAr
        domain = $s.domain
        url = $s.url
        category = $s.category
        lang = $s.lang
        accessMode = $s.accessMode
        accessModeAr = $s.accessModeAr
        F = $s.F
        R = $s.R
        C = $s.C
        D = $s.D
        B = $s.B
        baseScore = $s.baseScore
        articleCount = $cnt
    }
}

$Payload = [PSCustomObject]@{
    generatedAt = (Get-Date).ToString("o")
    scope = "football-v1"
    totalArticles = $SortedArticles.Count
    feeds = $FeedStatuses
    sources = $EnrichedSources
    articles = $SortedArticles
}

$JsonOutput = ConvertTo-Json -InputObject $Payload -Depth 6
$JsonPath = Join-Path $DataDir "news.json"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($JsonPath, $JsonOutput, $Utf8NoBom)

. (Join-Path $PSScriptRoot "cms_helper.ps1")
Sync-PublicJsBundle -ProjectRoot $ProjectRoot

Write-Host "Collected $($SortedArticles.Count) football articles across $($FeedStatuses.Count) free feeds."
foreach ($fs in $FeedStatuses) {
    Write-Host (" - {0}: ok={1}, fetched={2}, kept={3} {4}" -f $fs.id, $fs.ok, $fs.fetchedCount, $fs.keptCount, $fs.error)
}
