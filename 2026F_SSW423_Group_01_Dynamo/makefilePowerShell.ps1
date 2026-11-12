[CmdletBinding()]
param(
    [ValidateSet("pdf", "diagrams", "clean")]
    [string]$Action = "pdf"
)

$ErrorActionPreference = "Stop"
$Main = "SeniorDesignReportTemplate"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

function Assert-Tool {
    param([string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required tool '$Name' was not found on PATH."
    }
}

function Invoke-Tool {
    param(
        [string]$Name,
        [string[]]$Arguments
    )

    & $Name @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE."
    }
}

function Build-Diagrams {
    Assert-Tool -Name "dot"

    $DiagramDirectory = Join-Path $Root "diagrams"
    $OutputDirectory = Join-Path $Root "png"
    if (-not (Test-Path $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
    }

    Get-ChildItem -Path $DiagramDirectory -Directory | ForEach-Object {
        $ChapterDirectory = $_
        $ChapterOutputDirectory = Join-Path $OutputDirectory $ChapterDirectory.Name
        if (-not (Test-Path $ChapterOutputDirectory)) {
            New-Item -ItemType Directory -Path $ChapterOutputDirectory | Out-Null
        }
        Get-ChildItem -Path $ChapterDirectory.FullName -Filter "*.dot" | ForEach-Object {
            $OutputPath = Join-Path $ChapterOutputDirectory ($_.BaseName + ".png")
        Invoke-Tool -Name "dot" -Arguments @(
            "-Gdpi=180",
            "-Tpng",
            $_.FullName,
            "-o",
            $OutputPath
        )
        }
    }
}

Push-Location $Root
try {
    switch ($Action) {
        "diagrams" {
            Build-Diagrams
        }
        "pdf" {
            Build-Diagrams
            foreach ($Tool in @("pdflatex", "bibtex", "makeglossaries", "makeindex")) {
                Assert-Tool -Name $Tool
            }

            Invoke-Tool -Name "pdflatex" -Arguments @(
                "-interaction=nonstopmode",
                "-halt-on-error",
                "$Main.tex"
            )
            Invoke-Tool -Name "bibtex" -Arguments @($Main)
            Invoke-Tool -Name "makeglossaries" -Arguments @($Main)
            Invoke-Tool -Name "makeindex" -Arguments @("$Main.idx")
            Invoke-Tool -Name "pdflatex" -Arguments @(
                "-interaction=nonstopmode",
                "-halt-on-error",
                "$Main.tex"
            )
            Invoke-Tool -Name "pdflatex" -Arguments @(
                "-interaction=nonstopmode",
                "-halt-on-error",
                "$Main.tex"
            )
        }
        "clean" {
            Assert-Tool -Name "latexmk"
            Invoke-Tool -Name "latexmk" -Arguments @("-c", "$Main.tex")

            foreach ($Extension in @(
                "acn", "acr", "alg", "bbl", "blg", "glg", "glo", "gls",
                "ist", "xdy"
            )) {
                $GeneratedFile = Join-Path $Root "$Main.$Extension"
                Remove-Item -Path $GeneratedFile -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
finally {
    Pop-Location
}
