param(
    [string]$CsvPath = "data/online_retail_II.csv",
    [string]$OutputPath = "cmd_logs/online_retail_scaling_results.csv",
    [string]$ChartPath = "docs/online-retail-speedup-line-chart.md"
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$workersPath = Join-Path $root "config/workers"
$csvFullPath = Resolve-Path (Join-Path $root $CsvPath)
$outputFullPath = Join-Path $root $OutputPath
$chartFullPath = Join-Path $root $ChartPath
$originalWorkers = Get-Content -LiteralPath $workersPath -Raw

function Invoke-Checked {
    param([string[]]$Command)

    & $Command[0] @($Command[1..($Command.Length - 1)])
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed: $($Command -join ' ')"
    }
}

function Get-ServicesForNodeCount {
    param([int]$NodeCount)

    $services = @("namenode")
    for ($i = 1; $i -le $NodeCount; $i++) {
        $services += "datanode$i"
    }
    return $services
}

$rows = New-Object System.Collections.Generic.List[object]

try {
    for ($nodes = 1; $nodes -le 3; $nodes++) {
        $workers = 1..$nodes | ForEach-Object { "datanode$_" }
        Set-Content -LiteralPath $workersPath -Value ($workers -join "`n") -NoNewline

        Invoke-Checked @("docker", "compose", "down")
        Invoke-Checked (@("docker", "compose", "up", "-d", "--build") + (Get-ServicesForNodeCount $nodes))

        foreach ($service in Get-ServicesForNodeCount $nodes) {
            Invoke-Checked @("docker", "exec", $service, "bash", "/opt/scripts/init-ssh.sh")
        }

        Invoke-Checked @("docker", "exec", "namenode", "bash", "/opt/scripts/start-hadoop.sh")
        Invoke-Checked @("docker", "exec", "namenode", "bash", "/opt/scripts/run-online-retail-analysis.sh")

        $timeLines = docker exec namenode cat /data/online_retail_times.tsv
        if ($LASTEXITCODE -ne 0) {
            throw "Could not read /data/online_retail_times.tsv from namenode"
        }

        foreach ($line in $timeLines) {
            $parts = $line -split "`t"
            if ($parts.Length -eq 2) {
                $rows.Add([pscustomobject]@{
                    Nodes = $nodes
                    Job = $parts[0]
                    Seconds = [double]$parts[1]
                    Speedup = $null
                })
            }
        }
    }
}
finally {
    Set-Content -LiteralPath $workersPath -Value $originalWorkers -NoNewline
}

$baseline = @{}
foreach ($row in $rows | Where-Object { $_.Nodes -eq 1 }) {
    $baseline[$row.Job] = $row.Seconds
}

foreach ($row in $rows) {
    if ($baseline.ContainsKey($row.Job) -and $row.Seconds -gt 0) {
        $row.Speedup = [math]::Round($baseline[$row.Job] / $row.Seconds, 3)
    }
}

$outputDir = Split-Path -Parent $outputFullPath
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$rows | Export-Csv -LiteralPath $outputFullPath -NoTypeInformation -Encoding UTF8
Write-Host "Wrote benchmark results to $outputFullPath"

$chartDir = Split-Path -Parent $chartFullPath
New-Item -ItemType Directory -Force -Path $chartDir | Out-Null

$chartLines = New-Object System.Collections.Generic.List[string]
$chartLines.Add("# So do Speedup theo MapReduce Job Map - Online Retail II")
$chartLines.Add("")
$chartLines.Add("File nay duoc tao sau khi chay benchmark 1, 2, 3 nodes.")
$chartLines.Add("")
$chartLines.Add("Cong thuc:")
$chartLines.Add("")
$chartLines.Add('```text')
$chartLines.Add("Speedup = T1 / Tn")
$chartLines.Add('```')
$chartLines.Add("")
$chartLines.Add("## Bang Speedup theo MapReduce Job Map")
$chartLines.Add("")
$chartLines.Add("| MapReduce Job Map | Speedup 1 Node | Speedup 2 Nodes | Speedup 3 Nodes |")
$chartLines.Add("|---|---:|---:|---:|")

$jobs = $rows | Select-Object -ExpandProperty Job -Unique
foreach ($job in $jobs) {
    $jobRows = $rows | Where-Object { $_.Job -eq $job }
    $speedup1 = ($jobRows | Where-Object { $_.Nodes -eq 1 } | Select-Object -First 1).Speedup
    $speedup2 = ($jobRows | Where-Object { $_.Nodes -eq 2 } | Select-Object -First 1).Speedup
    $speedup3 = ($jobRows | Where-Object { $_.Nodes -eq 3 } | Select-Object -First 1).Speedup
    $mapName = "mapreduce_job_map_$job"
    $chartLines.Add("| $mapName | $speedup1 | $speedup2 | $speedup3 |")
}

$chartLines.Add("")
$chartLines.Add("## So do duong Speedup")
$chartLines.Add("")
$chartLines.Add('```mermaid')
$chartLines.Add("xychart-beta")
$chartLines.Add("    title `"Speedup theo MapReduce Job Map`"")
$chartLines.Add("    x-axis `"MapReduce Job Map`" [q1_map, q2_map]")
$chartLines.Add("    y-axis `"Speedup`" 0 --> 2")

$speedup2Values = @()
$speedup3Values = @()
foreach ($job in $jobs) {
    $jobRows = $rows | Where-Object { $_.Job -eq $job }
    $speedup2Values += "{0:0.###}" -f (($jobRows | Where-Object { $_.Nodes -eq 2 } | Select-Object -First 1).Speedup)
    $speedup3Values += "{0:0.###}" -f (($jobRows | Where-Object { $_.Nodes -eq 3 } | Select-Object -First 1).Speedup)
}
$chartLines.Add("    line [$($speedup2Values -join ', ')]")
$chartLines.Add("    line [$($speedup3Values -join ', ')]")
$chartLines.Add('```')
$chartLines.Add("")
$chartLines.Add("Ghi chu: `q1_map` = `mapreduce_job_map_q1_invoice_count_by_country`; `q2_map` = `mapreduce_job_map_q2_distinct_customer_count_by_country`.")
$chartLines.Add("")
$chartLines.Add("Duong thu nhat la Speedup 2 Nodes, duong thu hai la Speedup 3 Nodes.")
$chartLines.Add("")

foreach ($job in $jobs) {
    $jobRows = $rows | Where-Object { $_.Job -eq $job } | Sort-Object Nodes

    $chartLines.Add("## Chi tiet $job")
    $chartLines.Add("")
    $chartLines.Add("| So node | Thoi gian chay | Speedup |")
    $chartLines.Add("|---:|---:|---:|")
    foreach ($row in $jobRows) {
        $chartLines.Add("| $($row.Nodes) | $($row.Seconds) | $($row.Speedup) |")
    }
    $chartLines.Add("")
}

$chartLines.Add("## Nhan xet")
$chartLines.Add("")
$chartLines.Add("- Hang `MapReduce Job Map` duoc dat theo dang `mapreduce_job_map_<ten_job>`.")
$chartLines.Add("- Cot `Speedup` cho biet toc do nhanh hon so voi cau hinh 1 node.")
$chartLines.Add("- Speedup tang cham hoac giam co the do overhead khoi dong job, shuffle/sort, I/O HDFS, hoac tai nguyen container.")

Set-Content -LiteralPath $chartFullPath -Value $chartLines -Encoding UTF8
Write-Host "Wrote speedup line chart to $chartFullPath"
