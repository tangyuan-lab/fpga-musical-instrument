$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceDir = Join-Path $projectRoot 'firmware\usb_touch_probe'
$toolRoot = Join-Path $projectRoot '.tools\riscv-gcc\xpack-riscv-none-elf-gcc-15.2.0-1'
$gcc = Join-Path $toolRoot 'bin\riscv-none-elf-gcc.exe'
$objcopy = Join-Path $toolRoot 'bin\riscv-none-elf-objcopy.exe'
$objdump = Join-Path $toolRoot 'bin\riscv-none-elf-objdump.exe'

foreach ($tool in @($gcc, $objcopy, $objdump)) {
    if (-not (Test-Path -LiteralPath $tool)) {
        throw "Missing RISC-V tool: $tool"
    }
}

$common = @('-Wall', '-Wextra', '-O2', '-g', '-mabi=ilp32', '-march=rv32i',
            '-ffreestanding', '-fno-stack-protector', '-Iusb', '-I.')
$sources = @('start.S', 'firmware.c', 'minlibc.c', 'usb\usb_core.c', 'usb\usb_hw.c')
$objects = @()

Push-Location $sourceDir
try {
    foreach ($source in $sources) {
        $object = [IO.Path]::ChangeExtension($source, '.o')
        & $gcc @common -c $source -o $object
        if ($LASTEXITCODE -ne 0) {
            throw "Compile failed: $source"
        }
        $objects += $object
    }

    & $gcc '-mabi=ilp32' '-march=rv32i' '-Wl,--build-id=none,-Bstatic,-T,baremetal.ld' '-nostdlib' @objects '-lgcc' '-o' 'firmware.elf'
    if ($LASTEXITCODE -ne 0) {
        throw 'Firmware link failed'
    }

    & $objcopy 'firmware.elf' 'firmware.bin' '-O' 'binary'
    if ($LASTEXITCODE -ne 0) {
        throw 'Firmware binary conversion failed'
    }

    # BSRAM 初始化文件每行一个 32 位小端字，与上游 hexdump 规则保持一致。
    $bytes = [IO.File]::ReadAllBytes((Join-Path $sourceDir 'firmware.bin'))
    $lines = [Collections.Generic.List[string]]::new()
    for ($offset = 0; $offset -lt $bytes.Length; $offset += 4) {
        $wordBytes = [byte[]](0, 0, 0, 0)
        $copyLength = [Math]::Min(4, $bytes.Length - $offset)
        [Array]::Copy($bytes, $offset, $wordBytes, 0, $copyLength)
        $word = [BitConverter]::ToUInt32($wordBytes, 0)
        $lines.Add($word.ToString('x8'))
    }
    $lines | Set-Content -LiteralPath (Join-Path $sourceDir 'firmware.hex') -Encoding ascii

    & $objdump '-S' '-d' '-M' 'numeric' 'firmware.elf' |
        Set-Content -LiteralPath 'firmware.lst' -Encoding utf8
    if ($LASTEXITCODE -ne 0) {
        throw 'Firmware listing generation failed'
    }

    $hex = Join-Path $sourceDir 'firmware.hex'
    $hash = Get-FileHash -Algorithm SHA256 -LiteralPath $hex
    Write-Output "Firmware built: $hex"
    Write-Output "SHA256: $($hash.Hash)"
}
finally {
    Pop-Location
}
