Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead((Resolve-Path (Join-Path $PSScriptRoot '..\docs\Relatorio-SGB.docx')))
try {
    $entry = $archive.GetEntry('word/document.xml')
    $reader = [IO.StreamReader]::new($entry.Open())
    try { [xml]$xml = $reader.ReadToEnd() } finally { $reader.Dispose() }
    $ns = [Xml.XmlNamespaceManager]::new($xml.NameTable)
    $ns.AddNamespace('w','http://schemas.openxmlformats.org/wordprocessingml/2006/main')
    $paragraphs = $xml.SelectNodes('//w:p',$ns)
    $texts = @($paragraphs | ForEach-Object { ($_.SelectNodes('.//w:t',$ns) | ForEach-Object { $_.InnerText }) -join '' })
    $brackets = @($texts | Where-Object { $_ -match '\[[^\]]+\]' })
    $orientations = @($texts | Where-Object { $_ -match 'ORIENTAÇÕES' })
    $guidance = @($texts | Where-Object { $_ -match 'por gerar|Exemplo:|Sommerville|biblioteca escolar|sistema de empréstimos da biblioteca|ISBN|Ctrl\+A|prima F9|Lista de verificação|Como utilizar este modelo|[Ii]nsira aqui|\[Inserir|\[Descreva|\[Frase|\[Tipo\]' })
    Write-Output "PARAGRAPHS=$($texts.Count) TABLES=$($xml.SelectNodes('//w:tbl',$ns).Count) BRACKETS=$($brackets.Count) ORIENTATIONS=$($orientations.Count)"
    if ($brackets.Count) { $brackets | Select-Object -First 40 }
    if ($orientations.Count) { $orientations | Select-Object -First 5 }
    if ($guidance.Count) { Write-Output "GUIDANCE=$($guidance.Count)"; $guidance | Select-Object -First 30 }
    $captions = @($texts | Where-Object { $_ -match '^(Figura|Tabela)\s+[0-9]+' })
    Write-Output 'CAPTIONS:'
    $captions | Select-Object -First 40
} finally { $archive.Dispose() }
