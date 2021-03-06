class {'cicserver::install':
  ensure                => installed,
  survey                => 'c:/I3/IC/Manifest/newsurvey.icsurvey',
  installnodomain       => true,
  organizationname      => 'testorg',
  locationname          => 'testloc',
  sitename              => 'testsite',
  dbreporttype          => 'db',
  dbservertype          => 'mssql',
  dbtablename           => 'I3_IC',
  dialplanlocalareacode => '317',
  emailfbmc             => true,
  recordingspath        => 'C:/I3/IC/Recordings',
  sipnic                => 'Ethernet',
  outboundaddress       => '3178723000',
  defaulticpassword     => '1234',
  licensefile           => 'C:/vagrant-data/cic-license.i3lic',
  loggedonuserpassword  => 'vagrant',
}