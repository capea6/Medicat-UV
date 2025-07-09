Add-Type -AssemblyName PresentationFramework

$Buttons = @($args)
if (-not $Buttons -or $Buttons.Count -eq 0) {
    [System.Windows.MessageBox]::Show("No se han definido botones para el menú.","Error")
    exit 1
}

$window = New-Object Windows.Window
$window.Title = "Medicat Instalador"
$window.Width = 500
$window.Height = 80 + ($Buttons.Count * 50)
$window.WindowStartupLocation = "CenterScreen"
$window.ResizeMode = "NoResize"

$stack = New-Object Windows.Controls.StackPanel
$stack.Margin = '20'
$stack.HorizontalAlignment = 'Center'
$stack.VerticalAlignment = 'Center'

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
