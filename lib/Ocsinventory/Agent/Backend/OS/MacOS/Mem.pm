package Ocsinventory::Agent::Backend::OS::MacOS::Mem;
use strict;

sub check {
    my $params = shift;
    my $common = $params->{common};

    return(undef) unless -r '/usr/sbin/system_profiler'; # check perms
    return (undef) unless $common->can_load("Mac::SysProfile");
    return 1;
}

sub run {
    my $params = shift;
    my $common = $params->{common};

    my $PhysicalMemory;

    # create the profile object and return undef unless we get something back
    my $profile = Mac::SysProfile->new();
    my $data = $profile->gettype('SPMemoryDataType');
    return(undef) unless(ref($data) eq 'ARRAY');

    # Workaround for MacOSX 10.5.7
    #if ($h->{'Memory Slots'}) {
    #  $h = $h->{'Memory Slots'};
    #}


    foreach my $memory (@$data){
        next unless $memory->{'_name'} =~ /^BANK|SODIMM|DIMM/;
        # tare out the slot number
        my $slot = $memory->{'_name'};
	# memory in 10.5
        if($slot =~ /^BANK (\d)\/DIMM\d/){
            $slot = $1;
        }
	# 10.4
	if($slot =~ /^SODIMM(\d)\/.*$/){
		$slot = $1;
	}
	# 10.4 PPC
	if($slot =~ /^DIMM(\d)\/.*$/){
		$slot = $1;
	}

	# 10.7
	if ($slot =~ /^DIMM (\d)/) {
		$slot = $1;
	}

        my $size = $memory->{'dimm_size'};

        my $desc = $memory->{'dimm_part_number'};

        if ($desc !~ /empty/ && $desc =~ s/^0x//) {
            # dimm_part_number is an hex string, convert it to ascii
            $desc =~ s/^0x//;
            $desc = pack "H*", $desc;
            $desc =~ s/\s+$//;
            # New macs might have some specific characters, perform a regex to fix it
            $desc =~ s/(?!-)[[:punct:]]//g;
        }

        # if system_profiler lables the size in gigs, we need to trim it down to megs so it's displayed properly
        if($size =~ /GB$/){
                $size =~ s/GB$//;
                $size *= 1024;
        }
        $common->addMemory({
            'CAPACITY'      => $size,
            'SPEED'         => $memory->{'dimm_speed'},
            'TYPE'          => $memory->{'dimm_type'},
            'SERIALNUMBER'  => $memory->{'dimm_serial_number'},
            'DESCRIPTION'   => $desc,
            'NUMSLOTS'      => $slot,
            'CAPTION'       => 'Status: '.$memory->{'dimm_status'},
        });
    }

    # Send total memory size to inventory object
    my $sysctl_memsize=`sysctl -n hw.memsize`;
    $common->setHardware({
        MEMORY =>  $sysctl_memsize / 1024 / 1024,
    });
}
1;
