# Baixa o script da internet
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/MNLierman/VBoxCloak/main/VBoxCloak.ps1" -OutFile "$env:TEMP\VBoxCloak.ps1"

# Desbloqueia o script (caso esteja bloqueado pelo Windows)
Unblock-File -Path "$env:TEMP\VBoxCloak.ps1"

# Executa o script com todas as opções (Registry + Arquivos + Processos)
& "$env:TEMP\VBoxCloak.ps1" -all