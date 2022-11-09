FROM mcr.microsoft.com/windows/servercore:ltsc2019
# FROM mcr.microsoft.com/dotnet/framework/aspnet:4.7.2
# FROM mcr.microsoft.com/dotnet/sdk:7.0.100-rc.2-windowsservercore-ltsc2019
# FROM mcr.microsoft.com/dotnet/framework/sdk:4.7.2-windowsservercore-ltsc2019

#input GitHub runner version argument
ARG RUNNER_VERSION

#Set working directory
WORKDIR /actions-runner

SHELL ["cmd", "/S", "/C"]

RUN curl -SL --output vs_buildtools.exe https://aka.ms/vs/15/release/vs_buildtools.exe \
    && (start /w vs_buildtools.exe --quiet --wait --norestart --nocache \
        --installPath "%ProgramFiles(x86)%\Microsoft Visual Studio\2017\BuildTools" \
        --add Microsoft.Net.Component.4.7.2.SDK \
        --add Microsoft.Net.Component.4.7.2.TargetingPack \
        --add Microsoft.Net.ComponentGroup.4.7.2.DeveloperTools \
        --add Microsoft.VisualStudio.Component.NuGet \
        --add Microsoft.VisualStudio.Component.NuGet.BuildTools \
        || IF "%ERRORLEVEL%"=="3010" EXIT 0) \
    && del /q vs_buildtools.exe

ADD "https://dist.nuget.org/win-x86-commandline/v4.7.0/nuget.exe" "C:\TEMP\nuget.exe"

# Install SSDT NuGet
RUN "C:\TEMP\nuget.exe" install Microsoft.Data.Tools.Msbuild -Version 10.0.61804.210

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop';"]

RUN Set-TimeZone -Id 'Singapore Standard Time'

#Download GitHub Runner based on RUNNER_VERSION argument (Can use: Docker build --build-arg RUNNER_VERSION=x.y.z)
RUN Invoke-WebRequest -Uri "https://github.com/actions/runner/releases/download/v$env:RUNNER_VERSION/actions-runner-win-x64-$env:RUNNER_VERSION.zip" -OutFile "actions-runner.zip"; \
    Expand-Archive -Path ".\\actions-runner.zip" -DestinationPath '.'; \
    Remove-Item ".\\actions-runner.zip" -Force

#Install chocolatey
ADD scripts/Install-Choco.ps1 .
ADD scripts/start.ps1 .
RUN .\Install-Choco.ps1 -Wait; \
    Remove-Item .\Install-Choco.ps1 -Force

#Install Git, GitHub-CLI, Azure-CLI and PowerShell Core with Chocolatey (add more tooling if needed at build)
RUN choco install -y \
    git \
    gh \
    nodejs-lts \
    yarn \
    opencover

# RUN choco install -y dotnetcore-sdk --version 2.1.526
# RUN choco install -y dotnetfx --version=4.7.2.20180712
# RUN choco install -y --ignore-package-exit-codes=3010 dotnetfx
# RUN choco install -y visualstudio2017buildtools --package-parameters "--norestart"

#Add GitHub runner configuration startup script

# ADD scripts/Cleanup-Runners.ps1 .
ENTRYPOINT ["C:\\Program Files (x86)\\Microsoft Visual Studio\\2017\\BuildTools\\Common7\\Tools\\VsDevCmd.bat", "&&", "powershell.exe", ".\\start.ps1"]
