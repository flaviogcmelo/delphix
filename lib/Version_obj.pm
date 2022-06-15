#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Copyright (c) 2022 by Delphix. All rights reserved.
#
# Program Name : Version_obj.pm
# Description  : Delphix Engine OS version
# It's include the following classes:
# - Version_obj - class to manage upgrades and OS versions
# Author       : Marcin Przepiorowski
# Created      : 30 May 2022 (v2.0.0)
#


package Version_obj;

use warnings;
use strict;
use Data::Dumper;
use JSON;
use Toolkit_helpers qw (logger);
use Encode qw(decode_utf8);


sub new {
    my $classname  = shift;
    my $dlpxObject = shift;
    my $debug = shift;
    logger($debug, "Entering Version_obj::constructor",1);

    my %versions;
    my %osmap;
    my %verification;
    my $self = {
        _versions => \%versions,
        _name_map => \%osmap,
        _verification => \%verification,
        _dlpxObject => $dlpxObject,
        _debug => $debug
    };


    bless($self,$classname);

    $self->loadOSversions($debug);
    return $self;
}


# Procedure loadOSversions
# parameters:
# Load OSes

sub loadOSversions {
   my $self = shift;

   logger($self->{_debug}, "Entering Version_obj::loadOSversions",1);
   my $operation = "resources/json/delphix/system/version";
   my ($result,$result_fmt, $retcode) = $self->{_dlpxObject}->getJSONResult($operation);
   if (defined($result->{status}) && ($result->{status} eq 'OK')) {
       for my $osver (@{$result->{result}}) {
         $self->{_versions}->{$osver->{reference}} = $osver;
         $self->{_name_map}->{$osver->{name}} = $osver->{reference};
       }
   } else {
       print "No data returned for $operation. Try to increase timeout \n";
   }


}

# Procedure getOSversions
# parameters:
# Return list of loaded

sub getOSversions {
   my $self = shift;
   my @ret = sort(keys (%{$self->{_versions}}));
   return \@ret;
}


# Procedure getInstalTime
# parameters:
# - reference
# return a install time for the reference

sub getInstalTime {
   my $self = shift;
   my $reference = shift;
   return Toolkit_helpers::convert_from_utc ($self->{_versions}->{$reference}->{installDate}, $self->{_dlpxObject}->getTimezone(), 1);
}


# Procedure getOSStatus
# parameters:
# - reference
# return a OS status ( loaded / deployed / etc)

sub getOSStatus {
   my $self = shift;
   my $reference = shift;
   return $self->{_versions}->{$reference}->{status};
}


# Procedure getOSName
# parameters:
# - reference
# return a OS version name

sub getOSName {
   my $self = shift;
   my $reference = shift;
   return $self->{_versions}->{$reference}->{name};
}

# Procedure is_loaded
# parameters:
# - version
# return true is version is loaded

sub is_loaded {
   my $self = shift;
   my $version = shift;
   return defined($self->{_name_map}->{$version});
}



# Procedure loadVerfication
# parameters:
# Load OS verification results

sub loadVerfication {
   my $self = shift;

   logger($self->{_debug}, "Entering Version_obj::loadVerfication",1);
   my $operation = "resources/json/delphix/system/verification/reports";
   my ($result,$result_fmt, $retcode) = $self->{_dlpxObject}->getJSONResult($operation);
   if (defined($result->{status}) && ($result->{status} eq 'OK')) {
       for my $verification (@{$result->{result}}) {
         $self->{_verification}->{$verification->{reference}} = $verification;
         $self->{_verification}->{$verification->{reference}}->{report} = decode_json($self->{_verification}->{$verification->{reference}}->{report});
       }
   } else {
       print "No data returned for $operation. Try to increase timeout \n";
   }
}


sub getReportList {
  my $self = shift;
  my @ret = sort(keys (%{$self->{_verification}}));
  return \@ret;
}


sub getReportVersions {
   my $self = shift;
   my $reportref = shift;
   my $running_version;
   my $verified_version;

   if (defined($self->{_verification}->{$reportref})) {
     my $report_dict = $self->{_verification}->{$reportref}->{report};

     if (defined($report_dict->{runningDlpxVersion})) {
       $running_version = $report_dict->{runningDlpxVersion}
     } else {
       $running_version = 'N/A';
     }

     if (defined($report_dict->{verifiedDlpxVersion})) {
       $verified_version = $report_dict->{verifiedDlpxVersion};
     } else {
       $verified_version = 'N/A';
     }


   }


   return $running_version, $verified_version;

}


sub getReportSteps {
   my $self = shift;
   my $reportref = shift;
   my $output = shift;

   if (defined($self->{_verification}->{$reportref})) {
     my $report_dict = $self->{_verification}->{$reportref}->{report};
     my @ordered_by_date = sort { $a->{startTimestamp} cmp $b->{startTimestamp} } @{$report_dict->{checkReport}};
     my $start_time;
     for my $step (@ordered_by_date) {
       $start_time = Toolkit_helpers::convert_from_utc ($step->{startTimestamp}, $self->{_dlpxObject}->getTimezone(), 1);
       $output->addLine(
         '',
         '',
         '',
         $step->{className},
         $step->{runStatus},
         $start_time
       )
     };


   }




}

1;
