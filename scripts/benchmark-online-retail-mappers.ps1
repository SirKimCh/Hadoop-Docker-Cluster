param(
    [int[]]$MapperCounts = @(1, 3, 5, 10, 20),
    [int]$Runs = 3,
    [string]$RawOutputPath = "cmd_logs/online_retail_mapper_runs.csv",
    [string]$AverageOutputPath = "cmd_logs/online_retail_mapper_average_speedup.csv",
    [string]$ChartPath = "docs/online-retail-mapper-speedup-line-chart.md"
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$rawOutputFullPath = Join-Path $root $RawOutputPath
$averageOutputFullPath = Join-Path $root $AverageOutputPath
$chartFullPath = Join-Path $root $ChartPath

function Invoke-Checked {
    param([string[]]$Command)

    & $Command[0] @($Command[1..($Command.Length - 1)])
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed: $($Command -join ' ')"
    }
}

$rawRows = New-Object System.Collections.Generic.List[object]

foreach ($mapperCount in $MapperCounts) {
    for ($run = 1; $run -le $Runs; $run++) {
        Write-Host "Running mapperCount=$mapperCount, run=$run/$Runs"
        Invoke-Checked @(
            "docker", "exec", "namenode", "bash", "-lc",
            "MAPPER_COUNT=$mapperCount /opt/scripts/run-online-retail-analysis.sh"
        )

        $timeLines = docker exec namenode cat /data/online_retail_times.tsv
        if ($LASTEXITCODE -ne 0) {
            throw "Could not read /data/online_retail_times.tsv from namenode"
        }

        foreach ($line in $timeLines) {
            $parts = $line -split "`t"
            if ($parts.Length -eq 2) {
                $job = $parts[0]
                $rawRows.Add([pscustomobject]@{
                    MapperCount = $mapperCount
                    Run = $run
                    Job = $job
                    MapReduceJobMap = "mapreduce_job_map_$job"
                    Seconds = [double]$parts[1]
                })
            }
        }
    }
}

$averageRows = New-Object System.Collections.Generic.List[object]
$groups = $rawRows | Group-Object Job, MapperCount
foreach ($group in $groups) {
    $first = $group.Group | Select-Object -First 1
    $avgSeconds = [math]::Round((($group.Group | Measure-Object -Property Seconds -Average).Average), 3)
    $averageRows.Add([pscustomobject]@{
        MapperCount = $first.MapperCount
        Job = $first.Job
        MapReduceJobMap = $first.MapReduceJobMap
        AverageSeconds = $avgSeconds
        AverageSpeedup = $null
    })
}

$baseline = @{}
foreach ($row in $averageRows | Where-Object { $_.MapperCount -eq 1 }) {
    $baseline[$row.Job] = $row.AverageSeconds
}

foreach ($row in $averageRows) {
    if ($baseline.ContainsKey($row.Job) -and $row.AverageSeconds -gt 0) {
        $row.AverageSpeedup = [math]::Round($baseline[$row.Job] / $row.AverageSeconds, 3)
    }
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $rawOutputFullPath) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $averageOutputFullPath) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $chartFullPath) | Out-Null

$rawRows | Export-Csv -LiteralPath $rawOutputFullPath -NoTypeInformation -Encoding UTF8
$averageRows | Sort-Object Job, MapperCount | Export-Csv -LiteralPath $averageOutputFullPath -NoTypeInformation -Encoding UTF8

$jobs = $averageRows | Select-Object -ExpandProperty Job -Unique
$mapperLabel = ($MapperCounts | ForEach-Object { $_ }) -join ", "

$chartLines = New-Object System.Collections.Generic.List[string]
$chartLines.Add("# So do duong Speedup trung binh theo Mapper - Online Retail II")
$chartLines.Add("")
$chartLines.Add("Benchmark chay moi mapper count $Runs lan, tinh thoi gian trung binh roi tinh Speedup.")
$chartLines.Add("")
$chartLines.Add("Cong thuc:")
$chartLines.Add("")
$chartLines.Add('```text')
$chartLines.Add("AverageSpeedup(m) = AverageTime(1 mapper) / AverageTime(m mappers)")
$chartLines.Add('```')
$chartLines.Add("")
$chartLines.Add("## Bang Speedup trung binh")
$chartLines.Add("")
$chartLines.Add("| MapReduce Job Map | Speedup 1 Mapper | Speedup 3 Mappers | Speedup 5 Mappers | Speedup 10 Mappers | Speedup 20 Mappers |")
$chartLines.Add("|---|---:|---:|---:|---:|---:|")

foreach ($job in $jobs) {
    $jobRows = $averageRows | Where-Object { $_.Job -eq $job }
    $values = foreach ($mapperCount in $MapperCounts) {
        ($jobRows | Where-Object { $_.MapperCount -eq $mapperCount } | Select-Object -First 1).AverageSpeedup
    }
    $chartLines.Add("| mapreduce_job_map_$job | $($values -join ' | ') |")
}

$chartLines.Add("")
$chartLines.Add("## So do duong Speedup")
$chartLines.Add("")
$chartLines.Add('```mermaid')
$chartLines.Add("xychart-beta")
$chartLines.Add("    title `"Average Speedup theo so mapper`"")
$chartLines.Add("    x-axis `"Mapper count`" [$mapperLabel]")
$chartLines.Add("    y-axis `"Average Speedup`" 0 --> 3")

foreach ($job in $jobs) {
    $jobRows = $averageRows | Where-Object { $_.Job -eq $job }
    $values = foreach ($mapperCount in $MapperCounts) {
        "{0:0.###}" -f (($jobRows | Where-Object { $_.MapperCount -eq $mapperCount } | Select-Object -First 1).AverageSpeedup)
    }
    $chartLines.Add("    line [$($values -join ', ')]")
}

$chartLines.Add('```')
$chartLines.Add("")
$chartLines.Add("Ghi chu: moi duong tuong ung mot `MapReduce Job Map` theo thu tu bang tren.")
$chartLines.Add("")
$chartLines.Add("## Du lieu trung binh")
$chartLines.Add("")
$chartLines.Add("| Mapper count | MapReduce Job Map | Average seconds | Average speedup |")
$chartLines.Add("|---:|---|---:|---:|")
foreach ($row in ($averageRows | Sort-Object Job, MapperCount)) {
    $chartLines.Add("| $($row.MapperCount) | $($row.MapReduceJobMap) | $($row.AverageSeconds) | $($row.AverageSpeedup) |")
}

$chartLines.Add("")
$chartLines.Add("## Nhan xet can dien")
$chartLines.Add("")
$chartLines.Add("- Neu Speedup tang khi tang mapper: job tan dung duoc chia nho input va xu ly song song tot hon.")
$chartLines.Add("- Neu Speedup tang cham hoac giam: co the do overhead tao mapper, shuffle/sort, I/O HDFS, hoac container resource.")

Set-Content -LiteralPath $chartFullPath -Value $chartLines -Encoding UTF8

Write-Host "Wrote raw mapper runs to $rawOutputFullPath"
Write-Host "Wrote average mapper speedup to $averageOutputFullPath"
Write-Host "Wrote mapper speedup line chart to $chartFullPath"
