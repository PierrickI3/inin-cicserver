class {'cicserver::install':
  ensure                 => installed,
  source                 => '\\\\192.168.0.22\\Logiciels\\ININ\\2015R1\\CIC_2015_R1',
  source_user            => 'admin',
  source_password        => 'Vero052408',
  survey                 => 'c:/i3/ic/manifest/newsurvey.icsurvey',
  installnodomain        => true,
  organizationname       => 'organizationname',
  locationname           => 'locationname',
  sitename               => 'sitename',
  dbreporttype           => 'db',
  dbservertype           => 'mssql',
  dbtablename            => 'I3_IC',
  dialplanlocalareacode  => '317',
  emailfbmc              => true,
  recordingspath         => 'C:\\I3\\IC\\Recordings',
  sipnic                 => 'Ethernet 2',
  outboundaddress        => '3178723000',
  defaulticpassword      => '1234',
  licensefile            => 'c:\\i3\\ic\\license.i3lic',
  loggedonuserpassword   => 'vagrant',
}