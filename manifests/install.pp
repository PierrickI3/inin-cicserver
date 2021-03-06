# == Class: cicserver::install
#
# Installs CIC, Interaction Firmware and Media Server then pairs
# the Media server with the CIC server. All silently.
# CIC ISO (i.e. CIC_2015_R2.iso) should be in a shared folder
# linked to C:\daas-cache.
# This script will install media server using the latest version
# available on disk
#
# === Parameters
#
# [ensure]
#   installed. No other values are currently supported.
#
# [survey]
#   location of survey file to be written.
#
# [installnodomain]
#   set to true for a workgroup install (no AD).
#
# [organizationname]
#   Interaction Center Organization Name.
#
# [locationname]
#   Interaction Center location name.
#
# [sitename]
#   Interaction Center Site Name.
#
# [dbreporttype]
#   Database report type. Only 'db' is supported for now.
#
# [dbservertype]
#   Database server type. Only 'mssql' is supported for now.
#
# [dbtablename]
#   Database table name. Defaults to I3_IC.
#
# [dialplanlocalareacode]
#   local area code. Defaults to 317.
#
# [emailfbmc]
#   Set to true to enable IC's FBMC (File Based Mail Connector). Default: false.
#
# [recordingspath]
#   Path to store the compressed recordings. Defaults to C:/I3/IC/Recordings.
#
# [sipnic]
#   Network card (NIC) to use for SIP/RTP transport. Default: Ethernet.
#
# [outboundaddress]
#   Phone number to show for outbound calls. Defaults to 3178723000.
#
# [defaulticpassword]
#   Default IC user password. Defaults to 1234.
#
# [licensefile]
#   Path to the CIC license file
#
# [loggedonuserpassword]
#   Password of the user that will be used to install CIC. Used to set credentials for the Interaction Center windows service.
#
# === Examples
#
#  class {'cicserver::install':
#   ensure                  => installed,
#   survey                  => 'c:/i3/ic/manifest/newsurvey.icsurvey',
#   installnodomain         => true,
#   organizationname        => 'organizationname',
#   locationname            => 'locationname',
#   sitename                => 'sitename',
#   dbreporttype            => 'db',
#   dbservertype            => 'mssql',
#   dbtablename             => 'I3_IC',
#   dialplanlocalareacode   => '317',
#   emailfbmc               => true,
#   recordingspath          => 'C:/I3/IC/Recordings',
#   sipnic                  => 'Ethernet',
#   outboundaddress         => '3178723000',
#   defaulticpassword       => '1234',
#   licensefile             => 'C:/vagrant-data/cic-license.i3lic',
#   loggedonuserpassword    => 'vagrant',
#  }
#
# === Authors
#
# Pierrick Lozach <pierrick.lozach@inin.com>
#
# === Copyright
#
# Copyright 2015, Interactive Intelligence Inc.
#

class cicserver::install (
  $ensure = installed,
  $survey,
  $installnodomain,
  $organizationname,
  $locationname,
  $sitename,
  $dbreporttype,
  $dbservertype,
  $dbtablename,
  $dialplanlocalareacode,
  $emailfbmc,
  $recordingspath,
  $sipnic,
  $outboundaddress,
  $defaulticpassword,
  $licensefile,
  $loggedonuserpassword,
)
{
  $daascache                        = 'C:/daas-cache/'

  $server                           = $::hostname
  $mediaserverregistrationurl       = "https://${server}/config/servers/add/postback"
  $mediaserverregistrationnewdata   = "NotifierHost=${server}&NotifierUserId=vagrant&NotifierPassword=1234&AcceptSessions=true&PropertyCopySrc=&_Command=Add"

  if ($::operatingsystem != 'Windows')
  {
    err('This module works on Windows only!')
    fail('Unsupported OS')
  }

  $cache_dir = hiera('core::cache_dir', 'c:/users/vagrant/appdata/local/temp') # If I use c:/windows/temp then a circular dependency occurs when used with SQL
  if (!defined(File[$cache_dir]))
  {
    file {$cache_dir:
      ensure   => directory,
      provider => windows,
    }
  }

  case $ensure
  {
    installed:
    {

      # ===================================
      # -= Disable Automatic Maintenance =-
      # ===================================

      exec {'disable-regular-maintenance':
        command  => 'psexec -accepteula -s schtasks /change /tn "\Microsoft\Windows\TaskScheduler\Regular Maintenance" /DISABLE',
        path     => $::path,
        cwd      => $::system32,
        timeout  => 30,
        provider => powershell,
        returns  => [0,1],
        before   => Class['cicserver::icsurvey'],
      }

      exec {'disable-idle-maintenance':
        command  => 'psexec -accepteula -s schtasks /change /tn "\Microsoft\Windows\TaskScheduler\Idle Maintenance" /DISABLE',
        path     => $::path,
        cwd      => $::system32,
        timeout  => 30,
        provider => powershell,
        returns  => [0,1],
        before   => Class['cicserver::icsurvey'],
      }

      # =====================
      # -= Setup Assistant =-
      # =====================

      # Create IC Survey file to run Setup Assistant remotely
      class {'cicserver::icsurvey':
        path                  => $survey, # TODO Probably needs to move/generate this somewhere else
        installnodomain       => $installnodomain,
        organizationname      => $organizationname,
        locationname          => $locationname,
        sitename              => $sitename,
        dbreporttype          => $dbreporttype,
        dbtablename           => $dbtablename,
        dialplanlocalareacode => $dialplanlocalareacode,
        emailfbmc             => $emailfbmc,
        recordingspath        => $recordingspath,
        sipnic                => $sipnic,
        outboundaddress       => $outboundaddress,
        defaulticpassword     => $defaulticpassword,
        licensefile           => $licensefile,
        before                => Exec['setupassistant-run'],
        template              => 'cicserver/DefaultSurvey.ICSurvey.erb',
      }

      # Create script to run Setup Assistant
      file {"${cache_dir}\\RunSetupAssistant.ps1":
        ensure  => 'file',
        owner   => 'Vagrant',
        group   => 'Administrators',
        content => "
        \$LogFile=\"${cache_dir}\\salog.txt\"

        function LogWrite
        {
          Param ([string]\$logstring)
          Add-content \$LogFile -value \$logstring
        }

        function WaitForSetupAssistantToFinish
        {
          Write-Host 'Waiting for Setup Assistant to finish...'
          LogWrite 'Waiting for Setup Assistant to finish...'
          do
          {
            sleep 10
            \$sacomplete = Get-ItemProperty (\"hklm:\\software\\Wow6432Node\\Interactive Intelligence\\Setup Assistant\") -name Complete | Select -exp Complete
            LogWrite 'Setup Assistant Complete? '
            LogWrite \$sacomplete
          }while (\$sacomplete -eq 0)
        }

        Write-Host \"Starting Setup Assistant... this will take a while to complete. Please wait...\"
        LogWrite 'Starting setup assistant...'
        Invoke-Expression \"C:\\I3\\IC\\Server\\icsetupu.exe /f=${survey}\"
        WaitForSetupAssistantToFinish

        LogWrite 'Sleeping for 180 seconds while waiting for setup assistant to finish.'
        Start-Sleep -s 180
        LogWrite 'Sleeping is done. Setup assistant is done.'
        ",
      }

      # Run Setup Assistant script
      exec {'setupassistant-run':
        command => "${cache_dir}\\RunSetupAssistant.ps1",
        onlyif  => [
          "if ((Get-ItemProperty (\"hklm:\\software\\Wow6432Node\\Interactive Intelligence\\Setup Assistant\") -name Complete | Select -exp Complete) -eq 1) {exit 1}", # Don't run if it has been completed before
          "if ((Get-ItemProperty (\"${licensefile}\") -name Length | Select -exp Length) -eq 0) {exit 1}", # Don't run if the license file size is 0
          ],
        provider => powershell,
        timeout  => 3600,
        require  => [
          File["${cache_dir}\\RunSetupAssistant.ps1"],
          Class['cicserver::icsurvey'],
        ],
      }

      # Apply registry fix to fix notifier name
      exec {'registry-fix':
        command => 'C:/vagrant/daas/shell/cic-server-name-registry-fix.ps1',
        provider => powershell,
        timeout  => 300,
        require  => Exec['setupassistant-run'],
        before   => Service['cicserver-service-start'],
      }

      # Start CIC service
      service {'cicserver-service-start':
        ensure  => running,
        enable  => true,
        name    => 'Interaction Center',
        require => Exec['setupassistant-run'],
      }

      # ==========================
      # -= Install Media Server =-
      # ==========================

      # Mount CIC ISO
      exec {'mount-cic-iso':
        command => "cmd.exe /c imdisk -a -f \"${daascache}\\${::cic_latest_version}\" -m l:",
        path    => $::path,
        cwd     => $::system32,
        creates => 'l:/Installs/Install.exe',
        timeout => 30,
        require => Service['cicserver-service-start'],
      }

      # Install Media Server
      package {'install-media-server':
        ensure          => installed,
        source          => "L:/Installs/Off-ServerComponents/MediaServer_${::cic_installed_major_version}_R${::cic_installed_release}.msi",
        install_options => [
          '/l*v',
          'c:\\windows\\logs\\mediaserver.log',
          {'MEDIASERVER_ADMINPASSWORD_ENCRYPTED' => 'CA1E4FED70D14679362C37DF14F7C88A'},
        ],
        provider        => 'windows',
        require         => Exec['mount-cic-iso'],
      }

      # We don't need the ISO any more
      exec {'unmount-cic-iso':
        command  => 'cmd.exe /c imdisk -D -m l:',
        path     => $::path,
        cwd      => $::system32,
        timeout  => 30,
        require  => Package['install-media-server'],
      }

      # Mount CIC Patch ISO
      if ($::cic_installed_patch != '0') {
        # A patch was installed. We need to update media server to the latest patch available
        exec {'mount-cic-latest-patch-iso':
          command => "cmd.exe /c imdisk -a -f \"${daascache}\\CIC_${::cic_installed_major_version}_R${::cic_installed_release}_Patch${::cic_installed_patch}.iso\" -m m:",
          path    => $::path,
          cwd     => $::system32,
          creates => 'm:/Installs/Install.exe',
          timeout => 30,
          require => Package['install-media-server'],
        }

        # Create script to install Latest Patch since puppet does not know how to run MSPs (will be fixed in 4.x: https://tickets.puppetlabs.com/browse/PUP-395)
        file {'mediaserver-latest-patch-script':
          ensure  => present,
          path    => "${cache_dir}\\patchmediaserver.ps1",
          content => "
            \$parms  = '/update',\"m:\\Installs\\Off-ServerComponents\\MediaServer_${::cic_installed_major_version}_R${::cic_installed_release}_Patch${::cic_installed_patch}.msp\"
            \$parms += 'STARTEDBYEXEORIUPDATE=1'
            \$parms += 'REBOOT=ReallySuppress'
            \$parms += '/l*v'
            \$parms += \"C:\\Windows\\Logs\\mediaserverpatch.log\"
            \$parms += '/qn'
            \$parms += '/norestart'
            Start-Process -FilePath msiexec -ArgumentList \$parms -Wait -Verbose
          ",
          require => Package['install-media-server'],
        }

        # Install Media Server Latest Patch
        exec {'mediaserver-latest-patch-run':
          command  => "${cache_dir}\\patchmediaserver.ps1",
          provider => powershell,
          timeout  => 1800,
          require  => [
            File['mediaserver-latest-patch-script'],
            Exec['mount-cic-latest-patch-iso'],
          ],
        }

        # We don't need the ISO any more. Unmount it.
        exec {'unmount-cic-latest-patch-iso':
          command  => 'cmd.exe /c imdisk -D -m m:',
          path     => $::path,
          cwd      => $::system32,
          timeout  => 30,
          require  => Exec['mediaserver-latest-patch-run'],
        }

      }

      # ==============================
      # -= Configuring Media Server =-
      # ==============================

      # Setting web config login password
      registry_value {"$::media_server_registry_path\\WebConfigLoginPassword":
        type    => string,
        data    => 'CA1E4FED70D14679362C37DF14F7C88A',
        require => Package['install-media-server'],
      }

      # Downloading Media Server License
      if ($processor_cores == '01') {

        download_file("mediaservertest_40_${processor_cores}core_prod_vm.i3lic", "${daascache}Licenses/MediaServer", $cache_dir, '', '')

        # Create Media Server License file for a single core
        file { 'c:/i3/ic/mediaserverlicense.i3lic':
          ensure             => file,
          source             => "file:///${cache_dir}/mediaservertest_40_${processor_cores}core_prod_vm.i3lic",
          source_permissions => ignore,
        }
      } else {

        download_file("mediaservertest_40_${processor_cores}cores_prod_vm.i3lic", "${daascache}Licenses/MediaServer", $cache_dir, '', '')

        # Create Media Server License file for multiple cores
        file { 'c:/i3/ic/mediaserverlicense.i3lic':
          ensure             => file,
          source             => "file:///${cache_dir}/mediaservertest_40_${processor_cores}cores_prod_vm.i3lic",
          source_permissions => ignore,
        }
      }


      # Installing Media Server license
      registry_value {"$::media_server_registry_path\\LicenseFile":
      type    => string,
      data    => 'C:\\I3\\IC\\MediaServerLicense.i3lic',
      require => [
        Package['install-media-server'],
        File['c:/i3/ic/mediaserverlicense.i3lic'],
      ],
      before  => Exec['ININMediaServer-Start'],
      }

      # Creating powershell script to start Media Server service
      file {"${cache_dir}\\StartMediaServerService.ps1":
        ensure  => 'file',
        owner   => 'Vagrant',
        group   => 'Administrators',
        content => "
        function Service-Start (\$ServiceName, \$TimeoutSeconds) {
          try {
              \$service = Get-Service -Name \$ServiceName
              if (\$service.Status -eq \"Stopped\") {
                  \$service.start()
                  \$service.WaitForStatus('Running', (New-TimeSpan -Seconds \$TimeoutSeconds))
              } elseif (\$currentStatus -eq 'Running') {
                  write-host \" ==> \$ServiceName is already running service\"
              }
          } catch { \$CurrentStatus = \"ERROR\" }
          return \$CurrentStatus
        }
        Service-Start 'ININMediaServer' 30
        ",
      }

      # Start Media Server
      if ($::cic_installed_patch != '0') {
        exec {'ININMediaServer-Start' :
          command  => "${cache_dir}\\StartMediaServerService.ps1",
          provider => powershell,
          require  => [
            Package['install-media-server'],
            Exec['mediaserver-latest-patch-run'],
          ],
        }
      } else {
        exec {'ININMediaServer-Start' :
          command  => "${cache_dir}\\StartMediaServerService.ps1",
          provider => powershell,
          require  => [
            Package['install-media-server'],
          ],
        }
      }

      # Creating script to pair CIC and Media server
      file {'mediaserver-pairing':
        ensure  => present,
        path    => "${cache_dir}\\mediaserverpairing.ps1",
        content => "
        [System.Net.ServicePointManager]::SecurityProtocol = 'tls11,tls12'
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {\$true}
        \$uri = New-Object System.Uri (\"${mediaserverregistrationurl}\")
        \$secpasswd = ConvertTo-SecureString \"1234\" -AsPlainText -Force
        \$mycreds = New-Object System.Management.Automation.PSCredential (\"admin\", \$secpasswd)

        \$mediaserverPath = \"c:\\i3\\ic\\resources\\MediaServerConfig.xml\"
        \$commandServerCount = 0
        \$finishedLongWait = \$false;

        for(\$provisionCount = 0; \$provisionCount -lt 15; \$provisionCount++)
        {
            try {
                \$r = Invoke-WebRequest -Uri \$uri.AbsoluteUri -Credential \$mycreds  -Method Post -Body \"${mediaserverregistrationnewdata}\"

            } catch {
                \$x =  \$_.Exception.Message
                write-host \$x -ForegroundColor yellow
            }

            sleep 10
            [xml]\$mediaServerConfig = Get-Content \$mediaserverPath
            \$commandServers = \$mediaServerConfig.SelectSingleNode(\"//MediaServerConfig/CommandServers\")
            \$commandServerCount = \$commandServers.ChildNodes.Count -gt 0
            if(\$commandServerCount -gt 0)
            {
                write-host \"command server provisioned\"
                \$provisionCount = 100;
                break;
            }

            if(\$provisionCount -eq 14 -And !\$finishedLongWait)
            {
                \$finishedLongWait= \$true
                #still not provisioned, sleep and try some more
                write-host \"waiting 10 minutes before trying again\"
                sleep 600
                \$provisionCount = 0;
            }
        }

        if (\$commandServerCount -eq 0){
            write-host \"Error provisioning media server\" -ForegroundColor red
        }

        write-host \"Approving certificate in CIC\"
        function ApproveCertificate(\$certPath){
          Set-ItemProperty -path \"Registry::\$certPath\" -name Status -value Allowed
        }

        \$certs = Get-ChildItem -Path \"hklm:\\Software\\Wow6432Node\\Interactive Intelligence\\EIC\\Directory Services\\Root\\${sitename}\\Production\\Config Certificates\\Config Subsystems Certificates\"
        ApproveCertificate \$certs[0].name
        ApproveCertificate \$certs[1].name
        write-host \"Certificate approval done\"

        function CreateShortcut(\$AppLocation, \$description){
            \$WshShell = New-Object -ComObject WScript.Shell
            \$Shortcut = \$WshShell.CreateShortcut(\"\$env:USERPROFILE\\Desktop\\\$description.url\")
            \$Shortcut.TargetPath = \$AppLocation
            #\$Shortcut.Description = \$description
            \$Shortcut.Save()
        }

        CreateShortcut \"http://localhost:8084\" \"Media_Server\"
        ",
        require => Exec['ININMediaServer-Start'],
      }

      # Pairing CIC and Media server
      exec {'mediaserver-pair-cic':
        command  => "${cache_dir}\\mediaserverpairing.ps1",
        provider => powershell,
        timeout  => 1800,
        require  => File['mediaserver-pairing'],
      }

    }
    default:
    {
      fail("Unsupported ensure \"${ensure}\"")
    }
  }
}
