param(
    [string]$CsvOutputPath = "cmd_logs/online_retail_q3_top_customers.csv",
    [string]$ChartPath = "docs/online-retail-q3-top-customers-chart.md",
    [int]$TopN = 10
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$csvOutputFullPath = Join-Path $root $CsvOutputPath
$chartFullPath = Join-Path $root $ChartPath

$hdfsLines = docker exec namenode hdfs dfs -cat /data/online_retail/output/q3/part-r-*
if ($LASTEXITCODE -ne 0) {
    throw "Could not read q3 output from HDFS. Run /opt/scripts/run-online-retail-analysis.sh first."
}

$rows = New-Object System.Collections.Generic.List[object]
foreach ($line in $hdfsLines) {
    $parts = $line -split "`t"
    if ($parts.Length -lt 3) {
        continue
    }

    $country = $parts[0]
    $customerId = ($parts[1] -replace "^customer_id=", "")
    $totalText = ($parts[2] -replace "^total=", "")
    $total = [double]::Parse($totalText, [System.Globalization.CultureInfo]::InvariantCulture)

    $rows.Add([pscustomobject]@{
        Country = $country
        CustomerId = $customerId
        TotalPurchaseValue = [math]::Round($total, 2)
    })
}

$sortedRows = $rows | Sort-Object TotalPurchaseValue -Descending
$topRows = $sortedRows | Select-Object -First $TopN

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $csvOutputFullPath) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $chartFullPath) | Out-Null

$sortedRows | Export-Csv -LiteralPath $csvOutputFullPath -NoTypeInformation -Encoding UTF8

function Convert-ToMermaidLabel {
    param([string]$Text)
    $label = $Text -replace "[^A-Za-z0-9]+", "_"
    return $label.Trim("_")
}

$labels = $topRows | ForEach-Object { Convert-ToMermaidLabel $_.Country }
$values = $topRows | ForEach-Object { "{0:0.##}" -f $_.TotalPurchaseValue }
$maxValue = [math]::Ceiling((($topRows | Measure-Object -Property TotalPurchaseValue -Maximum).Maximum) / 100000) * 100000
if ($maxValue -le 0) {
    $maxValue = 1
}

$chartLines = New-Object System.Collections.Generic.List[string]
$chartLines.Add("# Bieu do cau 3 - Top customer theo Country")
$chartLines.Add("")
$chartLines.Add("Cau 3: Khach hang nao co gia tri mua hang cao nhat o moi quoc gia.")
$chartLines.Add("")
$chartLines.Add("Gia tri mua hang duoc tinh bang:")
$chartLines.Add("")
$chartLines.Add('```text')
$chartLines.Add("TotalPurchaseValue = SUM(Quantity * Price)")
$chartLines.Add('```')
$chartLines.Add("")
$chartLines.Add("## Bieu do Top $TopN quoc gia theo gia tri mua hang cao nhat")
$chartLines.Add("")
$chartLines.Add('```mermaid')
$chartLines.Add("xychart-beta")
$chartLines.Add("    title `"Top $TopN customer purchase value by country`"")
$chartLines.Add("    x-axis `"Country`" [$($labels -join ', ')]")
$chartLines.Add("    y-axis `"Total purchase value`" 0 --> $maxValue")
$chartLines.Add("    bar [$($values -join ', ')]")
$chartLines.Add('```')
$chartLines.Add("")
$chartLines.Add("## Bang ket qua cau 3")
$chartLines.Add("")
$chartLines.Add("| Country | Customer ID | Total purchase value |")
$chartLines.Add("|---|---:|---:|")
foreach ($row in $sortedRows) {
    $chartLines.Add("| $($row.Country) | $($row.CustomerId) | $($row.TotalPurchaseValue) |")
}

$chartLines.Add("")
$chartLines.Add("## Nhan xet")
$chartLines.Add("")
$chartLines.Add("- Cac quoc gia co gia tri top customer cao thuong la noi co don hang lon hoac khach hang mua lap lai nhieu.")
$chartLines.Add("- Neu mot quoc gia co total am hoac rat thap, co the do giao dich huy/tra hang lam giam tong `Quantity * Price`.")

Set-Content -LiteralPath $chartFullPath -Value $chartLines -Encoding UTF8

Write-Host "Wrote q3 CSV to $csvOutputFullPath"
Write-Host "Wrote q3 chart to $chartFullPath"
