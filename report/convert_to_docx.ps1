$ErrorActionPreference = 'Stop'
$root = 'C:\Users\XIAOXIAO\Desktop\fpga\sc500cs\sc500cs\report'
$html = Join-Path $root 'report_for_word.html'
$docx = Join-Path $root 'report_main.docx'
$pdf  = Join-Path $root 'report_main.pdf'
$headerText = [System.IO.File]::ReadAllText((Join-Path $root 'header.txt'), [System.Text.Encoding]::UTF8).Trim()
$footerPrefix = [System.IO.File]::ReadAllText((Join-Path $root 'footer_prefix.txt'), [System.Text.Encoding]::UTF8)
$footerSuffix = [System.IO.File]::ReadAllText((Join-Path $root 'footer_suffix.txt'), [System.Text.Encoding]::UTF8)

$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0
$word.ScreenUpdating = $false

try {
    $doc = $word.Documents.Open($html, $false, $false, $false)
    $doc.PageSetup.PageWidth = 595.3
    $doc.PageSetup.PageHeight = 841.9
    $doc.PageSetup.TopMargin = 72
    $doc.PageSetup.BottomMargin = 72
    $doc.PageSetup.LeftMargin = 90
    $doc.PageSetup.RightMargin = 90
    $doc.PageSetup.HeaderDistance = 42
    $doc.PageSetup.FooterDistance = 42
    $doc.PageSetup.Gutter = 0

    $section = $doc.Sections.Item(1)
    $section.PageSetup.DifferentFirstPageHeaderFooter = -1

    # Primary header (not on cover page).
    $header = $section.Headers.Item(1)
    $header.Range.Text = $headerText
    $header.Range.ParagraphFormat.Alignment = 1
    $header.Range.Font.NameFarEast = 'SimSun'
    $header.Range.Font.NameAscii = 'Times New Roman'
    $header.Range.Font.Size = 9
    $header.Range.Font.Color = 8421504

    # Primary footer with PAGE field.
    $footer = $section.Footers.Item(1)
    $footer.Range.Text = $footerPrefix
    $footer.Range.ParagraphFormat.Alignment = 1
    $footer.Range.Font.NameFarEast = 'SimSun'
    $footer.Range.Font.NameAscii = 'Times New Roman'
    $footer.Range.Font.Size = 9
    $footer.Range.Font.Color = 8421504
    $footer.Range.Collapse(0)
    $footer.Range.Fields.Add($footer.Range, 33) | Out-Null
    $footer.Range.InsertAfter($footerSuffix)
    $footer.Range.ParagraphFormat.Alignment = 1

    # First-page header/footer stay empty.
    $section.Headers.Item(2).Range.Text = ''
    $section.Footers.Item(2).Range.Text = ''

    # HTML import links pictures by default. Force them into the DOCX package
    # so the report remains self-contained when copied to another machine.
    for ($i = 1; $i -le $doc.InlineShapes.Count; $i++) {
        $shape = $doc.InlineShapes.Item($i)
        if ($shape.Type -eq 4) {
            $shape.LinkFormat.SavePictureWithDocument = $true
        }
        # Word's HTML import uses the picture's pixel size (about 48 cm for a
        # 1800 px PNG), ignoring CSS width. Fit every figure to the text width.
        $shape.LockAspectRatio = -1
        $shape.Width = $word.CentimetersToPoints(14.5)
    }

    if (Test-Path $docx) { Remove-Item $docx -Force }
    if (Test-Path $pdf)  { Remove-Item $pdf -Force }
    $doc.SaveAs([ref][string]$docx, [ref]16)
    Write-Output 'DOCX_SAVED'
    $doc.Close($false)

    # Reopen the saved DOCX (normal paragraph collection) and apply the page
    # breaks that Word's HTML importer ignored.
    $doc = $word.Documents.Open($docx, $false, $false, $false)

    # Compact table cells: Word's HTML import uses generous cell padding and
    # paragraph spacing, which otherwise splits small tables across pages.
    $widthMap = @{
        1 = @(24, 76)
        2 = @(18, 42, 40)
        3 = @(20, 16, 64)
        4 = @(22, 30, 48)
        5 = @(20, 34, 46)
        6 = @(24, 34, 42)
        7 = @(22, 20, 58)
        8 = @(22, 78)
        9 = @(8, 28, 40, 24)
        10 = @(30, 26, 44)
    }
    $tableIndex = 0
    foreach ($t in $doc.Tables) {
        $tableIndex++
        try {
            $t.PreferredWidthType = 2
            $t.PreferredWidth = 100
            $t.AutoFitBehavior(0)
            $t.TopPadding = 1.0
            $t.BottomPadding = 1.0
            $t.LeftPadding = 2.5
            $t.RightPadding = 2.5
            $t.Rows.Item(1).HeadingFormat = $true
            $t.Rows.AllowBreakAcrossPages = $false
            $w = $widthMap[$tableIndex]
            if ($null -ne $w) {
                for ($c = 1; $c -le $t.Columns.Count -and $c -le $w.Count; $c++) {
                    $t.Columns.Item($c).PreferredWidthType = 2
                    $t.Columns.Item($c).PreferredWidth = $w[$c - 1]
                }
            }
            foreach ($cell in $t.Range.Cells) {
                $cell.Range.ParagraphFormat.SpaceBefore = 0
                $cell.Range.ParagraphFormat.SpaceAfter = 0
                $cell.Range.ParagraphFormat.LineSpacingRule = 0
            }
        }
        catch { }
    }
    Write-Output ('TABLE_COUNT=' + $tableIndex)
    foreach ($t in $doc.Tables) {
        try { $t.Rows.Item(1).HeadingFormat = -1 } catch { }
    }
    foreach ($shape in $doc.InlineShapes) {
        try { $shape.Range.Paragraphs.Item(1).ParagraphFormat.KeepWithNext = -1 } catch { }
    }
    Write-Output 'TABLES_COMPACTED'

    $paraCount = $doc.Paragraphs.Count
    for ($i = $paraCount; $i -ge 1; $i--) {
        $p = $doc.Paragraphs.Item($i)
        if ($p.Range.Text -like '*[[PB]]*') {
            if ($i -lt $paraCount) {
                $doc.Paragraphs.Item($i + 1).Range.ParagraphFormat.PageBreakBefore = -1
            }
            $p.Range.Text = ''
        }
    }
    $doc.Save()
    Write-Output 'PAGEBREAKS_APPLIED'

    try {
        $doc.SaveAs([ref][string]$pdf, [ref]17)
        Write-Output 'PDF_SAVED'
    }
    catch {
        Write-Output ('PDF_WARN: ' + $_.Exception.Message)
    }

    Write-Output ('PAGES=' + $doc.ComputeStatistics(2))
    Write-Output ('WORDS=' + $doc.ComputeStatistics(0))
    Write-Output ('CHARACTERS=' + $doc.ComputeStatistics(3))
    Write-Output ('SAVED_DOCX=' + $docx)
    Write-Output ('SAVED_PDF=' + $pdf)
    $doc.Close($false)
}
finally {
    $word.Quit()
}
