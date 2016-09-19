#!/usr/bin/env perl

use strict;
use warnings;

use Template;
use Data::UUID;
use FindBin;
use YAML qw(DumpFile LoadFile);

my $config_file = File::Spec->catfile(
	$FindBin::Bin,
	'config.yml' );

my $config;
if( @ARGV > 0 && $ARGV[0] eq '--config' ) {
	$config = {
		product_uuid => Data::UUID->new->create_str,
	};
	DumpFile( $config_file, $config );
}

if( ! -f $config_file ) {
	die <<DIE;
Create config file and commit to repository by running:
    $0 --config
DIE
} else {
	$config = LoadFile( $config_file );
}

my $data = {
	manufacturer => 'Project Renard',
	product_name => 'Project Renard Curie',
	package_description => 'Project Renard Curie Installer',
	package_comments => 'Project Renard is an FOSS project',
	package_version => '0.001',
	uuid => Data::UUID->new,
	%{$config},
};

my $tt = Template->new;

$tt->process( \*DATA, $data, "" ) or die $tt->error, "\n";

__DATA__
<?xml version='1.0' encoding='windows-1252'?>
<Wix xmlns='http://schemas.microsoft.com/wix/2006/wi'>
  <Product Name='[% product_name %]' Id='[% product_uuid %]' UpgradeCode='[% uuid.create_str() %]'
    Language='1033' Codepage='1252' Version='[% package_version %]' Manufacturer='[% manufacturer %]'>

    <Package Id='*' Keywords='Installer' Description="[% package_description %]"
      Comments='[% package_comments %]' Manufacturer='[% manufacturer %]'
      InstallerVersion='100' Languages='1033' Compressed='yes' SummaryCodepage='1252' />

    <Media Id='1' Cabinet='Sample.cab' EmbedCab='yes' DiskPrompt="CD-ROM #1" />
    <Property Id='DiskPrompt' Value="[% package_description %] Installation [1]" />

    <Directory Id='TARGETDIR' Name='SourceDir'>
      <Directory Id='ProgramFilesFolder' Name='PFiles'>
        <Directory Id='ProjectRenard' Name='Project Renard'>
          <Directory Id='INSTALLDIR' Name='Curie'>

            <Component Id='MainExecutable' Guid='[% uuid.create_str() %]'>
              <File Id='CurieEXE' Name='curie-gui.exe' DiskId='1' Source='curie-gui.exe' KeyPath='yes'>
                <Shortcut Id="startmenuPR" Directory="ProgramMenuDir" Name="Curie" WorkingDirectory='INSTALLDIR' Icon="curie.exe" IconIndex="0" Advertise="yes" />
                <Shortcut Id="desktopPR" Directory="DesktopFolder" Name="Curie" WorkingDirectory='INSTALLDIR' Icon="curie.exe" IconIndex="0" Advertise="yes" />
              </File>
            </Component>
          </Directory>
        </Directory>
      </Directory>

      <Directory Id="ProgramMenuFolder" Name="Programs">
        <Directory Id="ProgramMenuDir" Name="Project Renard">
          <Component Id="ProgramMenuDir" Guid="[% uuid.create_str() %]">
            <RemoveFolder Id='ProgramMenuDir' On='uninstall' />
            <RegistryValue Root='HKCU' Key='Software\[Manufacturer]\[ProductName]' Type='string' Value='' KeyPath='yes' />
          </Component>
        </Directory>
      </Directory>

      <Directory Id="DesktopFolder" Name="Desktop" />
    </Directory>

    <Feature Id='Complete' Level='1'>
      <ComponentRef Id='MainExecutable' />
      <ComponentRef Id='ProgramMenuDir' />
      <ComponentGroupRef Id='curie_lib' />
      <ComponentGroupRef Id='curie_mingw64' />
      <ComponentGroupRef Id='curie_perl5' />
    </Feature>

    <Icon Id="curie.exe" SourceFile="curie-gui.exe" />

  </Product>
</Wix>
