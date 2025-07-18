param(
    [string]$Message = "",
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Buttons
)

# Reemplazar '\n' y '`n' por saltos de línea reales
$Message = $Message -replace '\\n', "`n"
$Message = $Message -replace '`n', "`n"

Add-Type -AssemblyName PresentationFramework

if (-not $Buttons -or $Buttons.Count -eq 0) {
    [System.Windows.MessageBox]::Show("No se han definido botones para el menú.","Error")
    exit 1
}

$window = New-Object Windows.Window
$window.Title = "Medicat Instalador"
$window.Width = 600
$window.Height = 120 + ($Buttons.Count * 50)
$window.WindowStartupLocation = "CenterScreen"
$window.ResizeMode = "NoResize"

$stack = New-Object Windows.Controls.StackPanel
$stack.Margin = '20'
$stack.HorizontalAlignment = 'Center'
$stack.VerticalAlignment = 'Center'

# Mensaje descriptivo
if ($Message) {
    $label = New-Object Windows.Controls.TextBlock
    $label.Text = $Message
    $label.TextWrapping = "Wrap"
    $label.Margin = '0,0,0,20'
    $label.FontSize = 16
    $stack.Children.Add($label)
}

# Calcular líneas del mensaje para ajustar la altura
$lineCount = ($Message -split "`n").Count
if ($lineCount -lt 3) { $lineCount = 3 } # Altura mínima para mensajes cortos

$window.Width = 800
$window.Height = 100 + ($Buttons.Count * 55) + ($lineCount * 28)

$selected = $null

foreach ($btnText in $Buttons) {
    $btn = New-Object Windows.Controls.Button
    $btn.Content = $btnText
    $btn.Margin = '5'
    $btn.Width = 400
    $btn.FontSize = 16
    $btn.Add_Click({ 
        $script:selected = $this.Content
        $window.Close()
    })
    $stack.Children.Add($btn)
}

$window.Content = $stack
$window.ShowDialog() | Out-Null

if ($selected) {
    Write-Output $selected
}